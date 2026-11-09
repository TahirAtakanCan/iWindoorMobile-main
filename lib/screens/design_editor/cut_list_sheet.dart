import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../services/design_api.dart';
import '../../utils/bom_display.dart';
import '../../utils/format.dart';
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

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final lines = BomLine.aggregate(c.layout.bom);
    final cutRows = workshopCutLines(lines);
    final glassRows = lines.where((l) => l.group == BomGroup.glass || l.group == BomGroup.panel).toList();
    final hw = lines.where((l) => l.group == BomGroup.hardware).toList();
    final theme = Theme.of(context);
    double meters(bool Function(BomLine) f) =>
        lines.where((l) => l.isBar && f(l)).fold(0.0, (a, l) => a + l.length! * l.qty / 1000);
    final area = glassRows.fold(0.0, (a, l) => a + l.w! * l.h! * l.qty / 1e6);

    return DefaultTabController(
      length: 2,
      child: Column(children: [
        const TabBar(tabs: [Tab(text: 'Kesim listesi'), Tab(text: 'Teklif')]),
        Expanded(
          child: TabBarView(children: [
            ListView(padding: const EdgeInsets.all(16), children: [
              Wrap(spacing: 16, runSpacing: 4, children: [
                Text('Profil: ${formatQty(meters((l) => l.group == BomGroup.profile), 'm')}'),
                Text('Çıta: ${formatQty(meters((l) => l.group == BomGroup.bead), 'm')}'),
                Text('Cam/panel: ${formatQty(area, 'm²')}'),
                Text('1 adet için · seri: ${c.series.name}', style: theme.textTheme.bodySmall),
              ]),
              const SizedBox(height: 12),
              if (cutRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text('Kesim', style: theme.textTheme.titleSmall),
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
                      DataColumn(label: Text('Adet'), numeric: true),
                    ],
                    rows: [
                      for (final l in cutRows)
                        DataRow(cells: [
                          DataCell(Text(l.label)),
                          DataCell(Text(l.length?.round().toString() ?? '—')),
                          DataCell(Text(l.cut ?? '—')),
                          DataCell(Text('${l.qty}')),
                        ]),
                    ],
                  ),
                ),
              ],
              if (glassRows.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Text('Cam / panel', style: theme.textTheme.titleSmall),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 32,
                    dataRowMinHeight: 30,
                    dataRowMaxHeight: 34,
                    columns: const [
                      DataColumn(label: Text('Kod')),
                      DataColumn(label: Text('Ölçü (mm)')),
                      DataColumn(label: Text('Adet'), numeric: true),
                    ],
                    rows: [
                      for (final l in glassRows)
                        DataRow(cells: [
                          DataCell(Text(l.glassCode ?? '—')),
                          DataCell(Text('${l.w!.round()} × ${l.h!.round()}')),
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
                          DataCell(Text(hardwareKindTr(l.kind))),
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
                      for (final l in sortedQuoteLines(q.lines))
                        ListTile(
                          dense: true,
                          title: Text(l.name),
                          subtitle: Text('${groupTr(l.group)} · ${l.code} · ${formatQty(l.quantity, l.unit)} × ${formatMoney(l.unitPrice)}'),
                          trailing: Text(formatMoney(l.total)),
                        ),
                      const Divider(),
                      ListTile(
                        title: const Text('Birim fiyat'),
                        trailing: Text(formatMoney(q.unitTotal)),
                      ),
                      ListTile(
                        title: Text('Toplam (${q.quantity} adet)'),
                        trailing: Text(formatMoney(q.total),
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
