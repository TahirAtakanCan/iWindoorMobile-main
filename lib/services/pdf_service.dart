import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/company.dart';
import '../models/project_quote.dart';
import '../models/quote_version.dart';
import '../pdf/pdf_fonts.dart';
import '../pdf/pdf_window_drawing.dart';
import '../utils/cost_breakdown.dart';
import '../utils/design_summary.dart';
import '../utils/format.dart';

export '../utils/format.dart';

String _dateTr(DateTime? d) {
  if (d == null) return '—';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

/// Kapak + her pencere (müşteri teklifi; malzeme sayfası yok).
int expectedQuotePageCount(ProjectQuote q) => 1 + q.windows.length;

SeriesInfo seriesForWindow(CatalogSnapshot catalog, QuoteWindow w) {
  final name = w.seriesName?.trim();
  if (name != null && name.isNotEmpty) {
    for (final s in catalog.series) {
      if (s.name == name) return s;
    }
  }
  return catalog.seriesFor(w.design.seriesId);
}

/// Snapshot → ProjectQuote (PDF için).
ProjectQuote projectQuoteFromSnapshot(
  QuoteVersionSnapshot snap, {
  CompanyProfile? companyFallback,
  String? projectNameFallback,
}) {
  final company = snap.company != null
      ? CompanyProfile.fromJson(snap.company!)
      : (companyFallback ?? const CompanyProfile(name: ''));
  final project = snap.project != null
      ? QuoteProjectInfo.fromJson(snap.project!)
      : QuoteProjectInfo(id: 0, name: projectNameFallback ?? 'Sürüm ${snap.versionNo}');

  return ProjectQuote(
    company: company,
    project: project,
    windows: [
      for (final w in snap.windows)
        QuoteWindow(
          windowId: w.windowId ?? 0,
          name: w.name,
          quantity: w.quantity,
          width: w.width,
          height: w.height,
          design: w.design,
          unitPrice: w.unitPrice,
          lineTotal: w.lineTotal > 0 ? w.lineTotal : w.unitPrice * w.quantity,
          seriesName: w.seriesName ??
              snap.seriesNames[w.design.seriesId ?? ''] ??
              (w.design.seriesId != null ? snap.seriesNames['${w.design.seriesId}'] : null),
          saleUnitPrice: w.unitPrice,
        ),
    ],
    materials: const [],
    extras: snap.extras,
    subtotal: snap.subtotal,
    discountPct: snap.discountPct,
    discountAmount: snap.discountAmount,
    netTotal: snap.netTotal,
    vatRate: snap.vatRate,
    vatAmount: snap.vatAmount,
    grandTotal: snap.grandTotal,
    currency: snap.currency,
  );
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
    final loaded = await PdfFonts.load();
    final font = base ?? loaded.$1;
    final fontBold = bold ?? loaded.$2;
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
          currency,
          catalog: catalog,
        ),
      ],
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

  /// Sürüm snapshot'ından müşteri teklif PDF'i.
  Future<void> shareOrPrintSnapshotQuote(
    QuoteVersionSnapshot snap, {
    required CatalogSnapshot catalog,
    CompanyProfile? companyFallback,
    String? projectNameFallback,
  }) async {
    final q = projectQuoteFromSnapshot(
      snap,
      companyFallback: companyFallback,
      projectNameFallback: projectNameFallback,
    );
    await shareOrPrintQuotePdf(q, catalog);
  }

  Future<void> shareSurveyListPdf({
    required String projectName,
    required List<({String room, String type, String opening, int qty, String? note})> rows,
  }) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2));
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text('KEŞİF LİSTESİ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(projectName, style: const pw.TextStyle(fontSize: 11)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Oda', 'Tip', 'Boşluk (mm)', 'Adet', 'Not'],
            data: [
              for (final r in rows) [r.room, r.type, r.opening, '${r.qty}', r.note ?? ''],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Ölçü teyidi / müşteri imza: ________________________', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
    final bytes = await doc.save();
    final name = 'Kesif_${_safeFile(projectName)}.pdf';
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Printing.sharePdf(bytes: bytes, filename: name);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
    }
  }

  Future<Uint8List> buildCostReportPdf(
    ProjectQuote q, {
    pw.Font? base,
    pw.Font? bold,
    bool compress = true,
  }) async {
    if (q.costSummary == null) {
      throw StateError('Maliyet özeti yok.');
    }
    final cost = enrichCostSummary(q);
    final loaded = await PdfFonts.load();
    final font = base ?? loaded.$1;
    final fontBold = bold ?? loaded.$2;
    final pdf = pw.Document(theme: pw.ThemeData.withFont(base: font, bold: fontBold), compress: compress);
    final rows = cost.windows;
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (_) => [
          pw.Text('İÇ MALİYET RAPORU', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(q.project.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(q.company.name, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          pw.Text('Proje özeti', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Kalem', 'Tutar'],
            data: [
              ['Malzeme', formatMoney(cost.materialTotal)],
              ['İşçilik', formatMoney(cost.laborTotal)],
              ['Montaj', formatMoney(cost.installTotal)],
              ['Satış ara toplam', formatMoney(cost.saleSubtotal)],
              ['Brüt kâr', formatMoney(cost.grossProfit)],
              ['Brüt kâr %', formatProfitPct(cost.grossProfitPct)],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
            cellStyle: const pw.TextStyle(fontSize: 9),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
          ),
          pw.SizedBox(height: 14),
          pw.Text('Pencere bazında', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.TableHelper.fromTextArray(
            headers: const ['Poz', 'Malzeme', 'İşçilik', 'Montaj', 'Satış', 'Kâr'],
            data: [
              for (final r in rows)
                [
                  r.name,
                  formatMoney(r.material),
                  formatMoney(r.labor),
                  formatMoney(r.install),
                  formatMoney(r.sale),
                  formatMoney(r.profit),
                ],
            ],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo700),
            cellStyle: const pw.TextStyle(fontSize: 8),
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  Future<void> shareOrPrintCostReport(ProjectQuote q) async {
    final bytes = await buildCostReportPdf(q);
    final name = 'Maliyet_${_safeFile(q.project.name)}.pdf';
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await Printing.sharePdf(bytes: bytes, filename: name);
    } else {
      await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
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
      if (q.extras.isNotEmpty) ...[
        pw.SizedBox(height: 14),
        pw.Text('Ek kalemler', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        _extrasTable(q.extras),
      ],
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
    String currency, {
    required CatalogSnapshot catalog,
  }) {
    final seriesLabel = w.seriesName?.trim().isNotEmpty == true
        ? w.seriesName!.trim()
        : seriesForWindow(catalog, w).name;
    final colorLabel = _colorTitle(catalog, w.design.colorCode) ?? 'Beyaz';
    final profileColor = _profileColor(catalog, w.design.colorCode);
    final summary = summarizeDesign(w.design, catalog: catalog);
    return [
      pw.Text(w.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text(
        '$seriesLabel · $colorLabel · ${w.quantity} adet',
        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
      ),
      pw.Text(
        '${w.width.round()} × ${w.height.round()} mm',
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
      pw.Text('Cam: ${summary.glassLabel}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Açılım: ${summary.openingLabel}', style: const pw.TextStyle(fontSize: 10)),
      if (summary.screenLabel.isNotEmpty)
        pw.Text('Sineklik: ${summary.screenLabel}', style: const pw.TextStyle(fontSize: 10)),
      if (summary.shutterLabel.isNotEmpty)
        pw.Text('Panjur: ${summary.shutterLabel}', style: const pw.TextStyle(fontSize: 10)),
      if (summary.extrasLabel.isNotEmpty)
        pw.Text('Ek profiller: ${summary.extrasLabel}', style: const pw.TextStyle(fontSize: 10)),
      pw.SizedBox(height: 10),
      pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Birim: ${formatMoney(w.displaySaleUnit)}   ·   Tutar: ${formatMoney(w.lineTotal)}',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ),
    ];
  }

  pw.Widget _extrasTable(List<QuoteExtra> extras) {
    return pw.TableHelper.fromTextArray(
      headers: const ['Kalem', 'Miktar', 'Birim fiyat', 'Tutar'],
      data: [
        for (final e in extras)
          [e.name, formatQty(e.quantity, e.unit), formatMoney(e.unitPrice), formatMoney(e.total)],
      ],
      headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
    );
  }

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
