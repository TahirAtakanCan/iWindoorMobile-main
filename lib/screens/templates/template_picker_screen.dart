import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../models/catalog.dart';
import '../../services/auth_service.dart';
import '../../services/design_api.dart';
import '../../services/template_api.dart';
import '../../widgets/design_thumbnail.dart';
import '../design_editor/design_editor_screen.dart';

/// Yeni pencere oluştururken şablon seçimi.
/// [popWithWindow] true ise editöre gitmez; oluşturulan [WindowDoc] ile pop eder.
class TemplatePickerScreen extends StatefulWidget {
  final int projectId;
  final CatalogSnapshot? catalog;
  final DesignApi? designApi;
  final TemplateApi? templateApi;
  final int initialTabIndex;
  final double? presetWidth;
  final double? presetHeight;
  final String? presetName;
  final int presetQuantity;
  final bool popWithWindow;

  const TemplatePickerScreen({
    super.key,
    required this.projectId,
    this.catalog,
    this.designApi,
    this.templateApi,
    this.initialTabIndex = 0,
    this.presetWidth,
    this.presetHeight,
    this.presetName,
    this.presetQuantity = 1,
    this.popWithWindow = false,
  });

  @override
  State<TemplatePickerScreen> createState() => _TemplatePickerScreenState();
}

class _TemplatePickerScreenState extends State<TemplatePickerScreen> with SingleTickerProviderStateMixin {
  late final DesignApi _designApi = widget.designApi ?? DesignApi();
  late final TemplateApi _templateApi = widget.templateApi ?? TemplateApi();
  late final TabController _tabs = TabController(
    length: 4,
    vsync: this,
    initialIndex: widget.initialTabIndex.clamp(0, 3),
  );

  CatalogSnapshot? _catalog;
  List<CompanyTemplate>? _company;
  String? _companyError;
  bool _companyLoading = false;
  bool _companyLoadStarted = false;
  bool _isAdmin = false;
  bool _creating = false;

  static const _wide = 900.0;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _bootstrap();
    _tabs.addListener(_onTab);
  }

  void _onTab() {
    if (!_tabs.indexIsChanging && _tabs.index == 3) _ensureCompanyLoaded();
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTab);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final role = await AuthService().getRole();
    if (mounted) setState(() => _isAdmin = role == 'COMPANY_ADMIN');
    if (_catalog == null) {
      final cat = await _designApi.catalog();
      if (mounted) setState(() => _catalog = cat);
    }
  }

  void _ensureCompanyLoaded() {
    if (_companyLoadStarted || _companyLoading) return;
    _loadCompany();
  }

  Future<void> _loadCompany() async {
    setState(() {
      _companyLoadStarted = true;
      _companyLoading = true;
      _companyError = null;
    });
    try {
      final list = await _templateApi.list();
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      if (!mounted) return;
      setState(() {
        _company = list;
        _companyLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _companyError = ApiError.from(e).toString();
        _companyLoading = false;
      });
    }
  }

  List<DesignTemplate> _builtIns(String category) =>
      builtInTemplates().where((t) => t.category == category).toList();

  int _columns(double width) {
    if (width >= 1200) return 5;
    if (width >= _wide) return 4;
    if (width >= 600) return 3;
    return 2;
  }

  Future<(double, double, int?, String, int)?> _askCreateForm({
    required double defaultW,
    required double defaultH,
    required String title,
    int? preferredSeriesId,
  }) async {
    final cat = _catalog ?? CatalogSnapshot.fallback;
    final wCtrl = TextEditingController(text: (widget.presetWidth ?? defaultW).round().toString());
    final hCtrl = TextEditingController(text: (widget.presetHeight ?? defaultH).round().toString());
    final nameCtrl = TextEditingController(text: widget.presetName ?? title);
    var qty = widget.presetQuantity < 1 ? 1 : widget.presetQuantity;
    int? seriesId = preferredSeriesId;
    if (seriesId == null || !cat.series.any((s) => s.id == seriesId)) {
      seriesId = cat.series.isNotEmpty && cat.series.first.id != 0 ? cat.series.first.id : null;
    }

    return showModalBottomSheet<(double, double, int?, String, int)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Poz adı', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: wCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Genişlik (mm)', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: hCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Yükseklik (mm)', border: OutlineInputBorder()),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Adet'),
                    IconButton(onPressed: () => setLocal(() { if (qty > 1) qty--; }), icon: const Icon(Icons.remove_circle_outline)),
                    Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(onPressed: () => setLocal(() => qty++), icon: const Icon(Icons.add_circle_outline)),
                  ],
                ),
                if (cat.series.where((s) => s.id != 0).isNotEmpty)
                  DropdownButtonFormField<int>(
                    key: ValueKey('series-$seriesId'),
                    initialValue: seriesId,
                    decoration: const InputDecoration(labelText: 'Seri', border: OutlineInputBorder()),
                    items: [
                      for (final s in cat.series)
                        if (s.id != 0) DropdownMenuItem(value: s.id, child: Text(s.name)),
                    ],
                    onChanged: (v) => setLocal(() => seriesId = v),
                  ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    final w = double.tryParse(wCtrl.text.replaceAll(',', '.'));
                    final h = double.tryParse(hCtrl.text.replaceAll(',', '.'));
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Poz adı girin.')));
                      return;
                    }
                    if (w == null || h == null || w < 300 || h < 300 || w > 12000 || h > 6000) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('En 300–12000, boy 300–6000 mm olmalı.'),
                      ));
                      return;
                    }
                    Navigator.pop(ctx, (w, h, seriesId, name, qty));
                  },
                  child: const Text('Oluştur'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickBuiltIn(DesignTemplate t) async {
    final result = await _askCreateForm(defaultW: t.defaultWidth, defaultH: t.defaultHeight, title: t.name);
    if (result == null || !mounted) return;
    final cat = _catalog ?? CatalogSnapshot.fallback;
    final design = DesignOps.fillMissingCodes(
      t.build(result.$1, result.$2, result.$3?.toString() ?? ''),
      glass: cat.defaultGlassCode,
      panel: cat.defaultPanelCode,
    );
    await _create(name: result.$4, design: design, seriesId: result.$3, quantity: result.$5);
  }

  Future<void> _pickEmpty() async {
    final result = await _askCreateForm(defaultW: 1000, defaultH: 1200, title: 'Boş (tek cam)');
    if (result == null || !mounted) return;
    final cat = _catalog ?? CatalogSnapshot.fallback;
    final design = WindowDesign.single(
      result.$1,
      result.$2,
      seriesId: result.$3?.toString(),
      glassCode: cat.defaultGlassCode,
    );
    await _create(name: result.$4, design: design, seriesId: result.$3, quantity: result.$5);
  }

  Future<void> _pickCompany(CompanyTemplate t) async {
    final result = await _askCreateForm(
      defaultW: t.design.width,
      defaultH: t.design.height,
      title: t.name,
      preferredSeriesId: int.tryParse(t.design.seriesId ?? ''),
    );
    if (result == null || !mounted) return;
    final cat = _catalog ?? CatalogSnapshot.fallback;
    final knownGlass = {for (final g in cat.glassOnly.where((g) => g.isActive)) g.code};
    final knownPanel = {for (final g in cat.panels.where((g) => g.isActive)) g.code};
    final design = DesignOps.replaceUnknownCodes(
      applyTemplateDesign(t.design, result.$1, result.$2, result.$3?.toString() ?? t.design.seriesId ?? ''),
      knownGlass,
      knownPanel,
      glass: cat.defaultGlassCode,
      panel: cat.defaultPanelCode,
    );
    await _create(name: result.$4, design: design, seriesId: result.$3, quantity: result.$5);
  }

  Future<void> _create({
    required String name,
    required WindowDesign design,
    required int? seriesId,
    int quantity = 1,
  }) async {
    setState(() => _creating = true);
    try {
      final doc = await _designApi.createWindow(
        projectId: widget.projectId,
        name: name,
        seriesId: seriesId,
        quantity: quantity,
        design: design.copyWith(seriesId: seriesId?.toString() ?? design.seriesId),
      );
      if (!mounted) return;
      if (widget.popWithWindow) {
        Navigator.pop(context, doc);
        return;
      }
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DesignEditorScreen(windowId: doc.id, title: doc.name, api: _designApi),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _renameCompany(CompanyTemplate t) async {
    final ctrl = TextEditingController(text: t.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeniden adlandır'),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      await _templateApi.update(t.id, name: name);
      await _loadCompany();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteCompany(CompanyTemplate t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şablonu sil'),
        content: Text('"${t.name}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _templateApi.delete(t.id);
      await _loadCompany();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _companyMenu(CompanyTemplate t) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.drive_file_rename_outline),
            title: const Text('Yeniden adlandır'),
            onTap: () => Navigator.pop(ctx, 'rename'),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Sil'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
        ]),
      ),
    );
    if (choice == 'rename') await _renameCompany(t);
    if (choice == 'delete') await _deleteCompany(t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şablon seç'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Pencere'),
            Tab(text: 'Kapı'),
            Tab(text: 'Sürme'),
            Tab(text: 'Firmamın şablonları'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabs,
            children: [
              _builtInGrid('WINDOW'),
              _builtInGrid('DOOR'),
              _builtInGrid('SLIDING'),
              _companyTab(),
            ],
          ),
          if (_creating) const ModalBarrier(dismissible: false, color: Color(0x33000000)),
          if (_creating) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _builtInGrid(String category) {
    final items = _builtIns(category);
    return LayoutBuilder(builder: (context, box) {
      final cols = _columns(box.maxWidth);
      return CustomScrollView(
        slivers: [
          if (category == 'WINDOW')
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              sliver: SliverToBoxAdapter(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.crop_square_outlined),
                    title: const Text('Boş (tek cam)'),
                    subtitle: const Text('Eski davranış: tek sabit cam'),
                    onTap: _pickEmpty,
                  ),
                ),
              ),
            ),
          if (items.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Bu kategoride şablon yok.')))
          else
            SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: cols,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final t = items[i];
                    final design = t.build(t.defaultWidth, t.defaultHeight, '0');
                    return InkWell(
                      onTap: () => _pickBuiltIn(t),
                      borderRadius: BorderRadius.circular(8),
                      child: DesignThumbnail(
                        design: design,
                        title: t.name,
                        subtitle: '${t.defaultWidth.round()} × ${t.defaultHeight.round()} mm',
                        catalog: _catalog,
                      ),
                    );
                  },
                  childCount: items.length,
                ),
              ),
            ),
        ],
      );
    });
  }

  Widget _companyTab() {
    if (!_companyLoadStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ensureCompanyLoaded());
    }
    if (_companyLoading) return const Center(child: CircularProgressIndicator());
    if (_companyError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_companyError!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                _companyLoadStarted = false;
                _loadCompany();
              },
              child: const Text('Tekrar dene'),
            ),
          ]),
        ),
      );
    }
    final items = _company ?? const <CompanyTemplate>[];
    if (items.isEmpty) {
      return const Center(child: Text('Henüz firma şablonu yok. Editörden “Şablon olarak kaydet” ile ekleyin.'));
    }
    return LayoutBuilder(builder: (context, box) {
      final cols = _columns(box.maxWidth);
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: cols,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.85,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final t = items[i];
          return GestureDetector(
            onTap: () => _pickCompany(t),
            onLongPress: _isAdmin ? () => _companyMenu(t) : null,
            onSecondaryTap: _isAdmin ? () => _companyMenu(t) : null,
            child: DesignThumbnail(
              design: t.design,
              title: t.name,
              subtitle: '${t.design.width.round()} × ${t.design.height.round()} mm',
              catalog: _catalog,
              seriesId: t.design.seriesId,
            ),
          );
        },
      );
    });
  }
}
