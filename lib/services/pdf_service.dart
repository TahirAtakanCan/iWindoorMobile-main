import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/project_quote.dart';
import '../pdf/pdf_window_drawing.dart';
import '../utils/bom_display.dart';
import '../utils/format.dart';
import 'design_api.dart';

export '../utils/format.dart';

String _dateTr(DateTime? d) {
  if (d == null) return '—';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

int expectedQuotePageCount(ProjectQuote q) => 1 + q.windows.length + 1;

SeriesInfo seriesForWindow(CatalogSnapshot catalog, QuoteWindow w) {
  final name = w.seriesName?.trim();
  if (name != null && name.isNotEmpty) {
    for (final s in catalog.series) {
      if (s.name == name) return s;
    }
  }
  return catalog.seriesFor(w.design.seriesId);
}

String? _colorTitle(CatalogSnapshot catalog, String colorCode) {
  final code = colorCode.trim();
  if (code.isEmpty || code.toLowerCase() == 'white') return null;
  final cat = catalog.colorByCode(code);
  if (cat != null) return cat.name;
  final builtin = ProfileColor.of(code);
  return builtin.code == 'white' && code.toLowerCase() != 'white' ? code : builtin.label;
}

ProfileColor _profileColor(CatalogSnapshot catalog, String colorCode) {
  final cat = catalog.colorByCode(colorCode);
  if (cat != null) return ProfileColor.fromHex(cat.code, cat.name, cat.hexOutside);
  return ProfileColor.of(colorCode);
}

class PdfService {
  Future<Uint8List> buildQuotePdf(
    ProjectQuote q,
    CatalogSnapshot catalog, {
    pw.Font? base,
    pw.Font? bold,
    bool compress = true,
  }) async {
    final font = base ?? await PdfGoogleFonts.robotoRegular();
    final fontBold = bold ?? await PdfGoogleFonts.robotoBold();
    final theme = pw.ThemeData.withFont(base: font, bold: fontBold);
    final pdf = pw.Document(theme: theme, compress: compress);
    final currency = q.currency;

    GlassLook lookOf(String code) => GlassLook.forStyle(catalog.glassByCode(code)?.visualStyle);

    LayoutResult layoutOf(QuoteWindow w) => LayoutEngine(seriesForWindow(catalog, w).geometry).run(w.design);

    final widgets = <pw.Widget>[
      ..._cover(q, lookOf, layoutOf, currency, catalog),
      for (final w in q.windows) ...[
        pw.NewPage(),
        ..._windowPage(
          w,
          lookOf,
          layoutOf(w),
          seriesForWindow(catalog, w).geometry,
          currency,
          catalog: catalog,
        ),
      ],
      pw.NewPage(),
      ..._materialsPage(q, currency),
    ];

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 48),
        footer: (ctx) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Sayfa ${ctx.pageNumber} / ${ctx.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (ctx) => widgets,
      ),
    );

    return pdf.save();
  }

  Future<void> shareOrPrintQuotePdf(ProjectQuote q, CatalogSnapshot catalog) async {
    try {
      final bytes = await buildQuotePdf(q, catalog);
      final name = 'Teklif_${_safeFile(q.project.name)}.pdf';
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e, st) {
      debugPrint('PDF paylaşım hatası: $e\n$st');
      rethrow;
    }
  }

  static String _safeFile(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  List<pw.Widget> _cover(
    ProjectQuote q,
    GlassLook Function(String) lookOf,
    LayoutResult Function(QuoteWindow) layoutOf,
    String currency,
    CatalogSnapshot catalog,
  ) {
    final p = q.project;
    return [
      _companyHeader(q),
      pw.SizedBox(height: 12),
      pw.Text('TEKLİF', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
      pw.SizedBox(height: 8),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(p.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if ((p.description ?? '').isNotEmpty)
                  pw.Text(p.description!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ..._customerBlock(p),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Tarih: ${_dateTr(q.generatedAt)}', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Geçerlilik: ${_dateTr(q.validUntil)}', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text('Pencereler', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      _windowsSummaryTable(q, lookOf, layoutOf, currency, catalog),
      pw.SizedBox(height: 16),
      _totalsBlock(q, currency),
      if ((q.company.quoteNote ?? '').trim().isNotEmpty) ...[
        pw.SizedBox(height: 16),
        pw.Text('Teklif notu', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.Text(q.company.quoteNote!.trim(), style: const pw.TextStyle(fontSize: 10)),
      ],
    ];
  }

  List<pw.Widget> _customerBlock(QuoteProjectInfo p) {
    final has = [
      p.customerName,
      p.customerPhone,
      p.customerEmail,
      p.customerAddress,
    ].any((e) => (e ?? '').trim().isNotEmpty);
    if (!has) return const [];
    return [
      pw.SizedBox(height: 8),
      pw.Text('Müşteri', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      if ((p.customerName ?? '').trim().isNotEmpty)
        pw.Text(p.customerName!.trim(), style: const pw.TextStyle(fontSize: 10)),
      if ((p.customerPhone ?? '').trim().isNotEmpty)
        pw.Text('Tel: ${p.customerPhone!.trim()}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      if ((p.customerEmail ?? '').trim().isNotEmpty)
        pw.Text(p.customerEmail!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      if ((p.customerAddress ?? '').trim().isNotEmpty)
        pw.Text(p.customerAddress!.trim(), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
    ];
  }

  List<pw.Widget> _windowPage(
    QuoteWindow w,
    GlassLook Function(String) lookOf,
    LayoutResult layout,
    SeriesGeometry geometry,
    String currency, {
    required CatalogSnapshot catalog,
  }) {
    final bom = BomLine.aggregate(layout.bom);
    final ruleIssues = checkDesign(layout, geometry, w.design);
    final seriesLabel = w.seriesName?.trim().isNotEmpty == true
        ? w.seriesName!.trim()
        : seriesForWindow(catalog, w).name;
    final colorLabel = _colorTitle(catalog, w.design.colorCode);
    final profileColor = _profileColor(catalog, w.design.colorCode);
    return [
      pw.Text(w.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(
        '$seriesLabel'
        '${colorLabel != null ? ' · $colorLabel' : ''}'
        ' · ${w.quantity} adet',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 10),
      pw.Center(
        child: pdfWindowDrawing(
          design: w.design,
          layout: layout,
          lookOf: lookOf,
          color: profileColor,
          showDimensions: true,
          width: 480,
          height: 300,
        ),
      ),
      pw.SizedBox(height: 12),
      if (w.warnings.isNotEmpty || ruleIssues.isNotEmpty) ...[
        pw.Text('Uyarılar', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
        for (final warn in w.warnings) pw.Text('• $warn', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),
        for (final i in ruleIssues) pw.Text('• ${i.message}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.orange800)),
        pw.SizedBox(height: 8),
      ],
      ..._cutListTable(bom),
      pw.SizedBox(height: 10),
      ..._glassListTable(bom),
      pw.SizedBox(height: 10),
      ..._hardwareTable(bom),
      pw.SizedBox(height: 10),
      ..._linesSection(sortedQuoteLines(w.lines)),
      pw.SizedBox(height: 8),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Birim: ${formatMoney(w.unitPrice)}   ·   Satır: ${formatMoney(w.lineTotal)}',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
  }

  /// Bölüm başlığı + tablo: sığmazsa başlık en az 3 satırla birlikte sonraki sayfaya geçer;
  /// devam sayfalarında tablo başlığı tekrarlanır.
  List<pw.Widget> _sectionDataTable({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
    required PdfColor headerColor,
    double headerFontSize = 8,
    double cellFontSize = 8,
  }) {
    if (data.isEmpty) {
      return [
        pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('Satır yok.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
      ];
    }
    final first = data.take(3).toList();
    final rest = data.length > 3 ? data.sublist(3) : const <List<String>>[];
    pw.Widget tableOf(List<List<String>> rows) => pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerCount: 1,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: headerFontSize),
          headerDecoration: pw.BoxDecoration(color: headerColor),
          cellStyle: pw.TextStyle(fontSize: cellFontSize),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
        );
    return [
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            tableOf(first),
          ],
        ),
      ),
      if (rest.isNotEmpty) tableOf(rest),
    ];
  }

  List<pw.Widget> _cutListTable(List<BomLine> bom) {
    final rows = workshopCutLines(bom);
    return _sectionDataTable(
      title: 'Kesim listesi',
      headers: const ['Parça', 'Ölçü (mm)', 'Kesim', 'Adet'],
      data: [
        for (final l in rows)
          [
            l.label,
            l.length != null ? '${l.length!.round()}' : '—',
            l.cut ?? '—',
            '${l.qty}',
          ],
      ],
      headerColor: PdfColors.blueGrey700,
    );
  }

  List<pw.Widget> _glassListTable(List<BomLine> bom) {
    final rows = bom.where((l) => l.group == BomGroup.glass || l.group == BomGroup.panel).toList();
    return _sectionDataTable(
      title: 'Cam / panel listesi',
      headers: const ['Kod', 'Ölçü (G × Y mm)', 'Adet', 'Alan (m²)'],
      data: [
        for (final l in rows)
          [
            l.glassCode ?? '',
            (l.w != null && l.h != null) ? '${l.w!.round()} × ${l.h!.round()}' : '—',
            '${l.qty}',
            formatQty(((l.w ?? 0) / 1000) * ((l.h ?? 0) / 1000) * l.qty),
          ],
      ],
      headerColor: PdfColors.teal700,
    );
  }

  List<pw.Widget> _hardwareTable(List<BomLine> bom) {
    final rows = bom.where((l) => l.group == BomGroup.hardware).toList();
    if (rows.isEmpty) return const [];
    return _sectionDataTable(
      title: 'Donanım',
      headers: const ['Tür', 'Kanat ölçüsü (G × Y)', 'Adet'],
      data: [
        for (final l in rows)
          [
            hardwareKindTr(l.kind),
            (l.w != null && l.h != null) ? '${l.w!.round()} × ${l.h!.round()}' : '—',
            '${l.qty}',
          ],
      ],
      headerColor: PdfColors.brown700,
    );
  }

  List<pw.Widget> _materialsPage(ProjectQuote q, String currency) {
    return [
      pw.Text('Malzeme Özeti', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 10),
      ..._materialsSection(sortedQuoteLines(q.materials)),
      pw.SizedBox(height: 16),
      _totalsBlock(q, currency),
    ];
  }

  List<pw.Widget> _linesSection(List<QuoteLine> lines) => _sectionDataTable(
        title: 'Kalemler',
        headers: const ['Grup', 'Kod', 'Ad', 'Miktar', 'Birim fiyat', 'Tutar'],
        data: [
          for (final l in lines)
            [
              bomGroupTr(l.group),
              l.code,
              l.name,
              formatQty(l.quantity, l.unit),
              formatMoney(l.unitPrice),
              formatMoney(l.total),
            ],
        ],
        headerColor: PdfColors.grey700,
      );

  List<pw.Widget> _materialsSection(List<QuoteLine> lines) => _sectionDataTable(
        title: 'Malzeme listesi',
        headers: const ['Grup', 'Kod', 'Ad', 'Miktar', 'Birim fiyat', 'Tutar'],
        data: [
          for (final l in lines)
            [
              bomGroupTr(l.group),
              l.code,
              l.name,
              formatQty(l.quantity, l.unit),
              formatMoney(l.unitPrice),
              formatMoney(l.total),
            ],
        ],
        headerColor: PdfColors.blueGrey700,
        headerFontSize: 9,
      );

  pw.Widget _companyHeader(ProjectQuote q) {
    final c = q.company;
    final lines = <String>[
      if ((c.address ?? '').trim().isNotEmpty) c.address!.trim(),
      [
        if ((c.phone ?? '').trim().isNotEmpty) 'Tel: ${c.phone!.trim()}',
        if ((c.email ?? '').trim().isNotEmpty) c.email!.trim(),
      ].where((e) => e.isNotEmpty).join('  ·  '),
      [
        if ((c.taxOffice ?? '').trim().isNotEmpty) 'VD: ${c.taxOffice!.trim()}',
        if ((c.taxNumber ?? '').trim().isNotEmpty) 'VN: ${c.taxNumber!.trim()}',
      ].where((e) => e.isNotEmpty).join('  ·  '),
    ].where((e) => e.isNotEmpty).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(c.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        for (final line in lines) pw.Text(line, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      ],
    );
  }

  pw.Widget _windowsSummaryTable(
    ProjectQuote q,
    GlassLook Function(String) lookOf,
    LayoutResult Function(QuoteWindow) layoutOf,
    String currency,
    CatalogSnapshot catalog,
  ) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
      columnWidths: {
        0: const pw.FixedColumnWidth(70),
        1: const pw.FlexColumnWidth(2.2),
        2: const pw.FlexColumnWidth(1.4),
        3: const pw.FixedColumnWidth(36),
        4: const pw.FlexColumnWidth(1.2),
        5: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.blue700),
          children: [
            for (final h in ['Çizim', 'Poz', 'Ölçü', 'Adet', 'Birim fiyat', 'Tutar'])
              pw.Padding(
                padding: const pw.EdgeInsets.all(4),
                child: pw.Text(h, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
              ),
          ],
        ),
        for (final w in q.windows)
          pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.all(3),
                child: pdfWindowDrawing(
                  design: w.design,
                  layout: layoutOf(w),
                  lookOf: lookOf,
                  color: _profileColor(catalog, w.design.colorCode),
                  showDimensions: false,
                  width: 60,
                  height: 60,
                ),
              ),
              _cell(w.name),
              _cell('${w.width.toStringAsFixed(0)}×${w.height.toStringAsFixed(0)}'),
              _cell('${w.quantity}', align: pw.TextAlign.center),
              _cell(formatMoney(w.unitPrice), align: pw.TextAlign.right),
              _cell(formatMoney(w.lineTotal), align: pw.TextAlign.right),
            ],
          ),
      ],
    );
  }

  pw.Widget _totalsBlock(ProjectQuote q, String currency) {
    pw.Widget row(String label, String value, {bool bold = false, double size = 10}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 2),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 160,
                child: pw.Text(label,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              ),
              pw.SizedBox(width: 12),
              pw.SizedBox(
                width: 110,
                child: pw.Text(value,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
              ),
            ],
          ),
        );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.end,
      children: [
        row('Ara toplam', formatMoney(q.subtotal)),
        row('İskonto (%${_pct(q.discountPct)})', '-${formatMoney(q.discountAmount)}'),
        row('Net', formatMoney(q.netTotal)),
        row('KDV (%${_pct(q.vatRate)})', formatMoney(q.vatAmount)),
        pw.Divider(color: PdfColors.grey400),
        row('GENEL TOPLAM', formatMoney(q.grandTotal), bold: true, size: 12),
      ],
    );
  }

  static pw.Widget _cell(String text, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
        padding: const pw.EdgeInsets.all(4),
        child: pw.Text(text, textAlign: align, style: const pw.TextStyle(fontSize: 8)),
      );

  static String _pct(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toStringAsFixed(1);
}
