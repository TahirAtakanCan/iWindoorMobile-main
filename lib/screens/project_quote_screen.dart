import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/design_canvas.dart';
import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/project_quote.dart';
import '../services/company_api.dart';
import '../services/design_api.dart';
import '../services/pdf_service.dart';
import '../utils/bom_display.dart';

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
      final cat = await _designApi.catalog();
      final quote = await _api.getProjectQuote(widget.projectId);
      if (!mounted) return;
      _discountCtl.text = _fmtPct(quote.discountPct);
      setState(() {
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

  static String _fmtPct(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final q = _quote;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Proje Teklifi'),
        actions: [
          IconButton(
            tooltip: 'PDF',
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
          const SizedBox(height: 16),
          Text('Malzeme özeti', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (q.materials.isEmpty)
            const Text('Malzeme satırı yok.', style: TextStyle(color: Colors.grey))
          else
            ...sortedQuoteLines(q.materials).map((m) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.name),
                  subtitle: Text('${groupTr(m.group)} · ${m.code} · ${formatQty(m.quantity, m.unit)}'),
                  trailing: Text(formatMoney(m.total)),
                )),
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
                  Text(window.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    '${window.width.toStringAsFixed(0)} × ${window.height.toStringAsFixed(0)} mm'
                    '${window.seriesName != null ? ' · ${window.seriesName}' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                  ),
                  Text('${window.quantity} adet · birim ${formatMoney(window.unitPrice)}'),
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
