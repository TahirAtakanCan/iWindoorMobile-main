// Eski sunucu ağacını (window_nodes; Project JSON içindeki rootNode) tasarım belgesine çevirir.
// Backend'deki DesignDocuments.fromLegacy ile aynı kurallar. Sadece önizleme (küçük resim) için kullanılır;
// editör belgeyi zaten sunucudan dönüştürülmüş alır.

import 'model.dart';

class LegacyConverter {
  LegacyConverter._();

  static WindowDesign fromUnitJson(Map<String, dynamic> unit) {
    final w = (unit['width'] as num?)?.toDouble() ?? 1000;
    final h = (unit['height'] as num?)?.toDouble() ?? 1000;
    final root = unit['rootNode'];
    final series = unit['seriesId']?.toString();
    if (root is! Map) return WindowDesign.single(w, h, seriesId: series);
    return WindowDesign(width: w, height: h, seriesId: series, root: _convert(Map<String, dynamic>.from(root)));
  }

  static DesignNode _convert(Map<String, dynamic> n) {
    final type = n['nodeType'] as String? ?? 'EMPTY';
    final kids = ((n['children'] as List?) ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) => ((a['itemOrder'] as num?) ?? 0).compareTo((b['itemOrder'] as num?) ?? 0));
    final id = 'L${n['id']}';
    if ((type == 'MULLION_VERTICAL' || type == 'MULLION_HORIZONTAL') && kids.length >= 2) {
      final vertical = type == 'MULLION_VERTICAL';
      return SplitNode(
        id: id,
        dir: vertical ? SplitDir.v : SplitDir.h,
        sizes: [
          for (final k in kids) ((vertical ? k['width'] : k['height']) as num?)?.toDouble() ?? 1,
        ],
        children: [for (final k in kids) _convert(k)],
      );
    }
    if (kids.length == 1) return _convert(kids.first);
    if (type == 'SASH') {
      return SashNode(id: id, opening: OpeningType.turnLeft, child: _leaf('${id}g', n));
    }
    return _leaf(id, n);
  }

  static FillNode _leaf(String id, Map<String, dynamic> n) {
    final glass = n['glass'];
    final code = glass is Map ? (glass['code'] as String? ?? '') : '';
    return FillNode(id: id, glassCode: code);
  }
}
