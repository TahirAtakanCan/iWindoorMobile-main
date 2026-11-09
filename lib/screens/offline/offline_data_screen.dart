import 'package:flutter/material.dart';

import '../../services/offline/api_dio.dart';
import '../../services/offline/offline_project_store.dart';

class OfflineDataScreen extends StatefulWidget {
  const OfflineDataScreen({super.key});

  @override
  State<OfflineDataScreen> createState() => _OfflineDataScreenState();
}

class _OfflineDataScreenState extends State<OfflineDataScreen> {
  Set<int> _ids = {};
  int _bytes = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    final ids = await OfflineProjectStore.ids();
    final bytes = await sharedResponseCache.totalBytes();
    if (!mounted) return;
    setState(() {
      _ids = ids;
      _bytes = bytes;
      _loading = false;
    });
  }

  String _sizeLabel(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Çevrimdışı veriler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ListTile(
                  title: const Text('Kullanılan alan'),
                  subtitle: Text(_sizeLabel(_bytes)),
                ),
                const Divider(),
                Text('İndirilen projeler', style: Theme.of(context).textTheme.titleMedium),
                if (_ids.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Henüz indirilen proje yok.'),
                  )
                else
                  ..._ids.map(
                    (id) => ListTile(
                      title: Text('Proje #$id'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await OfflineProjectStore.remove(id);
                          await _reload();
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Önbelleği temizle'),
                        content: const Text('Tüm çevrimdışı önbellek silinsin mi?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Temizle')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    await sharedResponseCache.clear();
                    for (final id in [..._ids]) {
                      await OfflineProjectStore.remove(id);
                    }
                    await _reload();
                  },
                  child: const Text('Önbelleği temizle'),
                ),
              ],
            ),
    );
  }
}
