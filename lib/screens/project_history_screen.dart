import 'package:flutter/material.dart';

import '../models/dashboard.dart';
import '../services/customer_api.dart';
import '../services/design_api.dart';
import '../utils/format.dart';
import '../widgets/status_badge.dart';

class ProjectHistoryScreen extends StatefulWidget {
  final int projectId;
  const ProjectHistoryScreen({super.key, required this.projectId});

  @override
  State<ProjectHistoryScreen> createState() => _ProjectHistoryScreenState();
}

class _ProjectHistoryScreenState extends State<ProjectHistoryScreen> {
  final _api = CustomerApi();
  List<StatusHistoryEntry> _items = [];
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
      final list = await _api.statusHistory(widget.projectId);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Geçmiş')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _items.isEmpty
                  ? const Center(child: Text('Kayıt yok.'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final e = _items[i];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(formatDateTime(e.at), style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                const SizedBox(height: 6),
                                Row(children: [
                                  if (e.from != null) ...[
                                    StatusBadge(status: e.from!, compact: true),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Icon(Icons.arrow_forward, size: 16),
                                    ),
                                  ],
                                  StatusBadge(status: e.to, compact: true),
                                ]),
                                if ((e.byName ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(e.byName!, style: const TextStyle(fontSize: 12)),
                                ],
                                if ((e.note ?? '').isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(e.note!, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
