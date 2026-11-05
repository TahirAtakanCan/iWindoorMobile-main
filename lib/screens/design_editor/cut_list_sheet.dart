import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../services/design_api.dart';
import 'design_controller.dart';

/// Kesim listesi (çizim motorundan, anında) + sunucu teklifi (kaydedilmiş hâl, güncel fiyatlarla).
class CutListSheet extends StatefulWidget {
  final DesignController c;
  const CutListSheet({super.key, required this.c});

  static Future<void> show(BuildContext context, DesignController c) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => FractionallySizedBox(heightFactor: .85, child: CutListSheet(c: c)),
      );

  @override
  State<CutListSheet> createState() => _CutListSheetState();
}

class _CutListSheetState extends State<CutListSheet> {
  Future<Quote>? _quote;

  static const _groups = [
    (BomGroup.profile, 'Profil'),
    (BomGroup.bead, 'Cam çıtası'),
    (BomGroup.duplex, 'Dubleks'),
    (BomGroup.glass, 'Cam'),
    (BomGroup.panel, 'Panel'),
  ];

  static String _hwKindTr(String? kind) => switch (kind) {
        'TURN' => 'Açılır',
        'TILT' => 'Vasistas',
        'TILT_TURN' => 'Çift açılım',
        'SLIDE' => 'Sürme',
        _ => kind ?? '—',
      };

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final lines = BomLine.aggregate(c.layout.bom);
    final theme = Theme.of(context);
    double meters(bool Function(BomLine) f) =>
        lines.where((l) => l.isBar && f(l)).fold(0.0, (a, l) => a + l.length! * l.qty / 1000);
    final area = lines
        .where((l) => l.group == BomGroup.glass || l.group == BomGroup.panel)
        .fold(0.0, (a, l) => a + l.w! * l.h! * l.qty / 1e6);
    final hw = lines.where((l) => l.group == BomGroup.hardware).toList();

    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Kesim listesi'), Tab(text: 'Teklif')]),
        Expanded(
          child: TabBarView(children: [
            ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 16, runSpacing: 4, children: [
                Text('Profil: ${meters((l) => l.group == BomGroup.profile).toStringAsFixed(2)} m'),
                Text('Çıta: ${meters((l) => l.group == BomGroup.bead).toStringAsFixed(2)} m'),
                Text('Cam/panel: ${area.toStringAsFixed(3)} m²'),
                Text('1 adet için · seri: ${c.series.name}', style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 12),
              for (final (group, title) in _groups)
                if (lines.any((l) => l.group == group)) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowHeight: 32,
                      dataRowMinHeight: 30,
                      dataRowMaxHeight: 34,
                      columns: const [
                        DataColumn(label: Text('Parça')),
                        DataColumn(label: Text('Ölçü (mm)'), numeric: true),
                        DataColumn(label: Text('Kesim')),
                        DataColumn(label: Text('Kod')),
                        DataColumn(label: Text('Adet'), numeric: true),
                      ],
                      rows: [
                        for (final l in lines.where((l) => l.group == group))
                          DataRow(cells: [
                            DataCell(Text(l.label)),
                            DataCell(Text(l.isBar ? l.length!.round().toString() : '${l.w!.round()} × ${l.h!.round()}')),
                            DataCell(Text(l.cut ?? '—')),
                            DataCell(Text(l.glassCode ?? '—')),
                            DataCell(Text('${l.qty}')),
                          ]),
                      ],
                    ),
                  ),
                ],
              if (hw.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text('Donanım', style: theme.textTheme.titleSmall),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 34,
                    columns: const [
                      DataColumn(label: Text('Tür')),
                      DataColumn(label: Text('Kanat (G×Y)')),
                      DataColumn(label: Text('Adet'), numeric: true),
                    ],
                    rows: [
                      for (final l in hw)
                        DataRow(cells: [
                          DataCell(Text(_hwKindTr(l.kind))),
                          DataCell(Text('${l.w!.round()} × ${l.h!.round()}')),
                          DataCell(Text('${l.qty}')),
                        ]),
                    ],
                  ),
                ),
              ],
            ]),
            ListView(padding: const EdgeInsets.all(16), children: [
              if (c.dirty)
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Kaydedilmemiş değişiklikler var. Teklif, sunucudaki son kaydedilmiş hâle göre hesaplanır.'),
                  ),
                ),
              FilledButton.icon(
                icon: const Icon(Icons.request_quote),
                label: const Text('Güncel fiyatlarla teklif al'),
                onPressed: () => setState(() => _quote = c.api.quote(c.windowId)),
              ),
              const SizedBox(height: 12),
              if (_quote != null)
                FutureBuilder<Quote>(
                  future: _quote,
                  builder: (context, s) {
                    if (s.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (s.hasError) return Text(ApiError.from(s.error!).toString());
                    final q = s.data!;
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final w in q.warnings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text('⚠ $w', style: TextStyle(color: theme.colorScheme.error)),
                        ),
                      for (final l in q.lines)
                        ListTile(
                          dense: true,
                          title: Text(l.name),
                          subtitle: Text('${l.code} · ${l.quantity.toStringAsFixed(3)} ${l.unit} × '
                              '${l.unitPrice.toStringAsFixed(2)}'),
                          trailing: Text('${l.total.toStringAsFixed(2)} ${q.currency}'),
                        ),
                      const Divider(),
                      ListTile(
                        title: const Text('Birim fiyat'),
                        trailing: Text('${q.unitTotal.toStringAsFixed(2)} ${q.currency}'),
                      ),
                      ListTile(
                        title: Text('Toplam (${q.quantity} adet)'),
                        trailing: Text('${q.total.toStringAsFixed(2)} ${q.currency}',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                    ]);
                  },
                ),
            ]),
          ]),
        ),
      ]),
    );
  }
}
