import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../models/catalog.dart';
import '../../models/survey.dart';
import '../../services/company_api.dart';
import '../../services/design_api.dart';
import '../../services/pdf_service.dart';
import '../../services/survey_api.dart';
import '../../utils/survey_helpers.dart';
import '../../utils/template_create.dart';
import '../design_editor/design_editor_screen.dart';
import '../templates/template_picker_screen.dart';

const _roomSuggestions = [
  'Salon',
  'Mutfak',
  'Yatak odası',
  'Çocuk odası',
  'Banyo',
  'Balkon',
  'Merdiven',
  'Giriş',
];

class SurveyScreen extends StatefulWidget {
  final int projectId;
  final String projectName;
  final CatalogSnapshot? catalog;

  const SurveyScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    this.catalog,
  });

  @override
  State<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  final _api = SurveyApi();
  final _designApi = DesignApi();
  final _picker = ImagePicker();

  final _room = TextEditingController();
  final _width = TextEditingController();
  final _height = TextEditingController();
  final _note = TextEditingController();

  SurveyProductType _type = SurveyProductType.window;
  bool _unitCm = false;
  int _qty = 1;
  double _gapMm = 10;
  List<SurveyItem> _items = [];
  final List<XFile> _pendingPhotos = [];
  bool _loading = true;
  bool _saving = false;
  CatalogSnapshot? _catalog;
  String? _error;

  @override
  void initState() {
    super.initState();
    _catalog = widget.catalog;
    _bootstrap();
  }

  @override
  void dispose() {
    _room.dispose();
    _width.dispose();
    _height.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    try {
      final company = await CompanyApi().getCompany();
      _gapMm = company.surveyGapMm;
      _catalog ??= await _designApi.catalog();
      await _load();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiError.from(e).toString();
      });
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.list(widget.projectId);
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

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _pendingPhotos.add(file));
  }

  Future<void> _save({required bool andNext}) async {
    final room = _room.text.trim();
    final wRaw = double.tryParse(_width.text.replaceAll(',', '.'));
    final hRaw = double.tryParse(_height.text.replaceAll(',', '.'));
    if (room.isEmpty || wRaw == null || hRaw == null || wRaw <= 0 || hRaw <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Oda ve ölçüleri girin.')));
      return;
    }
    final wMm = toMm(wRaw, isCm: _unitCm);
    final hMm = toMm(hRaw, isCm: _unitCm);
    final sug = suggestedWindowSize(wMm, hMm, _gapMm);
    setState(() => _saving = true);
    try {
      final created = await _api.create(
        widget.projectId,
        SurveyItem(
          id: 0,
          room: room,
          productType: _type,
          openingWidthMm: wMm,
          openingHeightMm: hMm,
          suggestedWidthMm: sug.$1,
          suggestedHeightMm: sug.$2,
          quantity: _qty,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        ),
      );
      for (final p in _pendingPhotos) {
        final bytes = await p.readAsBytes();
        await _api.uploadPhoto(created.id, Uint8List.fromList(bytes), filename: p.name);
      }
      _pendingPhotos.clear();
      if (andNext) {
        _width.clear();
        _height.clear();
        _note.clear();
        _qty = 1;
      } else {
        _room.clear();
        _width.clear();
        _height.clear();
        _note.clear();
        _qty = 1;
      }
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _convertOne(SurveyItem item) async {
    if (item.isLinked) return;
    final doc = await Navigator.push<WindowDoc>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePickerScreen(
          projectId: widget.projectId,
          catalog: _catalog,
          designApi: _designApi,
          initialTabIndex: templateTabForProduct(item.productType),
          presetWidth: item.suggestedWidthMm,
          presetHeight: item.suggestedHeightMm,
          presetName: item.room,
          presetQuantity: item.quantity,
          popWithWindow: true,
        ),
      ),
    );
    if (doc == null) return;
    try {
      await _api.link(item.id, doc.id);
      await _load();
      if (!mounted) return;
      final warnings = await _collectWarnings(doc.id);
      if (warnings.isNotEmpty && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Kural uyarıları'),
            content: Text(warnings.join('\n')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red),
      );
    }
  }

  Future<List<String>> _collectWarnings(int windowId) async {
    try {
      final doc = await _designApi.getWindow(windowId);
      final cat = _catalog ?? CatalogSnapshot.fallback;
      final series = cat.seriesFor(doc.design.seriesId);
      final layout = LayoutEngine(series.geometry).run(doc.design);
      final issues = checkDesign(layout, series.geometry, doc.design);
      return [for (final i in issues) i.message];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _convertAll() async {
    final pending = _items.where((e) => !e.isLinked).toList();
    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Çevrilecek kalem yok.')));
      return;
    }
    final lines = [
      for (final i in pending)
        '• ${i.room} → ${defaultTemplateNameFor(i.productType, i.suggestedWidthMm)} '
            '(${i.suggestedWidthMm.round()}×${i.suggestedHeightMm.round()} mm, ${i.quantity} adet)',
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${pending.length} pencere oluşacak'),
        content: SingleChildScrollView(child: Text(lines.join('\n'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    );
    if (ok != true) return;

    final warnings = <String>[];
    for (final item in pending) {
      try {
        final tpl = defaultTemplateNameFor(item.productType, item.suggestedWidthMm);
        final doc = await createWindowFromTemplateName(
          api: _designApi,
          projectId: widget.projectId,
          templateName: tpl,
          width: item.suggestedWidthMm,
          height: item.suggestedHeightMm,
          name: item.room,
          quantity: item.quantity,
          catalog: _catalog,
        );
        await _api.link(item.id, doc.id);
        final w = await _collectWarnings(doc.id);
        if (w.isNotEmpty) warnings.add('${item.room}:\n${w.join('\n')}');
      } catch (e) {
        warnings.add('${item.room}: ${ApiError.from(e)}');
      }
    }
    await _load();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sonuç'),
        content: Text(warnings.isEmpty ? 'Tüm kalemler çevrildi.' : warnings.join('\n\n')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
      ),
    );
  }

  Future<void> _exportPdf() async {
    try {
      await PdfService().shareSurveyListPdf(
        projectName: widget.projectName,
        rows: [
          for (final i in _items)
            (
              room: i.room,
              type: surveyProductTr(i.productType),
              opening: '${i.openingWidthMm.round()} × ${i.openingHeightMm.round()}',
              qty: i.quantity,
              note: i.note,
            ),
        ],
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Widget _chipRow<T>({
    required List<(T, String)> options,
    required T selected,
    required ValueChanged<T> onSelect,
  }) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(o.$2),
            selected: selected == o.$1,
            onSelected: (_) => onSelect(o.$1),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keşif'),
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Keşif PDF', onPressed: _items.isEmpty ? null : _exportPdf),
          TextButton(onPressed: _convertAll, child: const Text('Tümünü çevir')),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Hızlı giriş', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _room,
                              decoration: const InputDecoration(labelText: 'Oda', border: OutlineInputBorder()),
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: [
                                for (final r in _roomSuggestions)
                                  ActionChip(label: Text(r), onPressed: () => setState(() => _room.text = r)),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Text('Ürün tipi'),
                            _chipRow(
                              options: [
                                for (final t in SurveyProductType.values) (t, surveyProductTr(t)),
                              ],
                              selected: _type,
                              onSelect: (v) => setState(() => _type = v),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _width,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Genişlik (${_unitCm ? 'cm' : 'mm'})',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _height,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      labelText: 'Yükseklik (${_unitCm ? 'cm' : 'mm'})',
                                      border: const OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('mm')),
                                ButtonSegment(value: true, label: Text('cm')),
                              ],
                              selected: {_unitCm},
                              onSelectionChanged: (s) => setState(() => _unitCm = s.first),
                            ),
                            Row(
                              children: [
                                const Text('Adet'),
                                IconButton(onPressed: () => setState(() { if (_qty > 1) _qty--; }), icon: const Icon(Icons.remove_circle_outline)),
                                Text('$_qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                IconButton(onPressed: () => setState(() => _qty++), icon: const Icon(Icons.add_circle_outline)),
                                const Spacer(),
                                IconButton(tooltip: 'Kamera', onPressed: () => _pickPhoto(ImageSource.camera), icon: const Icon(Icons.photo_camera)),
                                IconButton(tooltip: 'Galeri', onPressed: () => _pickPhoto(ImageSource.gallery), icon: const Icon(Icons.photo_library)),
                              ],
                            ),
                            if (_pendingPhotos.isNotEmpty)
                              Text('${_pendingPhotos.length} fotoğraf eklenecek', style: const TextStyle(fontSize: 12)),
                            TextField(
                              controller: _note,
                              decoration: const InputDecoration(labelText: 'Not', border: OutlineInputBorder()),
                              maxLines: 2,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving ? null : () => _save(andNext: true),
                                    child: const Text('Kaydet ve sonraki'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving ? null : () => _save(andNext: false),
                                    child: const Text('Kaydet'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text('Keşif listesi', style: Theme.of(context).textTheme.titleMedium),
                    if (_items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Henüz kalem yok.')),
                      )
                    else
                      ..._items.map((item) {
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text('${item.room} · ${surveyProductTr(item.productType)}',
                                          style: const TextStyle(fontWeight: FontWeight.w600)),
                                    ),
                                    if (item.isLinked)
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => DesignEditorScreen(
                                                windowId: item.linkedWindowId!,
                                                title: item.linkedWindowName ?? item.room,
                                                api: _designApi,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text('Tasarıma çevrildi'),
                                      )
                                    else
                                      TextButton(onPressed: () => _convertOne(item), child: const Text('Tasarıma çevir')),
                                  ],
                                ),
                                Text(
                                  'Boşluk ${item.openingWidthMm.round()}×${item.openingHeightMm.round()} mm → '
                                  'önerilen ${item.suggestedWidthMm.round()}×${item.suggestedHeightMm.round()} mm · ${item.quantity} adet',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                if ((item.note ?? '').isNotEmpty) Text(item.note!, style: const TextStyle(fontSize: 12)),
                                if (item.photos.isNotEmpty)
                                  SizedBox(
                                    height: 56,
                                    child: ListView(
                                      scrollDirection: Axis.horizontal,
                                      children: [
                                        for (final p in item.photos)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6, top: 6),
                                            child: FutureBuilder<Uint8List>(
                                              future: _api.getPhotoBytes(p.id),
                                              builder: (_, snap) {
                                                if (!snap.hasData) {
                                                  return Container(width: 56, height: 56, color: Colors.grey.shade200);
                                                }
                                                return Image.memory(snap.data!, width: 56, height: 56, fit: BoxFit.cover);
                                              },
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
    );
  }
}
