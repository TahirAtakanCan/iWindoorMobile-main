import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../drawing/design_canvas.dart';
import '../../services/design_api.dart';
import '../../widgets/opening_icon.dart';
import 'cut_list_sheet.dart';
import 'design_controller.dart';
import 'properties_panel.dart';

/// Yeni pencere editörü. Çizim ve hesap tamamen cihazda; sunucuya sadece "Kaydet" ile gidilir.
/// Geniş ekranda (masaüstü/tablet) üç sütun, telefonda araç çubuğu + çizim + alt sayfa.
class DesignEditorScreen extends StatefulWidget {
  final int windowId;
  final String? title;
  final DesignApi? api;

  const DesignEditorScreen({super.key, required this.windowId, this.title, this.api});

  @override
  State<DesignEditorScreen> createState() => _DesignEditorScreenState();
}

class _DesignEditorScreenState extends State<DesignEditorScreen> {
  late final DesignController c = DesignController(api: widget.api ?? DesignApi(), windowId: widget.windowId);
  bool _showLabels = false;
  final TransformationController _zoom = TransformationController();

  static const _wideBreakpoint = 900.0;

  @override
  void initState() {
    super.initState();
    c.load();
  }

  @override
  void dispose() {
    c.dispose();
    _zoom.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final issues = c.issues;
    if (issues.any((i) => i.isError)) {
      final err = issues.firstWhere((i) => i.isError);
      _snack(err.message, error: true);
      return;
    }
    if (issues.isNotEmpty) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Uyarılar'),
          content: Text(
            'Tasarımda ${issues.length} uyarı var. Uyarılarla kaydedilsin mi?\n\n'
            '${issues.map((i) => '• ${i.message}').join('\n')}',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final ok = await c.save();
    if (!mounted) return;
    if (ok) {
      final price = c.savedUnitPrice;
      _snack('Kaydedildi${price != null ? ' · birim fiyat ${price.toStringAsFixed(2)} TL' : ''}');
      return;
    }
    if (c.saveState == SaveState.conflict) {
      await _resolveConflict();
    } else {
      _snack(c.saveMessage ?? 'Kaydedilemedi.', error: true);
    }
  }

  void _showIssues() {
    final issues = c.issues;
    if (issues.isEmpty) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                issues.any((i) => i.isError) ? 'Hatalar ve uyarılar' : 'Uyarılar',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final i in issues)
              ListTile(
                leading: Icon(
                  i.isError ? Icons.error_outline : Icons.warning_amber_rounded,
                  color: i.isError ? Theme.of(ctx).colorScheme.error : Colors.orange.shade800,
                ),
                title: Text(i.message),
                onTap: () {
                  if (i.nodeIds.isNotEmpty) c.select(i.nodeIds.first);
                  Navigator.pop(ctx);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _resolveConflict() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pencere başka bir yerde değişti'),
        content: const Text(
            'Bu pencere siz düzenlerken başka bir cihazda (ör. masaüstü) kaydedildi.\n\n'
            'Güncel hâli yükleyebilir ya da kendi değişikliklerinizle üzerine yazabilirsiniz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'reload'), child: const Text('Güncel hâli yükle')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'overwrite'), child: const Text('Üzerine yaz')),
        ],
      ),
    );
    if (choice == 'reload') {
      await c.reloadFromServer();
      if (mounted) _snack('Sunucudaki güncel hâl yüklendi.');
    } else if (choice == 'overwrite') {
      final ok = await c.save(overwrite: true);
      if (mounted) _snack(ok ? 'Üzerine yazıldı.' : (c.saveMessage ?? 'Kaydedilemedi.'), error: !ok);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<bool> _confirmLeave() async {
    if (!c.dirty) return true;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydedilmemiş değişiklikler'),
        content: const Text('Çıkmadan önce kaydetmek ister misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('Kaydetmeden çık')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('Kaydet')),
        ],
      ),
    );
    if (choice == 'discard') return true;
    if (choice == 'save') {
      await _save();
      return !c.dirty;
    }
    return false;
  }

  void _openProperties() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(heightFactor: .7, child: PropertiesPanel(c: c)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return PopScope(
          canPop: !c.dirty,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop) return;
            final leave = await _confirmLeave();
            if (leave && context.mounted) Navigator.of(context).pop();
          },
          child: CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true): c.undo,
              const SingleActivator(LogicalKeyboardKey.keyY, control: true): c.redo,
              const SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true): c.redo,
              const SingleActivator(LogicalKeyboardKey.keyS, control: true): _save,
              const SingleActivator(LogicalKeyboardKey.keyZ, meta: true): c.undo,
              const SingleActivator(LogicalKeyboardKey.keyS, meta: true): _save,
            },
            child: Focus(autofocus: true, child: _scaffold(context)),
          ),
        );
      },
    );
  }

  Widget _scaffold(BuildContext context) {
    final title = c.loading ? (widget.title ?? 'Yükleniyor…') : c.name;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
          if (c.dirty)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Tooltip(message: 'Kaydedilmemiş değişiklik var', child: Icon(Icons.circle, size: 10)),
            ),
        ]),
        actions: c.loading || c.loadError != null
            ? null
            : [
                IconButton(
                    tooltip: 'Geri al (Ctrl+Z)', icon: const Icon(Icons.undo), onPressed: c.canUndo ? c.undo : null),
                IconButton(
                    tooltip: 'İleri al (Ctrl+Y)', icon: const Icon(Icons.redo), onPressed: c.canRedo ? c.redo : null),
                IconButton(
                  tooltip: 'Cam kodlarını göster',
                  isSelected: _showLabels,
                  icon: const Icon(Icons.label_outline),
                  selectedIcon: const Icon(Icons.label),
                  onPressed: () => setState(() => _showLabels = !_showLabels),
                ),
                IconButton(
                  tooltip: 'Kesim listesi / teklif',
                  icon: const Icon(Icons.list_alt),
                  onPressed: () => CutListSheet.show(context, c),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: c.saveState == SaveState.saving
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : IconButton(
                          tooltip: 'Kaydet (Ctrl+S)',
                          icon: const Icon(Icons.save),
                          onPressed: c.dirty ? _save : null,
                        ),
                ),
              ],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (c.loading) return const Center(child: CircularProgressIndicator());
    if (c.loadError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text(c.loadError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: c.load, child: const Text('Tekrar dene')),
          ]),
        ),
      );
    }
    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wideBreakpoint;
      final canvas = _canvas(context);
      if (wide) {
        return Row(children: [
          SizedBox(width: 132, child: _Toolbox(c: c, vertical: true)),
          const VerticalDivider(width: 1),
          Expanded(child: Column(children: [Expanded(child: canvas), _statusBar(context)])),
          const VerticalDivider(width: 1),
          SizedBox(width: 340, child: PropertiesPanel(c: c)),
        ]);
      }
      return Column(children: [
        _Toolbox(c: c, vertical: false),
        const Divider(height: 1),
        Expanded(child: canvas),
        _statusBar(context, onProperties: _openProperties),
      ]);
    });
  }

  Widget _canvas(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: InteractiveViewer(
        transformationController: _zoom,
        minScale: 0.6,
        maxScale: 6,
        boundaryMargin: const EdgeInsets.all(200),
        child: LayoutBuilder(
          builder: (context, box) => SizedBox(
            width: box.maxWidth,
            height: box.maxHeight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DesignCanvas(
                design: c.design,
                layout: c.layout,
                lookOf: c.lookOf,
                selectedId: c.selectedId,
                issueIds: {for (final i in c.issues) ...i.nodeIds},
                showLabels: _showLabels,
                onSelect: (id) {
                  if (id != null) c.select(id);
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBar(BuildContext context, {VoidCallback? onProperties}) {
    final theme = Theme.of(context);
    final fill = c.selectedFill;
    final glass = fill == null ? null : c.catalog.glassByCode(fill.glassCode);
    final issueCount = c.issues.length;
    final hasError = c.issues.any((i) => i.isError);
    final info = [
      '${c.design.width.round()} × ${c.design.height.round()} mm',
      c.series.name,
      if (fill != null) (glass?.name ?? (fill.glassCode.isEmpty ? 'cam seçilmedi' : fill.glassCode)),
      if (c.catalog.fromCache) 'katalog: çevrimdışı kopya',
      if (c.savedUnitPrice != null && !c.dirty) 'birim ${c.savedUnitPrice!.toStringAsFixed(2)} TL',
    ].join('  ·  ');
    return Material(
      color: theme.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(children: [
            Expanded(child: Text(info, style: theme.textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 2)),
            if (issueCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  onPressed: _showIssues,
                  style: TextButton.styleFrom(
                    foregroundColor: hasError ? theme.colorScheme.error : Colors.orange.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(hasError ? '⚠ $issueCount sorun' : '⚠ $issueCount uyarı'),
                ),
              ),
            IconButton(
              tooltip: 'Yakınlaştırmayı sıfırla',
              icon: const Icon(Icons.fit_screen),
              onPressed: () => _zoom.value = Matrix4.identity(),
            ),
            if (onProperties != null)
              FilledButton.tonalIcon(
                onPressed: onProperties,
                icon: const Icon(Icons.tune),
                label: const Text('Özellikler'),
              ),
          ]),
        ),
      ),
    );
  }
}

/// iWindoor tarzı araç kutusu: bölme ve açılım tipleri.
class _Toolbox extends StatelessWidget {
  final DesignController c;
  final bool vertical;
  const _Toolbox({required this.c, required this.vertical});

  @override
  Widget build(BuildContext context) {
    final enabled = c.selectedId != null;
    final current = c.opening;
    final tools = <Widget>[
      _tool(context, 'Dikey ikiye böl', const OpeningIcon.split(SplitDir.v, 2), enabled ? () => c.split(SplitDir.v, 2) : null),
      _tool(context, 'Dikey üçe böl', const OpeningIcon.split(SplitDir.v, 3), enabled ? () => c.split(SplitDir.v, 3) : null),
      _tool(context, 'Yatay ikiye böl', const OpeningIcon.split(SplitDir.h, 2), enabled ? () => c.split(SplitDir.h, 2) : null),
      _tool(context, 'Yatay üçe böl', const OpeningIcon.split(SplitDir.h, 3), enabled ? () => c.split(SplitDir.h, 3) : null),
      _tool(context, 'Bölmeyi kaldır', const OpeningIcon.unsplit(), c.canUnsplit ? c.unsplit : null),
      for (final o in OpeningChoice.values)
        _tool(context, OpeningIcon.label(o), OpeningIcon.opening(o), enabled ? () => c.setOpening(o) : null,
            selected: current == o),
    ];
    if (vertical) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BÖLME', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: tools.sublist(0, 5)),
          const SizedBox(height: 14),
          Text('AÇILIM', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: tools.sublist(5)),
        ]),
      );
    }
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        itemCount: tools.length,
        separatorBuilder: (_, i) => i == 4 ? const VerticalDivider(width: 14) : const SizedBox(width: 6),
        itemBuilder: (_, i) => tools[i],
      ),
    );
  }

  Widget _tool(BuildContext context, String tip, Widget icon, VoidCallback? onTap, {bool selected = false}) {
    final scheme = Theme.of(context).colorScheme;
    final color = onTap == null
        ? scheme.onSurface.withValues(alpha: .3)
        : (selected ? scheme.onPrimary : scheme.primary);
    return Tooltip(
      message: tip,
      child: Material(
        color: selected ? scheme.primary : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: SizedBox(
            width: 50,
            height: 44,
            child: Center(child: IconTheme(data: IconThemeData(color: color), child: icon)),
          ),
        ),
      ),
    );
  }
}
