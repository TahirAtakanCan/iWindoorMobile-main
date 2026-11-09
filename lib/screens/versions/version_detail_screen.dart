import 'package:flutter/material.dart';

import '../../models/catalog.dart';
import '../../models/quote_version.dart';
import '../../services/auth_service.dart';
import '../../services/company_api.dart';
import '../../services/design_api.dart';
import '../../services/pdf_service.dart';
import '../../services/version_api.dart';
import '../../widgets/design_thumbnail.dart';

class VersionDetailScreen extends StatefulWidget {
  final int versionId;
  final int projectId;
  final String projectName;
  final bool projectApproved;
  final QuoteVersionSummary? summary;

  const VersionDetailScreen({
    super.key,
    required this.versionId,
    required this.projectId,
    required this.projectName,
    this.projectApproved = false,
    this.summary,
  });

  @override
  State<VersionDetailScreen> createState() => _VersionDetailScreenState();
}

class _VersionDetailScreenState extends State<VersionDetailScreen> {
  final _api = VersionApi();
  QuoteVersionSnapshot? _snap;
  CatalogSnapshot? _catalog;
  bool _loading = true;
  bool _isAdmin = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final role = await AuthService().getRole();
    try {
      final snap = await _api.get(widget.versionId);
      final cat = await DesignApi().catalog();
      if (!mounted) return;
      setState(() {
        _isAdmin = role == 'COMPANY_ADMIN';
        _snap = snap;
        _catalog = cat;
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

  Future<void> _pdf() async {
    final snap = _snap;
    final cat = _catalog;
    if (snap == null || cat == null) return;
    try {
      final company = await CompanyApi().getCompany();
      await PdfService().shareOrPrintSnapshotQuote(
        snap,
        catalog: cat,
        companyFallback: company,
        projectNameFallback: widget.projectName,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _restore() async {
    if (widget.projectApproved) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bu sürüme dön'),
        content: const Text(
          'Mevcut hâl otomatik kaydedilecek; fiyatlar güncel katalogla yeniden hesaplanacak.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri yükle')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.restore(widget.versionId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sürüm geri yüklendi.')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final err = ApiError.from(e);
      final msg = switch (err.code) {
        'PROJECT_LOCKED' => 'Proje kilitli.',
        'VERSION_APPROVED' => 'Onaylı sürüm bu şekilde geri yüklenemez.',
        _ => err.toString(),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sürümü sil'),
        content: const Text('Bu sürüm silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.delete(widget.versionId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final snap = _snap;
    return Scaffold(
      appBar: AppBar(
        title: Text(snap != null ? 'Sürüm ${snap.versionNo}' : 'Sürüm'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), tooltip: 'PDF', onPressed: snap == null ? null : _pdf),
          if (_isAdmin)
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: snap == null ? null : _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : snap == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        if ((snap.label ?? '').isNotEmpty)
                          Text(snap.label!, style: Theme.of(context).textTheme.titleMedium),
                        Text(
                          '${formatDateTime(snap.createdAt)}${(snap.createdByName ?? '').isNotEmpty ? ' · ${snap.createdByName}' : ''}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text('Genel toplam: ${formatMoney(snap.grandTotal)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text(
                          'Ara ${formatMoney(snap.subtotal)} · İskonto ${formatMoney(snap.discountAmount)} · '
                          'KDV ${formatMoney(snap.vatAmount)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: widget.projectApproved ? null : _restore,
                          child: const Text('Bu sürüme dön'),
                        ),
                        if (widget.projectApproved)
                          const Padding(
                            padding: EdgeInsets.only(top: 6),
                            child: Text(
                              'Onaylı projede sürüm geri yüklenemez.',
                              style: TextStyle(fontSize: 12, color: Colors.orange),
                            ),
                          ),
                        const SizedBox(height: 16),
                        Text('Pencereler', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snap.windows.length,
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemBuilder: (_, i) {
                            final w = snap.windows[i];
                            return DesignThumbnail(
                              design: w.design,
                              title: w.name,
                              subtitle: '${w.width.round()} × ${w.height.round()} mm'
                                  '${w.quantity > 1 ? ' · ${w.quantity} adet' : ''}',
                              subtitle2: formatMoney(w.unitPrice),
                              catalog: _catalog,
                              seriesId: w.design.seriesId,
                            );
                          },
                        ),
                        if (snap.extras.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Ek kalemler', style: Theme.of(context).textTheme.titleMedium),
                          for (final e in snap.extras)
                            ListTile(
                              dense: true,
                              title: Text(e.name),
                              subtitle: Text('${e.quantity} ${e.unit}'),
                              trailing: Text(formatMoney(e.total)),
                            ),
                        ],
                      ],
                    ),
    );
  }
}
