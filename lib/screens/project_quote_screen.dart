import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/design_canvas.dart';
import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/project_quote.dart';
import '../services/auth_service.dart';
import '../services/company_api.dart';
import '../services/design_api.dart';
import '../services/pdf_service.dart';
import '../utils/cost_breakdown.dart';

const _extraSuggestions = ['Nakliye', 'Söküm', 'Denizlik', 'Montaj malzemesi'];

class ProjectQuoteScreen extends StatefulWidget {
  final int projectId;
  const ProjectQuoteScreen({super.key, required this.projectId});

  @override
  State<ProjectQuoteScreen> createState() => _ProjectQuoteScreenState();
}

class _ProjectQuoteScreenState extends State<ProjectQuoteScreen> {
  final _api = CompanyApi();
  final _designApi = DesignApi();
  final _discountCtl = TextEditingController();

  ProjectQuote? _quote;
  CatalogSnapshot? _catalog;
  bool _loading = true;
  bool _pdfBusy = false;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _discountCtl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final role = await AuthService().getRole();
      final cat = await _designApi.catalog();
      final quote = await _api.getProjectQuote(widget.projectId);
      if (!mounted) return;
      _discountCtl.text = _fmtPct(quote.discountPct);
      setState(() {
        _isAdmin = role == 'COMPANY_ADMIN';
        _catalog = cat;
        _quote = quote;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiError.from(e).toString();
      });
    }
  }

  Future<void> _reloadQuote() async {
    final pct = double.tryParse(_discountCtl.text.replaceAll(',', '.'));
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final quote = await _api.getProjectQuote(widget.projectId, discountPct: pct);
      if (!mounted) return;
      setState(() {
        _quote = quote;
        _loading = false;
        _discountCtl.text = _fmtPct(quote.discountPct);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiError.from(e).toString();
      });
    }
  }

  Future<void> _exportPdf() async {
    final q = _quote;
    final cat = _catalog;
    if (q == null || cat == null || _pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await PdfService().shareOrPrintQuotePdf(q, cat);
    } catch (e) {
      debugPrint('PDF hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulamadı: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _exportCostPdf() async {
    final q = _quote;
    if (q?.costSummary == null || _pdfBusy) return;
    setState(() => _pdfBusy = true);
    try {
      await PdfService().shareOrPrintCostReport(q!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maliyet PDF hatası: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _pdfBusy = false);
    }
  }

  Future<void> _editExtra(QuoteExtra? existing) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final qtyCtrl = TextEditingController(text: existing == null ? '1' : _fmtPct(existing.quantity));
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'adet');
    final priceCtrl = TextEditingController(text: existing == null ? '0' : existing.unitPrice.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Ek kalem' : 'Kalemi düzenle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (existing == null)
              Wrap(
                spacing: 6,
                children: [
                  for (final s in _extraSuggestions)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => nameCtrl.text = s,
                    ),
                ],
              ),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Miktar', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(labelText: 'Birim', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: priceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Birim fiyat', border: OutlineInputBorder(), suffixText: 'TL'),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final extra = QuoteExtra(
      id: existing?.id,
      name: nameCtrl.text.trim(),
      quantity: double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 1,
      unit: unitCtrl.text.trim().isEmpty ? 'adet' : unitCtrl.text.trim(),
      unitPrice: double.tryParse(priceCtrl.text.replaceAll(',', '.')) ?? 0,
      sortOrder: existing?.sortOrder ?? (_quote?.extras.length ?? 0),
    );
    try {
      if (existing?.id == null) {
        await _api.createExtra(widget.projectId, extra);
      } else {
        await _api.updateExtra(widget.projectId, existing!.id!, extra);
      }
      await _reloadQuote();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _deleteExtra(QuoteExtra e) async {
    if (e.id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kalemi sil'),
        content: Text('"${e.name}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteExtra(widget.projectId, e.id!);
      await _reloadQuote();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$err'), backgroundColor: Colors.red));
    }
  }

  static String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proje Teklifi'),
        actions: [
          if (_isAdmin && q?.costSummary != null)
            IconButton(
              tooltip: 'İç maliyet PDF',
              onPressed: _pdfBusy ? null : _exportCostPdf,
              icon: const Icon(Icons.analytics_outlined),
            ),
          IconButton(
            tooltip: 'Müşteri PDF',
            onPressed: q == null || _pdfBusy ? null : _exportPdf,
            icon: _pdfBusy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf),
          ),
        ],
      ),
      body: _loading && q == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && q == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _bootstrap, child: const Text('Yeniden dene')),
                    ]),
                  ),
                )
              : _buildBody(q!),
    );
  }

  Widget _buildBody(ProjectQuote q) {
    final cat = _catalog ?? CatalogSnapshot.fallback;
    return RefreshIndicator(
      onRefresh: _reloadQuote,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _discountCtl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'İskonto %',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _reloadQuote(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.tonal(onPressed: _loading ? null : _reloadQuote, child: const Text('Uygula')),
            ],
          ),
          if (_loading) const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(q.project.name, style: Theme.of(context).textTheme.titleLarge),
          if ((q.project.description ?? '').isNotEmpty)
            Text(q.project.description!, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          ...q.windows.map((w) => _WindowCard(window: w, catalog: cat)),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('Ek kalemler', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editExtra(null),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Ekle'),
              ),
            ],
          ),
          if (q.extras.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text('Ek kalem yok.', style: TextStyle(color: Colors.grey)),
            )
          else
            ...q.extras.map((e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(e.name),
                  subtitle: Text('${formatQty(e.quantity, e.unit)} · ${formatMoney(e.unitPrice)}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatMoney(e.total), style: const TextStyle(fontWeight: FontWeight.w600)),
                    IconButton(icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _editExtra(e)),
                    IconButton(icon: const Icon(Icons.delete_outline, size: 20), onPressed: () => _deleteExtra(e)),
                  ]),
                )),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Toplamlar', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _totalRow('Ara toplam', formatMoney(q.subtotal)),
                  _totalRow('İskonto (%${_fmtPct(q.discountPct)})', '-${formatMoney(q.discountAmount)}'),
                  _totalRow('Net', formatMoney(q.netTotal)),
                  _totalRow('KDV (%${_fmtPct(q.vatRate)})', formatMoney(q.vatAmount)),
                  const Divider(),
                  _totalRow('Genel toplam', formatMoney(q.grandTotal), bold: true),
                ],
              ),
            ),
          ),
          if (q.costSummary != null) ...[
            const SizedBox(height: 16),
            _CostCard(cost: enrichCostSummary(q)),
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
            Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
}

class _CostCard extends StatelessWidget {
  final CostSummary cost;
  const _CostCard({required this.cost});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blueGrey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Maliyet analizi', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _row('Malzeme', formatMoney(cost.materialTotal)),
            _row('İşçilik', formatMoney(cost.laborTotal)),
            _row('Montaj', formatMoney(cost.installTotal)),
            _row('Satış ara toplam', formatMoney(cost.saleSubtotal)),
            _row('Brüt kâr', formatMoney(cost.grossProfit)),
            _row('Brüt kâr %', formatProfitPct(cost.grossProfitPct)),
            if (cost.windows.isNotEmpty) ...[
              const Divider(),
              Text('Pencere bazında', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 12,
                  columns: const [
                    DataColumn(label: Text('Poz')),
                    DataColumn(label: Text('Malzeme'), numeric: true),
                    DataColumn(label: Text('İşçilik'), numeric: true),
                    DataColumn(label: Text('Montaj'), numeric: true),
                    DataColumn(label: Text('Satış'), numeric: true),
                    DataColumn(label: Text('Kâr'), numeric: true),
                  ],
                  rows: [
                    for (final w in cost.windows)
                      DataRow(cells: [
                        DataCell(Text(w.name)),
                        DataCell(Text(formatMoney(w.material))),
                        DataCell(Text(formatMoney(w.labor))),
                        DataCell(Text(formatMoney(w.install))),
                        DataCell(Text(formatMoney(w.sale))),
                        DataCell(Text(formatMoney(w.profit))),
                      ]),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a), Text(b)]),
      );
}

class _WindowCard extends StatelessWidget {
  final QuoteWindow window;
  final CatalogSnapshot catalog;

  const _WindowCard({required this.window, required this.catalog});

  @override
  Widget build(BuildContext context) {
    final layout = LayoutEngine(catalog.seriesFor(window.design.seriesId).geometry).run(window.design);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: DesignCanvas(
                design: window.design,
                layout: layout,
                lookOf: (code) => GlassLook.forStyle(catalog.glassByCode(code)?.visualStyle),
                showDimensions: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(window.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                    if (window.overridden)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('elle', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                      ),
                  ]),
                  Text(
                    '${window.width.toStringAsFixed(0)} × ${window.height.toStringAsFixed(0)} mm'
                    '${window.seriesName != null ? ' · ${window.seriesName}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text('${window.quantity} adet · birim ${formatMoney(window.displaySaleUnit)}'),
                  Text('Tutar: ${formatMoney(window.lineTotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.green)),
                  if (window.warnings.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(window.warnings.join('\n'),
                          style: TextStyle(fontSize: 11, color: Colors.orange.shade800)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
