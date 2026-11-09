import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../models/catalog.dart';
import '../../models/company.dart';
import '../../models/project.dart';
import '../../pdf/pdf_fonts.dart';
import '../../pdf/workshop_pdf.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/company_api.dart';
import '../../services/design_api.dart';
import '../../services/production_planner.dart';
import '../../utils/format.dart';

class ProductionScreen extends StatefulWidget {
  final int projectId;
  final Project? project;
  final CatalogSnapshot? catalog;

  const ProductionScreen({
    super.key,
    required this.projectId,
    this.project,
    this.catalog,
  });

  @override
  State<ProductionScreen> createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  final _companyApi = CompanyApi();
  final _designApi = DesignApi();
  final _api = ApiService();

  Project? _project;
  CatalogSnapshot? _catalog;
  CompanyProfile? _company;
  bool _loading = true;
  String? _error;
  bool _isAdmin = false;
  bool _busy = false;

  double _kerf = 4;
  double _trim = 10;
  double _minOffcut = 500;
  String? _selectedCode;

  ProjectCutPlan? _cutPlan;
  GlassOrder? _glassOrder;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await AuthService().getRole();
      final cat = widget.catalog ?? await _designApi.catalog();
      final project = widget.project ?? await _api.getProject(widget.projectId);
      final company = await _companyApi.getCompany();
      if (!mounted) return;
      if (project == null) {
        setState(() {
          _loading = false;
          _error = 'Proje bulunamadı.';
        });
        return;
      }
      setState(() {
        _isAdmin = role == 'COMPANY_ADMIN';
        _catalog = cat;
        _company = company;
        _project = project;
        _kerf = company.sawKerfMm;
        _trim = company.barTrimMm;
        _minOffcut = company.minOffcutMm;
        _loading = false;
      });
      _recompute();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _recompute() {
    final project = _project;
    final catalog = _catalog;
    if (project == null || catalog == null) return;
    final plan = ProductionPlanner.buildCutPlan(
      project,
      catalog,
      kerf: _kerf,
      trim: _trim,
      minOffcut: _minOffcut,
    );
    final glass = ProductionPlanner.buildGlassOrder(project, catalog);
    setState(() {
      _cutPlan = plan;
      _glassOrder = glass;
      if (_selectedCode == null && plan.groups.isNotEmpty) {
        _selectedCode = plan.groups.first.code;
      } else if (_selectedCode != null && !plan.groups.any((g) => g.code == _selectedCode)) {
        _selectedCode = plan.groups.isEmpty ? null : plan.groups.first.code;
      }
    });
  }

  Future<void> _saveDefaults() async {
    final c = _company;
    if (c == null || !_isAdmin) return;
    setState(() => _busy = true);
    try {
      final saved = await _companyApi.updateCompany(c.copyWith(
        sawKerfMm: _kerf,
        barTrimMm: _trim,
        minOffcutMm: _minOffcut,
      ));
      if (!mounted) return;
      setState(() {
        _company = saved;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Üretim varsayılanları kaydedildi.')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _shareWorkshopPdf() async {
    final project = _project;
    final catalog = _catalog;
    final company = _company;
    final plan = _cutPlan;
    if (project == null || catalog == null || company == null || plan == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await WorkshopPdf().build(
        project: project,
        catalog: catalog,
        company: company,
        cutPlan: plan,
        minOffcutMm: _minOffcut,
      );
      final name = 'Atolye_${_safe(project.name)}.pdf';
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF hatası: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareGlassPdf() async {
    final project = _project;
    final company = _company;
    final glass = _glassOrder;
    if (project == null || company == null || glass == null || _busy) return;
    setState(() => _busy = true);
    try {
      final bytes = await _buildGlassPdf(project, company, glass);
      final name = 'CamSiparis_${_safe(project.name)}.pdf';
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await Printing.sharePdf(bytes: bytes, filename: name);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF hatası: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _shareGlassCsv() async {
    final project = _project;
    final company = _company;
    final glass = _glassOrder;
    if (project == null || company == null || glass == null || _busy) return;
    setState(() => _busy = true);
    try {
      final csv = _glassCsv(project, company, glass);
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(csv)]);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/CamSiparis_${_safe(project.name)}.csv');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'text/csv')]));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('CSV hatası: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _safe(String s) => s.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();

  String _glassCsv(Project project, CompanyProfile company, GlassOrder glass) {
    final now = DateTime.now();
    final buf = StringBuffer();
    buf.writeln('Firma;${company.name}');
    buf.writeln('Proje;${project.name}');
    buf.writeln('Tarih;${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}');
    if ((company.glassSupplierName ?? '').isNotEmpty) buf.writeln('Cam firması;${company.glassSupplierName}');
    if ((company.glassSupplierPhone ?? '').isNotEmpty) buf.writeln('Telefon;${company.glassSupplierPhone}');
    if ((company.glassOrderNote ?? '').isNotEmpty) buf.writeln('Not;${company.glassOrderNote}');
    buf.writeln();
    buf.writeln('Grup;Kod;Poz;Genişlik;Yükseklik;Adet;m2');
    for (final g in glass.groups) {
      for (final l in g.lines) {
        buf.writeln(
          '${g.isPanel ? 'Paneller' : g.name};${g.code};${l.posLabel};${l.width.round()};${l.height.round()};${l.qty};${l.areaM2.toStringAsFixed(3).replaceAll('.', ',')}',
        );
      }
    }
    buf.writeln('TOPLAM;;;;${glass.totalQty};${glass.totalAreaM2.toStringAsFixed(3).replaceAll('.', ',')}');
    return buf.toString();
  }

  Future<Uint8List> _buildGlassPdf(Project project, CompanyProfile company, GlassOrder glass) async {
    final fonts = await PdfFonts.load();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: fonts.$1, bold: fonts.$2));
    final now = DateTime.now();
    final date = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final widgets = <pw.Widget>[
      pw.Text('CAM SİPARİŞ LİSTESİ', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 6),
      pw.Text(company.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.Text('Proje: ${project.name}', style: const pw.TextStyle(fontSize: 10)),
      pw.Text('Tarih: $date', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
      if ((company.glassSupplierName ?? '').isNotEmpty)
        pw.Text(
          'Cam firması: ${company.glassSupplierName}${company.glassSupplierPhone != null ? ' · ${company.glassSupplierPhone}' : ''}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      if ((company.glassOrderNote ?? '').isNotEmpty)
        pw.Text('Not: ${company.glassOrderNote}', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 12),
    ];
    for (final g in glass.groups) {
      widgets.add(pw.Text(
        g.isPanel ? 'Paneller' : '${g.code} · ${g.name}',
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
      ));
      widgets.add(pw.SizedBox(height: 4));
      widgets.add(pw.TableHelper.fromTextArray(
        headers: const ['Poz', 'Ölçü (mm)', 'Adet', 'm²'],
        data: [
          for (final l in g.lines)
            [l.posLabel, '${l.width.round()} × ${l.height.round()}', '${l.qty}', l.areaM2.toStringAsFixed(3)],
          ['', 'Grup toplam', '${g.totalQty}', g.totalAreaM2.toStringAsFixed(3)],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
        headerDecoration: const pw.BoxDecoration(color: PdfColors.teal700),
        cellStyle: const pw.TextStyle(fontSize: 8),
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.3),
      ));
      widgets.add(pw.SizedBox(height: 10));
    }
    widgets.add(pw.Text(
      'Genel toplam: ${glass.totalQty} adet · ${glass.totalAreaM2.toStringAsFixed(3)} m²',
      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
    ));
    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      build: (_) => widgets,
    ));
    return doc.save();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Üretim'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Kesim planı'),
            Tab(text: 'Cam siparişi'),
            Tab(text: 'Atölye föyü'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _project == null
                  ? const Center(child: Text('Proje yüklenemedi.'))
                  : TabBarView(
                      controller: _tabs,
                      children: [
                        _cutTab(),
                        _glassTab(),
                        _workshopTab(),
                      ],
                    ),
    );
  }

  Widget _cutTab() {
    final plan = _cutPlan;
    if (plan == null) return const Center(child: Text('Plan yok.'));
    ProfileCutGroup? selected;
    for (final g in plan.groups) {
      if (g.code == _selectedCode) {
        selected = g;
        break;
      }
    }
    selected ??= plan.groups.isEmpty ? null : plan.groups.first;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: _settingsRow(),
        ),
        if (plan.allUncuttable.isNotEmpty)
          Material(
            color: Colors.red.shade50,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.warning_amber, color: Colors.red),
              title: Text('${plan.allUncuttable.length} parça boydan uzun — kesilemez.'),
            ),
          ),
        SizedBox(
          height: 92,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final g in plan.groups)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '${g.code}\n${g.plan.totalBars} boy · ${g.totalMeters.toStringAsFixed(1)} m · %${g.wastePct.toStringAsFixed(0)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11, height: 1.2),
                    ),
                    selected: _selectedCode == g.code,
                    onSelected: (_) => setState(() => _selectedCode = g.code),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: selected == null
              ? const Center(child: Text('Profil seçin.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: selected.plan.bars.length + (selected.plan.uncuttable.isEmpty ? 0 : 1),
                  itemBuilder: (_, i) {
                    if (i >= selected!.plan.bars.length) {
                      return Card(
                        color: Colors.red.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kesilemez', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                              for (final u in selected.plan.uncuttable)
                                Text('${u.label} — ${u.length.round()} mm'),
                            ],
                          ),
                        ),
                      );
                    }
                    final bar = selected.plan.bars[i];
                    return _BarCard(index: i + 1, bar: bar, barLength: selected.barLengthMm, minOffcut: _minOffcut);
                  },
                ),
        ),
      ],
    );
  }

  Widget _settingsRow() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _numChip('Testere', _kerf, (v) {
              setState(() => _kerf = v);
              _recompute();
            }),
            _numChip('Kesim payı', _trim, (v) {
              setState(() => _trim = v);
              _recompute();
            }),
            _numChip('Artık sınırı', _minOffcut, (v) {
              setState(() => _minOffcut = v);
              _recompute();
            }),
            if (_isAdmin)
              TextButton.icon(
                onPressed: _busy ? null : _saveDefaults,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: const Text('Varsayılan yap'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _numChip(String label, double value, ValueChanged<double> onChanged) {
    return InkWell(
      onTap: () async {
        final ctrl = TextEditingController(
          text: value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1),
        );
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(label),
            content: TextField(
              controller: ctrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(suffixText: 'mm', border: OutlineInputBorder()),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Tamam')),
            ],
          ),
        );
        if (ok == true) {
          final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
          if (v != null && v >= 0) onChanged(v);
        }
      },
      child: Chip(
        label: Text('$label: ${value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(1)} mm'),
      ),
    );
  }

  Widget _glassTab() {
    final glass = _glassOrder;
    final company = _company;
    if (glass == null) return const Center(child: Text('Cam listesi yok.'));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text(
                'Toplam ${glass.totalQty} adet · ${formatQty(glass.totalAreaM2, 'm2')}'
                '${(company?.glassSupplierName ?? '').isNotEmpty ? '\n${company!.glassSupplierName}' : ''}',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            OutlinedButton.icon(
              onPressed: _busy ? null : _shareGlassCsv,
              icon: const Icon(Icons.table_view),
              label: const Text('CSV'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _shareGlassPdf,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('PDF'),
            ),
          ]),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              for (final g in glass.groups) ...[
                Text(
                  g.isPanel ? 'Paneller' : '${g.code} · ${g.name}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 6),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 16,
                      columns: const [
                        DataColumn(label: Text('Poz')),
                        DataColumn(label: Text('Ölçü')),
                        DataColumn(label: Text('Adet'), numeric: true),
                        DataColumn(label: Text('m²'), numeric: true),
                      ],
                      rows: [
                        for (final l in g.lines)
                          DataRow(cells: [
                            DataCell(Text(l.posLabel)),
                            DataCell(Text('${l.width.round()}×${l.height.round()}')),
                            DataCell(Text('${l.qty}')),
                            DataCell(Text(l.areaM2.toStringAsFixed(3))),
                          ]),
                        DataRow(cells: [
                          const DataCell(Text('Toplam', style: TextStyle(fontWeight: FontWeight.bold))),
                          const DataCell(Text('')),
                          DataCell(Text('${g.totalQty}', style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(g.totalAreaM2.toStringAsFixed(3), style: const TextStyle(fontWeight: FontWeight.bold))),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _workshopTab() {
    final project = _project;
    if (project == null) return const SizedBox.shrink();
    final positions = _catalog == null ? <WorkshopPos>[] : ProductionPlanner.positions(project, _catalog!);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${project.name} · ${positions.length} poz', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Atölye föyü fiyat içermez. Kapak, her poz için çizim/kesim/cam/donanım ve kesim planı üretir.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _shareWorkshopPdf,
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
            label: const Text('PDF üret / paylaş'),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              itemCount: positions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final p = positions[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(p.pos, style: const TextStyle(fontSize: 12))),
                  title: Text(p.unit.name),
                  subtitle: Text('${p.unit.width.round()}×${p.unit.height.round()} · ${p.unit.quantity} adet · ${p.series.name}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BarCard extends StatelessWidget {
  final int index;
  final CutBar bar;
  final double barLength;
  final double minOffcut;
  const _BarCard({required this.index, required this.bar, required this.barLength, required this.minOffcut});

  @override
  Widget build(BuildContext context) {
    final usable = bar.used + bar.remaining;
    final usableOff = bar.remaining >= minOffcut;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Boy $index · ${bar.used.round()} / ${usable.round()} mm (stok ${barLength.round()})',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  for (final p in bar.pieces)
                    Expanded(
                      flex: (p.length * 10).round().clamp(1, 100000),
                      child: Tooltip(
                        message: '${p.label}\n${p.length.round()} mm',
                        child: Container(
                          margin: const EdgeInsets.only(right: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${p.length.round()}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  if (bar.remaining > 0.5)
                    Expanded(
                      flex: (bar.remaining * 10).round().clamp(1, 100000),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: usableOff ? Colors.green.shade200 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          usableOff ? 'Artık ${bar.remaining.round()}' : 'Fire ${bar.remaining.round()}',
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final p in bar.pieces)
              Text(
                '• ${p.label} — ${p.length.round()} mm${p.cut != null ? ' (${p.cut})' : ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}
