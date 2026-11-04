// Tasarım modeli: sunucuya JSON olarak kaydedilen TEK şey.
// Ölçü/geometri burada tutulmaz; sadece yapı, oranlar ve tipler.
// Geometri her seferinde LayoutEngine ile bu modelden yeniden üretilir.
// JSON biçimi backend'deki DesignDocumentValidator ile birebir aynıdır.

enum SplitDir { v, h }

/// Açılım tipleri. Adları (turnLeft...) JSON'daki "open" değeridir.
enum OpeningType { turnLeft, turnRight, tilt, tiltTurnLeft, tiltTurnRight }

enum FillType { glass, panel }

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
        return SplitNode(id: id, dir: j['dir'] == 'V' ? SplitDir.v : SplitDir.h, sizes: sizes, children: children);
      case 'sash':
        return SashNode(
          id: id,
          opening: OpeningType.values.byName(j['open'] as String),
          child: DesignNode.fromJson(Map<String, dynamic>.from(j['child'] as Map)),
        );
      case 'slide':
        final c = (j['children'] as List).map((e) => DesignNode.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        return SlideNode(id: id, left: c[0], right: c[1]);
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

/// Alanı dikey (V: yan yana) ya da yatay (H: alt alta) orta kayıtlarla böler.
/// [sizes] ağırlıktır: referans aralığı (kasa dışı / kayıt ekseni) bu oranlarla paylaştırılır.
class SplitNode extends DesignNode {
  final SplitDir dir;
  final List<double> sizes;
  final List<DesignNode> children;
  const SplitNode({required String id, required this.dir, required this.sizes, required this.children}) : super(id);

  @override
  Map<String, dynamic> toJson() => {
        'id': id,
        'type': 'split',
        'dir': dir == SplitDir.v ? 'V' : 'H',
        'sizes': sizes,
        'children': children.map((c) => c.toJson()).toList(),
      };
}

class SashNode extends DesignNode {
  final OpeningType opening;
  final DesignNode child;
  const SashNode({required String id, required this.opening, required this.child}) : super(id);

  @override
  Map<String, dynamic> toJson() => {'id': id, 'type': 'sash', 'open': opening.name, 'child': child.toJson()};
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
  static const schemaVersion = 1;
  final double width, height;
  final String? seriesId;
  final String colorCode;
  final DesignNode root;

  const WindowDesign({
    required this.width,
    required this.height,
    required this.root,
    this.seriesId,
    this.colorCode = 'white',
  });

  WindowDesign copyWith({double? width, double? height, DesignNode? root, String? seriesId, String? colorCode}) =>
      WindowDesign(
        width: width ?? this.width,
        height: height ?? this.height,
        root: root ?? this.root,
        seriesId: seriesId ?? this.seriesId,
        colorCode: colorCode ?? this.colorCode,
      );

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'width': width,
        'height': height,
        'series': seriesId,
        'color': colorCode,
        'root': root.toJson(),
      };

  factory WindowDesign.fromJson(Map<String, dynamic> j) => WindowDesign(
        width: _d(j['width'], 1000),
        height: _d(j['height'], 1000),
        seriesId: j['series']?.toString(),
        colorCode: (j['color'] as String?) ?? 'white',
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
