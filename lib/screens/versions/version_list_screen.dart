import 'package:flutter/material.dart';

import '../../models/quote_version.dart';
import '../../services/design_api.dart';
import '../../services/version_api.dart';
import '../../utils/format.dart';
import 'version_compare_screen.dart';
import 'version_detail_screen.dart';

class VersionListScreen extends StatefulWidget {
  final int projectId;
  final String projectName;
  final bool projectApproved;

  const VersionListScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.projectApproved = false,
  });

  @override
  State<VersionListScreen> createState() => _VersionListScreenState();
}

class _VersionListScreenState extends State<VersionListScreen> {
  final _api = VersionApi();
  List<QuoteVersionSummary> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.list(widget.projectId);
      list.sort((a, b) => b.versionNo.compareTo(a.versionNo));
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _save() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sürüm kaydet'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Etiket (isteğe bağlı)',
            hintText: 'Örn: Low-E seçeneği',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.create(widget.projectId, label: ctrl.text.trim());
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sürüm kaydedildi.')));
    } catch (e) {
      if (!mounted) return;
      final err = ApiError.from(e);
      final msg = switch (err.code) {
        'VERSION_LIMIT' => 'Sürüm sınırına ulaşıldı.',
        'PROJECT_LOCKED' => 'Proje kilitli; sürüm kaydedilemez.',
        _ => err.toString(),
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sürümler'),
        actions: [
          if (_items.length >= 2)
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VersionCompareScreen(projectId: widget.projectId, versions: _items, projectName: widget.projectName),
                  ),
                );
              },
              child: const Text('Karşılaştır'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _save,
        icon: const Icon(Icons.save_outlined),
        label: const Text('Sürüm kaydet'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('Henüz sürüm yok.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final v = _items[i];
                          return Card(
                            child: ListTile(
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Sürüm ${v.versionNo}${v.label != null && v.label!.isNotEmpty ? ' · ${v.label}' : ''}',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (v.approved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: const Text('Onaylanan', style: TextStyle(fontSize: 11, color: Colors.blue)),
                                    ),
                                ],
                              ),
                              subtitle: Text([
                                formatDateTime(v.createdAt),
                                if ((v.createdByName ?? '').isNotEmpty) v.createdByName!,
                                formatMoney(v.grandTotal),
                                '${v.windowCount} pencere',
                              ].join(' · ')),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VersionDetailScreen(
                                      versionId: v.id,
                                      projectId: widget.projectId,
                                      projectName: widget.projectName,
                                      projectApproved: widget.projectApproved,
                                      summary: v,
                                    ),
                                  ),
                                );
                                _load();
                              },
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
