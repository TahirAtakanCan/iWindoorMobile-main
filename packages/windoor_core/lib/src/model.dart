// Tasarım modeli: sunucuya JSON olarak kaydedilen TEK şey.
// Ölçü/geometri burada tutulmaz; sadece yapı, oranlar ve tipler.
// Geometri her seferinde LayoutEngine ile bu modelden yeniden üretilir.
// JSON biçimi backend'deki DesignDocumentValidator ile birebir aynıdır.

enum SplitDir { v, h }

/// Açılım tipleri. Adları (turnLeft...) JSON'daki "open" değeridir.
enum OpeningType { turnLeft, turnRight, tilt, tiltTurnLeft, tiltTurnRight }

enum FillType { glass, panel }

/// Pencere altı: kasa altı veya eşik.
enum BottomKind { frame, threshold }

/// Dikey bölmede iki kanat birleşimi: orta kayıt veya adaptör.
enum JointKind { mullion, adapter }

/// Kanat türü: pencere veya kapı.
enum SashKind { window, door }

/// Sürme sistemi.
enum SlideSystem { standard, liftSlide }

/// Sürme panel hareketi.
enum SlideMove { left, right, fixed }

/// Sineklik türü.
enum ScreenKind { plise, hinged, sliding }

enum ShutterType { mono, external }

enum ShutterSlat { aluminum, pvc }

enum ShutterDrive { manual, motor }

class Shutter {
  final ShutterType type;
  final ShutterSlat slat;
  final ShutterDrive drive;

  const Shutter({required this.type, required this.slat, required this.drive});

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'slat': slat.name,
        'drive': drive.name,
      };

  factory Shutter.fromJson(Map<String, dynamic> j) => Shutter(
        type: ShutterType.values.byName('${j['type']}'),
        slat: ShutterSlat.values.byName('${j['slat']}'),
        drive: ShutterDrive.values.byName('${j['drive']}'),
      );
}

enum TrimKind { none, three, four }

class FrameExtension {
  final double top, left, right, bottom;

  const FrameExtension({this.top = 0, this.left = 0, this.right = 0, this.bottom = 0});

  bool get isEmpty => top == 0 && left == 0 && right == 0 && bottom == 0;

  FrameExtension copyWith({double? top, double? left, double? right, double? bottom}) => FrameExtension(
        top: top ?? this.top,
        left: left ?? this.left,
        right: right ?? this.right,
        bottom: bottom ?? this.bottom,
      );

  Map<String, dynamic> toJson() => {
        if (top != 0) 'top': top,
        if (left != 0) 'left': left,
        if (right != 0) 'right': right,
        if (bottom != 0) 'bottom': bottom,
      };

  factory FrameExtension.fromJson(Object? raw) {
    if (raw is! Map) return const FrameExtension();
    final j = Map<String, dynamic>.from(raw);
    return FrameExtension(
      top: _d(j['top']),
      left: _d(j['left']),
      right: _d(j['right']),
      bottom: _d(j['bottom']),
    );
  }
}

class Extras {
  final bool sillOuter;
  final bool sillInner;
  final TrimKind trim;
  final FrameExtension extension;

  const Extras({
    this.sillOuter = false,
    this.sillInner = false,
    this.trim = TrimKind.none,
    this.extension = const FrameExtension(),
  });

  static const empty = Extras();

  bool get isEmpty => !sillOuter && !sillInner && trim == TrimKind.none && extension.isEmpty;

  Extras copyWith({
    bool? sillOuter,
    bool? sillInner,
    TrimKind? trim,
    FrameExtension? extension,
  }) =>
      Extras(
        sillOuter: sillOuter ?? this.sillOuter,
        sillInner: sillInner ?? this.sillInner,
        trim: trim ?? this.trim,
        extension: extension ?? this.extension,
      );

  Map<String, dynamic> toJson() => {
        if (sillOuter) 'sillOuter': true,
        if (sillInner) 'sillInner': true,
        if (trim != TrimKind.none) 'trim': trim.name,
        if (!extension.isEmpty) 'extension': extension.toJson(),
      };

  factory Extras.fromJson(Object? raw) {
    if (raw is! Map) return Extras.empty;
    final j = Map<String, dynamic>.from(raw);
    final t = '${j['trim'] ?? 'none'}'.toLowerCase();
    final trim = switch (t) {
      'three' || '3' => TrimKind.three,
      'four' || '4' => TrimKind.four,
      _ => TrimKind.none,
    };
    return Extras(
      sillOuter: j['sillOuter'] == true,
      sillInner: j['sillInner'] == true,
      trim: trim,
      extension: FrameExtension.fromJson(j['extension']),
    );
  }
}

/// Üçgen alınlık tepe konumu.
enum TriangleApex { left, center, right }

/// Kasa dış şekli. [RectShape] JSON'da yazılmaz.
sealed class FrameShape {
  const FrameShape();

  bool get isRect => this is RectShape;

  Map<String, dynamic>? toJson();

  static FrameShape fromJson(Object? raw) {
    if (raw == null) return const RectShape();
    if (raw is! Map) return const RectShape();
    final j = Map<String, dynamic>.from(raw);
    switch (j['type']) {
      case 'arch':
        return const ArchShape();
      case 'segmentArch':
        return SegmentArchShape(rise: _d(j['rise'], 100));
      case 'trapezoid':
        return TrapezoidShape(
          leftHeight: _d(j['leftHeight'], 1000),
          rightHeight: _d(j['rightHeight'], 1000),
        );
      case 'triangle':
        final a = '${j['apex'] ?? 'center'}'.toLowerCase();
        final apex = a == 'left'
            ? TriangleApex.left
            : a == 'right'
                ? TriangleApex.right
                : TriangleApex.center;
        return TriangleShape(apex: apex);
      default:
        return const RectShape();
    }
  }
}

class RectShape extends FrameShape {
  const RectShape();
  @override
  Map<String, dynamic>? toJson() => null;
}

class ArchShape extends FrameShape {
  const ArchShape();
  @override
  Map<String, dynamic>? toJson() => {'type': 'arch'};
}

class SegmentArchShape extends FrameShape {
  final double rise;
  const SegmentArchShape({required this.rise});
  @override
  Map<String, dynamic>? toJson() => {'type': 'segmentArch', 'rise': rise};
}

class TrapezoidShape extends FrameShape {
  final double leftHeight, rightHeight;
  const TrapezoidShape({required this.leftHeight, required this.rightHeight});
  @override
  Map<String, dynamic>? toJson() => {
        'type': 'trapezoid',
        'leftHeight': leftHeight,
        'rightHeight': rightHeight,
      };
}

class TriangleShape extends FrameShape {
  final TriangleApex apex;
  const TriangleShape({this.apex = TriangleApex.center});
  @override
  Map<String, dynamic>? toJson() => {'type': 'triangle', 'apex': apex.name};
}

double _d(Object? v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(Object? v, [int def = 1]) => v is num ? v.toInt() : def;

ScreenKind? _screenFromJson(Object? v) {
  if (v == null) return null;
  final s = '$v'.toLowerCase();
  return switch (s) {
    'plise' || 'pileli' => ScreenKind.plise,
    'hinged' || 'menteseli' || 'menteşeli' => ScreenKind.hinged,
    'sliding' || 'surme' || 'sürme' => ScreenKind.sliding,
    _ => null,
  };
}

String _screenJson(ScreenKind k) => k.name;

SlideMove _moveFromJson(Object? v) {
  final s = '$v'.toLowerCase();
  return switch (s) {
    'left' || 'sola' => SlideMove.left,
    'fixed' || 'sabit' => SlideMove.fixed,
    _ => SlideMove.right,
  };
}

SlideSystem _systemFromJson(Object? v) {
  final s = '$v'.toLowerCase();
  return s == 'liftslide' || s == 'lift_slide' || s == 'hs' ? SlideSystem.liftSlide : SlideSystem.standard;
}

sealed class DesignNode {
  final String id;
  const DesignNode(this.id);

  Map<String, dynamic> toJson();

  static DesignNode fromJson(Map<String, dynamic> j) {
    final id = '${j['id']}';
    switch (j['type']) {
      case 'split':
        final children = (j['children'] as List).map((e) => DesignNode.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        final sizes = (j['sizes'] as List).map((e) => _d(e, 1)).toList();
        return SplitNode(
          id: id,
          dir: j['dir'] == 'V' ? SplitDir.v : SplitDir.h,
          sizes: sizes,
          children: children,
          joint: j['joint'] == 'adapter' ? JointKind.adapter : JointKind.mullion,
        );
      case 'sash':
        return SashNode(
          id: id,
          opening: OpeningType.values.byName(j['open'] as String),
          child: DesignNode.fromJson(Map<String, dynamic>.from(j['child'] as Map)),
          kind: j['kind'] == 'door' ? SashKind.door : SashKind.window,
          passive: j['passive'] == true,
          outward: j['outward'] == true,
          screen: _screenFromJson(j['screen']),
        );
      case 'slide':
        return SlideNode.fromJson(id: id, j: j);
      case 'couple':
        final children = (j['children'] as List)
            .map((e) => DesignNode.fromJson(Map<String, dynamic>.from(e as Map)))
            .whereType<FrameNode>()
            .toList();
        final sizes = (j['sizes'] as List).map((e) => _d(e, 1)).toList();
        return CoupleNode(
          id: id,
          dir: j['dir'] == 'H' ? SplitDir.h : SplitDir.v,
          sizes: sizes,
          children: children,
        );
      case 'frame':
        return FrameNode(
          id: id,
          bottom: j['bottom'] == 'threshold' ? BottomKind.threshold : BottomKind.frame,
          height: j['height'] is num ? (j['height'] as num).toDouble() : null,
          width: j['width'] is num ? (j['width'] as num).toDouble() : null,
          shape: FrameShape.fromJson(j['shape']),
          child: DesignNode.fromJson(Map<String, dynamic>.from(j['child'] as Map)),
        );
      case 'glass':
      case 'panel':
        final d = (j['duplex'] as List?) ?? const [1, 1];
        return FillNode(
          id: id,
          fill: j['type'] == 'panel' ? FillType.panel : FillType.glass,
          glassCode: (j['glass'] as String?) ?? '',
          duplexCols: _i(d[0]),
          duplexRows: _i(d[1]),
        );
      default:
        throw FormatException('Bilinmeyen düğüm tipi: ${j['type']}');
    }
  }
}

/// Birleşik doğrama: yalnızca [WindowDesign.root] olabilir.
class CoupleNode extends DesignNode {
  final SplitDir dir;
  final List<double> sizes;
  final List<FrameNode> children;

  const CoupleNode({
    required String id,
    required this.dir,
    required this.sizes,
    required this.children,
  }) : super(id);

  CoupleNode copyWith({
    String? id,
    SplitDir? dir,
    List<double>? sizes,
    List<FrameNode>? children,
  }) =>
      CoupleNode(
        id: id ?? this.id,
        dir: dir ?? this.dir,
        sizes: sizes ?? this.sizes,
        children: children ?? this.children,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'couple',
        'dir': dir == SplitDir.v ? 'V' : 'H',
        'sizes': sizes,
        'children': children.map((c) => c.toJson()).toList(),
      };
}

/// Birleşik doğrama içindeki tek kasa.
class FrameNode extends DesignNode {
  final BottomKind bottom;
  final double? height;
  final double? width;
  final FrameShape shape;
  final DesignNode child;

  const FrameNode({
    required String id,
    required this.child,
    this.bottom = BottomKind.frame,
    this.height,
    this.width,
    this.shape = const RectShape(),
  }) : super(id);

  FrameNode copyWith({
    String? id,
    BottomKind? bottom,
    double? height,
    double? width,
    FrameShape? shape,
    DesignNode? child,
    bool clearHeight = false,
    bool clearWidth = false,
  }) =>
      FrameNode(
        id: id ?? this.id,
        bottom: bottom ?? this.bottom,
        height: clearHeight ? null : (height ?? this.height),
        width: clearWidth ? null : (width ?? this.width),
        shape: shape ?? this.shape,
        child: child ?? this.child,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'frame',
        if (bottom != BottomKind.frame) 'bottom': 'threshold',
        if (height != null) 'height': height,
        if (width != null) 'width': width,
        if (shape.toJson() != null) 'shape': shape.toJson(),
        'child': child.toJson(),
      };
}

/// Alanı dikey (V: yan yana) ya da yatay (H: alt alta) orta kayıtlarla böler.
/// [sizes] ağırlıktır: referans aralığı (kasa dışı / kayıt ekseni) bu oranlarla paylaştırılır.
class SplitNode extends DesignNode {
  final SplitDir dir;
  final List<double> sizes;
  final List<DesignNode> children;
  final JointKind joint;

  const SplitNode({
    required String id,
    required this.dir,
    required this.sizes,
    required this.children,
    this.joint = JointKind.mullion,
  }) : super(id);

  SplitNode copyWith({
    String? id,
    SplitDir? dir,
    List<double>? sizes,
    List<DesignNode>? children,
    JointKind? joint,
  }) =>
      SplitNode(
        id: id ?? this.id,
        dir: dir ?? this.dir,
        sizes: sizes ?? this.sizes,
        children: children ?? this.children,
        joint: joint ?? this.joint,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'split',
        'dir': dir == SplitDir.v ? 'V' : 'H',
        'sizes': sizes,
        'children': children.map((c) => c.toJson()).toList(),
        if (joint != JointKind.mullion) 'joint': 'adapter',
      };
}

class SashNode extends DesignNode {
  final OpeningType opening;
  final DesignNode child;
  final SashKind kind;
  final bool passive;
  final bool outward;
  final ScreenKind? screen;

  const SashNode({
    required String id,
    required this.opening,
    required this.child,
    this.kind = SashKind.window,
    this.passive = false,
    this.outward = false,
    this.screen,
  }) : super(id);

  SashNode copyWith({
    String? id,
    OpeningType? opening,
    DesignNode? child,
    SashKind? kind,
    bool? passive,
    bool? outward,
    ScreenKind? screen,
    bool clearScreen = false,
  }) =>
      SashNode(
        id: id ?? this.id,
        opening: opening ?? this.opening,
        child: child ?? this.child,
        kind: kind ?? this.kind,
        passive: passive ?? this.passive,
        outward: outward ?? this.outward,
        screen: clearScreen ? null : (screen ?? this.screen),
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'sash',
        'open': opening.name,
        'child': child.toJson(),
        if (kind != SashKind.window) 'kind': 'door',
        if (passive) 'passive': true,
        if (outward) 'outward': true,
        if (screen != null) 'screen': _screenJson(screen!),
      };
}

/// Sürme paneli: hareket + isteğe bağlı sineklik + iç düğüm.
class SlidePanel {
  final SlideMove move;
  final ScreenKind? screen;
  final DesignNode child;

  const SlidePanel({required this.move, required this.child, this.screen});

  SlidePanel copyWith({SlideMove? move, ScreenKind? screen, DesignNode? child, bool clearScreen = false}) =>
      SlidePanel(
        move: move ?? this.move,
        child: child ?? this.child,
        screen: clearScreen ? null : (screen ?? this.screen),
      );

  Map<String, dynamic> toJson() => {
        'move': move.name,
        if (screen != null) 'screen': _screenJson(screen!),
        'child': child.toJson(),
      };

  factory SlidePanel.fromJson(Map<String, dynamic> j) => SlidePanel(
        move: _moveFromJson(j['move']),
        screen: _screenFromJson(j['screen']),
        child: DesignNode.fromJson(Map<String, dynamic>.from(j['child'] as Map)),
      );
}

class SlideNode extends DesignNode {
  final SlideSystem system;
  final List<SlidePanel> panels;

  /// [panels] veya eski API: [left]/[right] (sol→right, sağ→left hareket).
  SlideNode({
    required String id,
    DesignNode? left,
    DesignNode? right,
    List<SlidePanel>? panels,
    this.system = SlideSystem.standard,
  })  : panels = panels ??
            [
              SlidePanel(move: SlideMove.right, child: left!),
              SlidePanel(move: SlideMove.left, child: right!),
            ],
        super(id);

  DesignNode get left => panels.first.child;
  DesignNode get right => panels.length > 1 ? panels[1].child : panels.first.child;

  bool get isLegacyShape =>
      system == SlideSystem.standard &&
      panels.length == 2 &&
      panels[0].move == SlideMove.right &&
      panels[1].move == SlideMove.left &&
      panels.every((p) => p.screen == null);

  SlideNode copyWith({String? id, List<SlidePanel>? panels, SlideSystem? system}) => SlideNode(
        id: id ?? this.id,
        panels: panels ?? this.panels,
        system: system ?? this.system,
      );

  factory SlideNode.fromJson({required String id, required Map<String, dynamic> j}) {
    final system = _systemFromJson(j['system']);
    if (j['panels'] is List) {
      final panels = (j['panels'] as List)
          .map((e) => SlidePanel.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return SlideNode(id: id, panels: panels, system: system);
    }
    final c = (j['children'] as List).map((e) => DesignNode.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    return SlideNode(id: id, left: c[0], right: c[1], system: system);
  }

  @override
  Map<String, dynamic> toJson() {
    if (isLegacyShape) {
      return {
        'id': id,
        'type': 'slide',
        'children': [left.toJson(), right.toJson()],
      };
    }
    return {
      'id': id,
      'type': 'slide',
      'system': system == SlideSystem.liftSlide ? 'liftSlide' : 'standard',
      'panels': panels.map((p) => p.toJson()).toList(),
    };
  }
}

/// Yaprak: cam ya da panel. Her zaman bir cam çıtası ile oturur.
class FillNode extends DesignNode {
  final FillType fill;
  final String glassCode; // katalogdaki cam/panel kodu
  final int duplexCols, duplexRows; // cam içi dekoratif çıta (1x1 = yok)
  const FillNode({
    required String id,
    this.fill = FillType.glass,
    this.glassCode = '',
    this.duplexCols = 1,
    this.duplexRows = 1,
  }) : super(id);

  FillNode copyWith({String? id, FillType? fill, String? glassCode, int? duplexCols, int? duplexRows}) => FillNode(
        id: id ?? this.id,
        fill: fill ?? this.fill,
        glassCode: glassCode ?? this.glassCode,
        duplexCols: duplexCols ?? this.duplexCols,
        duplexRows: duplexRows ?? this.duplexRows,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': fill == FillType.panel ? 'panel' : 'glass',
        'glass': glassCode,
        'duplex': [duplexCols, duplexRows],
      };
}

class WindowDesign {
  final double width, height;
  final String? seriesId;
  final String colorCode;
  final DesignNode root;
  final BottomKind bottom;
  /// Tek kasalı tasarımın dış şekli (couple'da her [FrameNode.shape] ayrı).
  final FrameShape shape;
  final Shutter? shutter;
  final Extras extras;

  const WindowDesign({
    required this.width,
    required this.height,
    required this.root,
    this.seriesId,
    this.colorCode = 'white',
    this.bottom = BottomKind.frame,
    this.shape = const RectShape(),
    this.shutter,
    this.extras = Extras.empty,
  });

  /// Yeni özelliklerden hiçbiri yoksa 1, varsa 2. Couple / şekil her zaman 2.
  int get schemaVersion => _usesV2 ? 2 : 1;

  bool get _usesV2 {
    if (root is CoupleNode) return true;
    if (bottom != BottomKind.frame) return true;
    if (!shape.isRect) return true;
    if (shutter != null) return true;
    if (!extras.isEmpty) return true;
    return _nodeUsesV2(root);
  }

  static bool _nodeUsesV2(DesignNode n) => switch (n) {
        CoupleNode _ => true,
        FrameNode f =>
          !f.shape.isRect ||
              f.bottom != BottomKind.frame ||
              f.height != null ||
              f.width != null ||
              _nodeUsesV2(f.child),
        SplitNode s => s.joint != JointKind.mullion || s.children.any(_nodeUsesV2),
        SashNode s =>
          s.kind != SashKind.window || s.passive || s.outward || s.screen != null || _nodeUsesV2(s.child),
        SlideNode s => !s.isLegacyShape || s.panels.any((p) => _nodeUsesV2(p.child)),
        FillNode _ => false,
      };

  WindowDesign copyWith({
    double? width,
    double? height,
    DesignNode? root,
    String? seriesId,
    String? colorCode,
    BottomKind? bottom,
    FrameShape? shape,
    Shutter? shutter,
    Extras? extras,
    bool clearShutter = false,
  }) =>
      WindowDesign(
        width: width ?? this.width,
        height: height ?? this.height,
        root: root ?? this.root,
        seriesId: seriesId ?? this.seriesId,
        colorCode: colorCode ?? this.colorCode,
        bottom: bottom ?? this.bottom,
        shape: shape ?? this.shape,
        shutter: clearShutter ? null : (shutter ?? this.shutter),
        extras: extras ?? this.extras,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'width': width,
        'height': height,
        'series': seriesId,
        'color': colorCode,
        if (bottom != BottomKind.frame) 'bottom': 'threshold',
        if (shape.toJson() != null) 'shape': shape.toJson(),
        if (shutter != null) 'shutter': shutter!.toJson(),
        if (!extras.isEmpty) 'extras': extras.toJson(),
        'root': root.toJson(),
      };

  factory WindowDesign.fromJson(Map<String, dynamic> j) => WindowDesign(
        width: _d(j['width'], 1000),
        height: _d(j['height'], 1000),
        seriesId: j['series']?.toString(),
        colorCode: (j['color'] as String?) ?? 'white',
        bottom: j['bottom'] == 'threshold' ? BottomKind.threshold : BottomKind.frame,
        shape: FrameShape.fromJson(j['shape']),
        shutter: j['shutter'] is Map ? Shutter.fromJson(Map<String, dynamic>.from(j['shutter'] as Map)) : null,
        extras: Extras.fromJson(j['extras']),
        root: DesignNode.fromJson(Map<String, dynamic>.from(j['root'] as Map)),
      );

  /// Tek camlı sabit pencere.
  factory WindowDesign.single(double width, double height, {String? seriesId, String glassCode = ''}) => WindowDesign(
        width: width,
        height: height,
        seriesId: seriesId,
        root: FillNode(id: 'n1', glassCode: glassCode),
      );
}
