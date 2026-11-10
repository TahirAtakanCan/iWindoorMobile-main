import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:windoor_core/windoor_core.dart';

import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/company.dart';
import '../models/project.dart';
import '../services/production_planner.dart';
import '../utils/bom_display.dart';
import '../utils/format.dart';
import 'pdf_fonts.dart';
import 'pdf_window_drawing.dart';

String _dateTr(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

ProfileColor _profileColor(CatalogSnapshot catalog, String colorCode) {
  final cat = catalog.colorByCode(colorCode);
  if (cat != null) return ProfileColor.fromHex(cat.code, cat.name, cat.hexOutside);
  return ProfileColor.of(colorCode);
}

class WorkshopPdf {
  Future<Uint8List> build({
    required Project project,
    required CatalogSnapshot catalog,
    required CompanyProfile company,
    required ProjectCutPlan cutPlan,
    double? minOffcutMm,
    DateTime? at,
  }) async {
    final minOffcut = minOffcutMm ?? company.minOffcutMm;
    final fonts = await PdfFonts.load();
    final theme = pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2);
    final pdf = pw.Document(theme: theme);
    final when = at ?? DateTime.now();
    final positions = ProductionPlanner.positions(project, catalog);
    GlassLook lookOf(String code) => GlassLook.forStyle(catalog.glassByCode(code)?.visualStyle);

    final widgets = <pw.Widget>[
      ..._cover(project, company, positions, when),
      for (final p in positions) ...[
        pw.NewPage(),
        ..._posPage(p, catalog, lookOf),
      ],
      if (cutPlan.groups.isNotEmpty) ...[
        pw.NewPage(),
        ..._cutPlanSection(cutPlan, minOffcut),
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
        build: (_) => widgets,
      ),
    );
    return pdf.save();
  }

  List<pw.Widget> _cover(Project project, CompanyProfile company, List<WorkshopPos> positions, DateTime when) {
    return [
      pw.Text(company.name, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      if ((company.phone ?? '').isNotEmpty || (company.email ?? '').isNotEmpty)
        pw.Text(
          [company.phone, company.email].where((e) => (e ?? '').isNotEmpty).join(' · '),
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      pw.SizedBox(height: 12),
      pw.Text('ATÖLYE FÖYÜ', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
      pw.SizedBox(height: 8),
      pw.Text(project.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      if ((project.customerName ?? '').trim().isNotEmpty)
        pw.Text('Müşteri: ${project.customerName!.trim()}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Tarih: ${_dateTr(when)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
      pw.SizedBox(height: 14),
      pw.Text('Poz listesi', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Inseparable(
        child: pw.TableHelper.fromTextArray(
          headers: const ['Poz', 'Ad', 'Ölçü', 'Adet', 'Seri', 'Renk'],
          data: [
            for (final p in positions)
              [
                p.pos,
                p.unit.name,
                '${p.unit.width.round()}×${p.unit.height.round()}',
                '${p.unit.quantity}',
                p.series.name,
                p.colorName ?? (p.design.colorCode == 'white' ? 'Beyaz' : p.design.colorCode),
              ],
          ],
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
          cellStyle: const pw.TextStyle(fontSize: 8),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
        ),
      ),
    ];
  }

  List<pw.Widget> _posPage(WorkshopPos p, CatalogSnapshot catalog, GlassLook Function(String) lookOf) {
    final bom = BomLine.aggregate(p.layout.bom);
    final cutRows = workshopCutLines(bom);
    final glasses = bom.where((l) => l.group == BomGroup.glass || l.group == BomGroup.panel).toList();
    final hardware = bom.where((l) => l.group == BomGroup.hardware).toList();
    final screens = bom.where((l) => l.group == BomGroup.screen).toList();
    final issues = checkDesign(p.layout, p.series.geometry, p.design);
    final colorLabel = p.colorName ?? (p.design.colorCode == 'white' ? 'Beyaz' : p.design.colorCode);

    return [
      pw.Text(
        '${p.pos} · ${p.unit.name}',
        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 2),
      pw.Text(
        '${p.unit.width.round()} × ${p.unit.height.round()} mm · ${p.unit.quantity} adet · ${p.series.name} · $colorLabel',
        style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
      ),
      pw.SizedBox(height: 8),
      pw.Center(
        child: pdfWindowDrawing(
          design: p.design,
          layout: p.layout,
          lookOf: lookOf,
          color: _profileColor(catalog, p.design.colorCode),
          showDimensions: true,
          width: 480,
          height: 280,
        ),
      ),
      pw.SizedBox(height: 10),
      if (issues.isNotEmpty) ...[
        pw.Text('Uyarılar', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.orange800)),
        for (final i in issues) pw.Text('• ${i.message}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.orange800)),
        pw.SizedBox(height: 6),
      ],
      ..._sectionTable(
        'Kesim listesi',
        const ['Parça', 'Ölçü (mm)', 'Kesim', 'Adet', 'Toplam'],
        [
          for (final l in cutRows)
            [
              l.label,
              l.length != null ? '${l.length!.round()}' : '—',
              l.cut ?? '—',
              '${l.qty}',
              '${l.qty * p.unit.quantity}',
            ],
        ],
        PdfColors.blueGrey700,
      ),
      pw.SizedBox(height: 8),
      ..._sectionTable(
        'Cam / panel',
        const ['Kod', 'Ölçü', 'Adet', 'Toplam'],
        [
          for (final l in glasses)
            [
              l.glassCode ?? '',
              (l.w != null && l.h != null) ? '${l.w!.round()}×${l.h!.round()}' : '—',
              '${l.qty}',
              '${l.qty * p.unit.quantity}',
            ],
        ],
        PdfColors.teal700,
      ),
      pw.SizedBox(height: 8),
      ..._sectionTable(
        'Donanım',
        const ['Tür', 'Ölçü', 'Adet', 'Toplam'],
        [
          for (final l in hardware)
            [
              hardwareKindTr(l.kind),
              (l.w != null && l.h != null) ? '${l.w!.round()}×${l.h!.round()}' : '—',
              '${l.qty}',
              '${l.qty * p.unit.quantity}',
            ],
        ],
        PdfColors.indigo700,
      ),
      if (screens.isNotEmpty) ...[
        pw.SizedBox(height: 8),
        ..._sectionTable(
          'Sineklik',
          const ['Tür', 'En × Boy', 'Adet', 'm²', 'Toplam'],
          [
            for (final l in screens)
              [
                screenKindBomTr(l.kind),
                (l.w != null && l.h != null) ? '${l.w!.round()} × ${l.h!.round()}' : '—',
                '${l.qty}',
                (l.w != null && l.h != null)
                    ? (l.w! * l.h! * l.qty / 1e6).toStringAsFixed(2)
                    : '—',
                '${l.qty * p.unit.quantity}',
              ],
          ],
          PdfColors.brown700,
        ),
      ],
    ];
  }

  List<pw.Widget> _cutPlanSection(ProjectCutPlan cutPlan, double minOffcut) {
    final out = <pw.Widget>[
      pw.Text('Kesim planı', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 8),
      ..._sectionTable(
        'Özet',
        const ['Kod', 'Ad', 'Boy', 'Metre', 'Fire %'],
        [
          for (final g in cutPlan.groups)
            [
              g.code,
              g.name,
              '${g.plan.totalBars}',
              g.totalMeters.toStringAsFixed(1),
              g.wastePct.toStringAsFixed(1),
            ],
        ],
        PdfColors.blueGrey800,
      ),
      pw.SizedBox(height: 10),
    ];

    for (final g in cutPlan.groups) {
      out.add(pw.Text('${g.code} · ${g.name} (${g.barLengthMm.round()} mm)',
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)));
      out.add(pw.SizedBox(height: 4));
      for (var i = 0; i < g.plan.bars.length; i++) {
        final bar = g.plan.bars[i];
        out.add(pw.Inseparable(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Boy ${i + 1} · kullanılan ${bar.used.round()} · kalan ${bar.remaining.round()}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              _barStrip(bar, g.barLengthMm, minOffcut),
              pw.SizedBox(height: 2),
              for (final p in bar.pieces)
                pw.Text('• ${p.label} — ${p.length.round()} mm${p.cut != null ? ' (${p.cut})' : ''}',
                    style: const pw.TextStyle(fontSize: 7)),
              pw.SizedBox(height: 6),
            ],
          ),
        ));
      }
      if (g.plan.uncuttable.isNotEmpty) {
        out.add(pw.Text('Kesilemeyen:', style: pw.TextStyle(fontSize: 8, color: PdfColors.red800, fontWeight: pw.FontWeight.bold)));
        for (final u in g.plan.uncuttable) {
          out.add(pw.Text('• ${u.label} — ${u.length.round()} mm', style: const pw.TextStyle(fontSize: 7, color: PdfColors.red800)));
        }
      }
      out.add(pw.SizedBox(height: 8));
    }
    return out;
  }

  pw.Widget _barStrip(CutBar bar, double barLength, double minOffcut) {
    final usableHint = bar.used + bar.remaining;
    return pw.Container(
      height: 14,
      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, width: 0.4)),
      child: pw.Row(
        children: [
          for (final p in bar.pieces)
            pw.Expanded(
              flex: (p.length * 10).round().clamp(1, 100000),
              child: pw.Container(
                alignment: pw.Alignment.center,
                color: PdfColors.blueGrey300,
                child: pw.Text('${p.length.round()}', style: const pw.TextStyle(fontSize: 6)),
              ),
            ),
          if (bar.remaining > 0.5)
            pw.Expanded(
              flex: (bar.remaining * 10).round().clamp(1, 100000),
              child: pw.Container(
                color: bar.remaining >= minOffcut ? PdfColors.green200 : PdfColors.grey300,
                alignment: pw.Alignment.center,
                child: pw.Text('${bar.remaining.round()}', style: const pw.TextStyle(fontSize: 6)),
              ),
            ),
          if (usableHint < barLength - 0.5)
            pw.Expanded(
              flex: ((barLength - usableHint) * 10).round().clamp(1, 100000),
              child: pw.Container(color: PdfColors.grey100),
            ),
        ],
      ),
    );
  }

  List<pw.Widget> _sectionTable(String title, List<String> headers, List<List<String>> data, PdfColor headerColor) {
    if (data.isEmpty) {
      return [
        pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.Text('Satır yok.', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
      ];
    }
    final first = data.take(3).toList();
    final rest = data.length > 3 ? data.sublist(3) : const <List<String>>[];
    pw.Widget tableOf(List<List<String>> rows) => pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerCount: 1,
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
          headerDecoration: pw.BoxDecoration(color: headerColor),
          cellStyle: const pw.TextStyle(fontSize: 8),
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
        );
    return [
      pw.Inseparable(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            tableOf(first),
          ],
        ),
      ),
      if (rest.isNotEmpty) tableOf(rest),
    ];
  }
}
