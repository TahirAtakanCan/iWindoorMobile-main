import 'package:flutter/material.dart';

import '../../models/quote_version.dart';
import '../../services/design_api.dart';
import '../../services/version_api.dart';
import '../../utils/format.dart';
import '../../utils/version_compare.dart';

class VersionCompareScreen extends StatefulWidget {
  final List<QuoteVersionSummary> versions;
  final String projectName;

  const VersionCompareScreen({super.key, required this.versions, required this.projectName});

  @override
  State<VersionCompareScreen> createState() => _VersionCompareScreenState();
}

class _VersionCompareScreenState extends State<VersionCompareScreen> {
  final _api = VersionApi();
  QuoteVersionSummary? _a;
  QuoteVersionSummary? _b;
  VersionCompareResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.versions.length >= 2) {
      _a = widget.versions[1];
      _b = widget.versions[0];
      _run();
    }
  }

  Future<void> _run() async {
    final a = _a;
    final b = _b;
    if (a == null || b == null) return;
    setState(() => _busy = true);
    try {
      final sa = await _api.get(a.id);
      final sb = await _api.get(b.id);
      final r = compareVersions(
        grandTotalA: sa.grandTotal,
        grandTotalB: sb.grandTotal,
        windowsA: [for (final w in sa.windows) w.toSnap()],
        windowsB: [for (final w in sb.windows) w.toSnap()],
      );
      if (!mounted) return;
      setState(() {
        _result = r;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiError.from(e).toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sürüm karşılaştır')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<QuoteVersionSummary>(
                initialValue: _a,
                decoration: const InputDecoration(labelText: 'A', border: OutlineInputBorder()),
                items: [
                  for (final v in widget.versions)
                    DropdownMenuItem(value: v, child: Text('Sürüm ${v.versionNo}')),
                ],
                onChanged: (v) => setState(() => _a = v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonFormField<QuoteVersionSummary>(
                initialValue: _b,
                decoration: const InputDecoration(labelText: 'B', border: OutlineInputBorder()),
                items: [
                  for (final v in widget.versions)
                    DropdownMenuItem(value: v, child: Text('Sürüm ${v.versionNo}')),
                ],
                onChanged: (v) => setState(() => _b = v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _run, child: const Text('Karşılaştır')),
          if (_busy) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
          if (_result != null) ...[
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                title: const Text('Genel toplam farkı'),
                subtitle: Text(
                  '${formatMoney(_result!.grandTotalA)} → ${formatMoney(_result!.grandTotalB)}\n'
                  '${formatMoney(_result!.totalDiff)} (%${_result!.totalDiffPct.toStringAsFixed(2).replaceAll('.', ',')})',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text('Pencereler', style: Theme.of(context).textTheme.titleMedium),
            for (final d in _result!.windows.where((x) => x.kind != WindowDiffKind.same))
              Card(
                child: ListTile(
                  leading: Icon(switch (d.kind) {
                    WindowDiffKind.added => Icons.add_circle,
                    WindowDiffKind.removed => Icons.remove_circle,
                    WindowDiffKind.changed => Icons.change_circle,
                    _ => Icons.check,
                  }, color: switch (d.kind) {
                    WindowDiffKind.added => Colors.green,
                    WindowDiffKind.removed => Colors.red,
                    WindowDiffKind.changed => Colors.orange,
                    _ => Colors.grey,
                  }),
                  title: Text(d.name),
                  subtitle: Text(switch (d.kind) {
                    WindowDiffKind.added => 'Eklendi',
                    WindowDiffKind.removed => 'Çıkarıldı',
                    WindowDiffKind.changed => d.changes.join('\n'),
                    _ => 'Aynı',
                  }),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
