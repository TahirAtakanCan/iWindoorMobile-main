import 'package:flutter/foundation.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../drawing/glass_look.dart';
import '../../models/catalog.dart';
import '../../services/design_api.dart';

enum SaveState { idle, saving, saved, conflict, error }

/// Editörün tüm durumu: belge, seçim, geri al/ileri al, kayıt.
/// Her değişiklik yeni bir belge üretir (DesignOps saf fonksiyon); motor anında yeniden hesaplar.
class DesignController extends ChangeNotifier {
  final DesignApi api;
  final int windowId;

  DesignController({required this.api, required this.windowId});

  // --- yüklenen veriler ---
  CatalogSnapshot catalog = CatalogSnapshot.fallback;
  bool loading = true;
  String? loadError;

  // --- pencere ---
  String name = '';
  int quantity = 1;
  int? seriesId;
  int rowVersion = 0;
  double? savedUnitPrice;
  bool legacySource = false;

  late WindowDesign _design;
  LayoutResult? _layout;
  List<RuleIssue>? _issues;
  String? selectedId;

  final List<WindowDesign> _undo = [];
  final List<WindowDesign> _redo = [];
  bool dirty = false;

  SaveState saveState = SaveState.idle;
  String? saveMessage;

  WindowDesign get design => _design;
  LayoutResult get layout {
    if (_layout == null) {
      _layout = LayoutEngine(geometry).run(_design);
      _issues = checkDesign(_layout!, geometry, _design);
    }
    return _layout!;
  }

  /// Seri / yerleşim ile birlikte önbelleklenen kural uyarıları.
  List<RuleIssue> get issues {
    layout;
    return _issues ?? const [];
  }

  SeriesInfo get series => catalog.seriesFor(seriesId);
  SeriesGeometry get geometry => series.geometry;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  FillNode? get selectedFill {
    final id = selectedId;
    if (id == null) return null;
    final n = DesignOps.find(_design.root, id);
    return n is FillNode ? n : null;
  }

  GlassLook lookOf(String code) => GlassLook.forStyle(catalog.glassByCode(code)?.visualStyle);

  // ---------------- yükleme ----------------

  Future<void> load() async {
    loading = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait([api.catalog(), api.getWindow(windowId)]);
      catalog = results[0] as CatalogSnapshot;
      _applyDoc(results[1] as WindowDoc, keepHistory: false);
    } catch (e) {
      loadError = ApiError.from(e).toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  void _applyDoc(WindowDoc doc, {required bool keepHistory}) {
    name = doc.name;
    quantity = doc.quantity;
    seriesId = doc.seriesId ?? (catalog.series.isNotEmpty ? catalog.series.first.id : null);
    rowVersion = doc.rowVersion;
    savedUnitPrice = doc.unitPrice;
    legacySource = doc.legacyDesign;

    // Eski pencerelerden gelen boş cam kodlarını katalog varsayılanıyla doldur
    final normalized = DesignOps.fillMissingCodes(doc.design,
        glass: catalog.defaultGlassCode, panel: catalog.defaultPanelCode);
    _design = normalized.copyWith(seriesId: seriesId?.toString());
    _layout = null;
    _issues = null;
    if (!keepHistory) {
      _undo.clear();
      _redo.clear();
    }
    dirty = doc.legacyDesign || normalized.toJson().toString() != doc.design.toJson().toString();
    final fills = DesignOps.fills(_design.root);
    if (selectedId == null || DesignOps.find(_design.root, selectedId!) == null) {
      selectedId = fills.isNotEmpty ? fills.first.id : null;
    }
  }

  // ---------------- düzenleme ----------------

  void _commit(WindowDesign next, {String? select}) {
    if (identical(next, _design)) return;
    _undo.add(_design);
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
    _design = next;
    _layout = null;
    _issues = null;
    if (select != null) selectedId = select;
    dirty = true;
    if (saveState != SaveState.saving) saveState = SaveState.idle;
    notifyListeners();
  }

  void select(String? id) {
    selectedId = id;
    notifyListeners();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_design);
    _design = _undo.removeLast();
    _afterHistoryMove();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_design);
    _design = _redo.removeLast();
    _afterHistoryMove();
  }

  void _afterHistoryMove() {
    _layout = null;
    _issues = null;
    dirty = true;
    if (selectedId != null && DesignOps.find(_design.root, selectedId!) == null) {
      final f = DesignOps.fills(_design.root);
      selectedId = f.isEmpty ? null : f.first.id;
    }
    notifyListeners();
  }

  void split(SplitDir dir, int parts) {
    final id = selectedId;
    if (id == null) return;
    final r = DesignOps.split(_design, id, dir, parts);
    _commit(r.design, select: r.selectedId);
  }

  void unsplit() {
    final id = selectedId;
    if (id == null) return;
    final r = DesignOps.unsplit(_design, id);
    _commit(r.design, select: r.selectedId);
  }

  bool get canUnsplit => selectedId != null && DesignOps.splitAround(_design.root, selectedId!) != null;

  OpeningChoice? get opening => selectedId == null ? null : DesignOps.openingOf(_design.root, selectedId!);

  void setOpening(OpeningChoice c) {
    final id = selectedId;
    if (id == null) return;
    final r = DesignOps.setOpening(_design, id, c);
    _commit(r.design, select: r.selectedId);
  }

  SashNode? get selectedSash {
    final id = selectedId;
    if (id == null) return null;
    final slot = DesignOps.slotOf(_design.root, id);
    return slot is SashNode ? slot : null;
  }

  SlideNode? get selectedSlide {
    final id = selectedId;
    if (id == null) return null;
    final slot = DesignOps.slotOf(_design.root, id);
    return slot is SlideNode ? slot : null;
  }

  void setSlidePanelCount(int n) {
    final slide = selectedSlide;
    if (slide == null) return;
    final r = DesignOps.setSlidePanelCount(_design, slide.id, n);
    _commit(r.design, select: selectedId);
  }

  void setSlidePanelMove(int index, SlideMove move) {
    final slide = selectedSlide;
    if (slide == null) return;
    final r = DesignOps.setSlidePanelMove(_design, slide.id, index, move);
    _commit(r.design, select: selectedId);
  }

  void setSlideSystem(SlideSystem system) {
    final slide = selectedSlide;
    if (slide == null) return;
    final r = DesignOps.setSlideSystem(_design, slide.id, system);
    _commit(r.design, select: selectedId);
  }

  void setScreen(ScreenKind? screen) {
    final id = selectedId;
    if (id == null) return;
    final sash = selectedSash;
    final target = sash?.id ?? id;
    final r = DesignOps.setScreen(_design, target, screen);
    _commit(r.design, select: selectedId);
  }

  void setSlidePanelScreen(int index, ScreenKind? screen) {
    final slide = selectedSlide;
    if (slide == null || index < 0 || index >= slide.panels.length) return;
    final childId = slide.panels[index].child.id;
    final r = DesignOps.setScreen(_design, childId, screen);
    _commit(r.design, select: selectedId);
  }

  SplitNode? get selectedSplit {
    final id = selectedId;
    if (id == null) return null;
    return DesignOps.splitAround(_design.root, id);
  }

  bool get selectedSplitIsAdapterCandidate {
    final sp = selectedSplit;
    if (sp == null || sp.dir != SplitDir.v || sp.children.length != 2) return false;
    return sp.children.every((c) => c is SashNode);
  }

  void makeDoubleSash() {
    final id = selectedId;
    if (id == null) return;
    final r = DesignOps.makeDoubleSash(_design, id);
    _commit(r.design, select: r.selectedId);
  }

  String? setJoint(JointKind joint) {
    final sp = selectedSplit;
    if (sp == null) return 'Bölme seçili değil.';
    final r = DesignOps.setJoint(_design, sp.id, joint);
    if (r.error != null) return r.error;
    _commit(r.design, select: selectedId);
    return null;
  }

  void setSashKind(SashKind kind) {
    final sash = selectedSash;
    if (sash == null) return;
    final r = DesignOps.setSashKind(_design, sash.id, kind);
    _commit(r.design, select: selectedId);
  }

  void setPassive() {
    final sash = selectedSash;
    if (sash == null) return;
    final r = DesignOps.setPassive(_design, sash.id);
    _commit(r.design, select: selectedId);
  }

  void setOutward(bool outward) {
    final sash = selectedSash;
    if (sash == null) return;
    final r = DesignOps.setOutward(_design, sash.id, outward);
    _commit(r.design, select: selectedId);
  }

  void setBottom(BottomKind bottom) {
    final r = DesignOps.setBottom(_design, bottom);
    _commit(r.design, select: selectedId);
  }

  List<FrameNode> get frames {
    final root = _design.root;
    if (root is CoupleNode) return root.children;
    return const [];
  }

  bool get isCoupled => _design.root is CoupleNode;

  void addFrame(String side, double sizeMm, {double? height, BottomKind bottom = BottomKind.frame}) {
    final r = DesignOps.addFrame(
      _design,
      side,
      sizeMm,
      height: height,
      bottom: bottom,
      glassCode: catalog.defaultGlassCode,
    );
    if (r.error != null) return;
    _commit(r.design, select: r.selectedId);
  }

  void removeFrame(String frameId) {
    final r = DesignOps.removeFrame(_design, frameId);
    _commit(r.design, select: r.selectedId);
  }

  void setFrameSize(String frameId, {double? widthMm, double? heightMm}) {
    final r = DesignOps.setFrameSize(_design, frameId, widthMm: widthMm, heightMm: heightMm);
    _commit(r.design, select: selectedId);
  }

  void setFrameBottom(String frameId, BottomKind bottom) {
    final r = DesignOps.setFrameBottom(_design, frameId, bottom);
    _commit(r.design, select: selectedId);
  }

  ProfileColor profileColor() {
    final cat = catalog.colorByCode(_design.colorCode);
    if (cat != null) return ProfileColor.fromHex(cat.code, cat.name, cat.hexOutside);
    return ProfileColor.of(_design.colorCode);
  }

  void setGlass(String code) {
    final id = selectedId;
    if (id == null) return;
    final isPanel = catalog.glassByCode(code)?.visualStyle == 'panel';
    _commit(DesignOps.updateFill(_design, id, glassCode: code, fill: isPanel ? FillType.panel : FillType.glass).design);
  }

  void setGlassEverywhere(String code) => _commit(DesignOps.setAllGlass(_design, code));

  void setDuplex({int? cols, int? rows}) {
    final id = selectedId;
    if (id == null) return;
    _commit(DesignOps.updateFill(_design, id, duplexCols: cols, duplexRows: rows).design);
  }

  /// Seçili alanın içinde bulunduğu bölme ve parçaların mm ölçüleri.
  (SplitNode, List<double>, int)? get partInfo {
    final id = selectedId;
    if (id == null) return null;
    final sp = DesignOps.splitAround(_design.root, id);
    if (sp == null) return null;
    final span = layout.splitSpans[sp.id];
    if (span == null) return null;
    final slot = DesignOps.slotOf(_design.root, id);
    final index = sp.children.indexWhere((c) => c.id == slot.id);
    return (sp, DesignOps.partSizesMm(sp, span), index);
  }

  void setPartSize(String splitId, int index, double mm) {
    final span = layout.splitSpans[splitId];
    if (span == null) return;
    _commit(DesignOps.setPartSize(_design, splitId, index, mm, span));
  }

  void setSize({double? width, double? height}) {
    final w = (width ?? _design.width).clamp(300, 12000).toDouble();
    final h = (height ?? _design.height).clamp(300, 6000).toDouble();
    if (w == _design.width && h == _design.height) return;
    _commit(_design.copyWith(width: w, height: h));
  }

  void setColor(String code) => _commit(_design.copyWith(colorCode: code));

  void setSeries(int id) {
    seriesId = id;
    _commit(_design.copyWith(seriesId: id.toString()));
  }

  void setName(String v) {
    if (v.trim().isEmpty || v == name) return;
    name = v.trim();
    dirty = true;
    notifyListeners();
  }

  void setQuantity(int v) {
    final q = v.clamp(1, 10000).toInt();
    if (q == quantity) return;
    quantity = q;
    dirty = true;
    notifyListeners();
  }

  // ---------------- kayıt ----------------

  /// true: kaydedildi. Çakışmada saveState = conflict olur; ekran kullanıcıya sorar.
  Future<bool> save({bool overwrite = false}) async {
    saveState = SaveState.saving;
    saveMessage = null;
    notifyListeners();
    try {
      var version = rowVersion;
      if (overwrite) {
        final current = await api.getWindow(windowId);
        version = current.rowVersion;
      }
      final doc = await api.saveWindow(
        id: windowId,
        name: name,
        quantity: quantity,
        seriesId: seriesId,
        design: _design,
        bom: layout.bomJson(),
        rowVersion: version,
      );
      rowVersion = doc.rowVersion;
      savedUnitPrice = doc.unitPrice;
      legacySource = false;
      dirty = false;
      saveState = SaveState.saved;
      return true;
    } on ApiError catch (e) {
      saveState = e.isConflict ? SaveState.conflict : SaveState.error;
      saveMessage = e.toString();
      return false;
    } catch (e) {
      saveState = SaveState.error;
      saveMessage = ApiError.from(e).toString();
      return false;
    } finally {
      notifyListeners();
    }
  }

  /// Çakışmada: benim değişikliklerimi bırak, sunucudaki güncel hâli yükle.
  Future<void> reloadFromServer() async {
    try {
      final doc = await api.getWindow(windowId);
      _applyDoc(doc, keepHistory: false);
      saveState = SaveState.idle;
      saveMessage = null;
    } catch (e) {
      saveState = SaveState.error;
      saveMessage = ApiError.from(e).toString();
    }
    notifyListeners();
  }
}
