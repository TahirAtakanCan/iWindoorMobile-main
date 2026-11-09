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

double _d(Object? v, [double def = 0]) => v is num ? v.toDouble() : def;
int _i(Object? v, [int def = 1]) => v is num ? v.toInt() : def;

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
        );
      case 'slide':
        final c = (j['children'] as List).map((e) => DesignNode.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        return SlideNode(id: id, left: c[0], right: c[1]);
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
  final DesignNode child;

  const FrameNode({
    required String id,
    required this.child,
    this.bottom = BottomKind.frame,
    this.height,
    this.width,
  }) : super(id);

  FrameNode copyWith({
    String? id,
    BottomKind? bottom,
    double? height,
    double? width,
    DesignNode? child,
    bool clearHeight = false,
    bool clearWidth = false,
  }) =>
      FrameNode(
        id: id ?? this.id,
        bottom: bottom ?? this.bottom,
        height: clearHeight ? null : (height ?? this.height),
        width: clearWidth ? null : (width ?? this.width),
        child: child ?? this.child,
      );

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'frame',
        if (bottom != BottomKind.frame) 'bottom': 'threshold',
        if (height != null) 'height': height,
        if (width != null) 'width': width,
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

  const SashNode({
    required String id,
    required this.opening,
    required this.child,
    this.kind = SashKind.window,
    this.passive = false,
    this.outward = false,
  }) : super(id);

  SashNode copyWith({
    String? id,
    OpeningType? opening,
    DesignNode? child,
    SashKind? kind,
    bool? passive,
    bool? outward,
  }) =>
      SashNode(
        id: id ?? this.id,
        opening: opening ?? this.opening,
        child: child ?? this.child,
        kind: kind ?? this.kind,
        passive: passive ?? this.passive,
        outward: outward ?? this.outward,
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
      };
}

class SlideNode extends DesignNode {
  final DesignNode left, right;
  const SlideNode({required String id, required this.left, required this.right}) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'slide',
        'children': [left.toJson(), right.toJson()],
      };
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

  const WindowDesign({
    required this.width,
    required this.height,
    required this.root,
    this.seriesId,
    this.colorCode = 'white',
    this.bottom = BottomKind.frame,
  });

  /// Yeni özelliklerden hiçbiri yoksa 1, varsa 2. Couple her zaman 2.
  int get schemaVersion => _usesV2 ? 2 : 1;

  bool get _usesV2 {
    if (root is CoupleNode) return true;
    if (bottom != BottomKind.frame) return true;
    return _nodeUsesV2(root);
  }

  static bool _nodeUsesV2(DesignNode n) => switch (n) {
        CoupleNode _ => true,
        FrameNode f =>
          f.bottom != BottomKind.frame || f.height != null || f.width != null || _nodeUsesV2(f.child),
        SplitNode s => s.joint != JointKind.mullion || s.children.any(_nodeUsesV2),
        SashNode s => s.kind != SashKind.window || s.passive || s.outward || _nodeUsesV2(s.child),
        SlideNode s => _nodeUsesV2(s.left) || _nodeUsesV2(s.right),
        FillNode _ => false,
      };

  WindowDesign copyWith({
    double? width,
    double? height,
    DesignNode? root,
    String? seriesId,
    String? colorCode,
    BottomKind? bottom,
  }) =>
      WindowDesign(
        width: width ?? this.width,
        height: height ?? this.height,
        root: root ?? this.root,
        seriesId: seriesId ?? this.seriesId,
        colorCode: colorCode ?? this.colorCode,
        bottom: bottom ?? this.bottom,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'width': width,
        'height': height,
        'series': seriesId,
        'color': colorCode,
        if (bottom != BottomKind.frame) 'bottom': 'threshold',
        'root': root.toJson(),
      };

  factory WindowDesign.fromJson(Map<String, dynamic> j) => WindowDesign(
        width: _d(j['width'], 1000),
        height: _d(j['height'], 1000),
        seriesId: j['series']?.toString(),
        colorCode: (j['color'] as String?) ?? 'white',
        bottom: j['bottom'] == 'threshold' ? BottomKind.threshold : BottomKind.frame,
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
