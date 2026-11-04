import 'package:windoor_core/windoor_core.dart';

/// GET /api/v1/catalog/snapshot cevabı. Çevrimdışı çizim için yerelde de saklanır.
class CatalogSnapshot {
  final List<SeriesInfo> series;
  final List<GlassInfo> glasses;
  final List<ProfileInfo> profiles;
  final DateTime? generatedAt;
  final bool fromCache;

  const CatalogSnapshot({
    required this.series,
    required this.glasses,
    required this.profiles,
    this.generatedAt,
    this.fromCache = false,
  });

  /// Sunucuya ulaşılamazsa ve önbellek de yoksa: örnek seri, cam yok.
  static const fallback = CatalogSnapshot(
    series: [SeriesInfo(id: 0, name: 'Varsayılan seri', geometry: SeriesGeometry(id: '0'))],
    glasses: [],
    profiles: [],
  );

  factory CatalogSnapshot.fromJson(Map<String, dynamic> j, {bool fromCache = false}) => CatalogSnapshot(
        series: [for (final s in (j['series'] as List? ?? const [])) SeriesInfo.fromJson(Map<String, dynamic>.from(s as Map))],
        glasses: [for (final g in (j['glasses'] as List? ?? const [])) GlassInfo.fromJson(Map<String, dynamic>.from(g as Map))],
        profiles: [
          for (final p in (j['profiles'] as List? ?? const [])) ProfileInfo.fromJson(Map<String, dynamic>.from(p as Map))
        ],
        generatedAt: DateTime.tryParse('${j['generatedAt']}'),
        fromCache: fromCache,
      );

  SeriesInfo seriesFor(Object? id) {
    final key = id?.toString();
    for (final s in series) {
      if (s.id.toString() == key) return s;
    }
    return series.isNotEmpty ? series.first : fallback.series.first;
  }

  GlassInfo? glassByCode(String code) {
    for (final g in glasses) {
      if (g.code == code) return g;
    }
    return null;
  }

  List<GlassInfo> get glassOnly => glasses.where((g) => g.visualStyle != 'panel').toList();
  List<GlassInfo> get panels => glasses.where((g) => g.visualStyle == 'panel').toList();

  /// Yeni camlar için varsayılan: tercihen 24 mm şeffaf.
  String get defaultGlassCode {
    final list = glassOnly;
    if (list.isEmpty) return '';
    return list
        .firstWhere((g) => g.visualStyle == 'clear' && (g.thicknessMm ?? 0) >= 20, orElse: () => list.first)
        .code;
  }

  String? get defaultPanelCode => panels.isEmpty ? null : panels.first.code;
}

class SeriesInfo {
  final int id;
  final String name;
  final String? brand;
  final String material;
  final SeriesGeometry geometry;

  const SeriesInfo({required this.id, required this.name, required this.geometry, this.brand, this.material = 'PVC'});

  factory SeriesInfo.fromJson(Map<String, dynamic> j) => SeriesInfo(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        brand: j['brand'] as String?,
        material: j['material'] as String? ?? 'PVC',
        geometry: j['geometry'] is Map
            ? SeriesGeometry.fromJson(Map<String, dynamic>.from(j['geometry'] as Map))
            : SeriesGeometry(id: '${j['id']}'),
      );
}

class GlassInfo {
  final int id;
  final String code;
  final String name;
  final int? thicknessMm;
  final String visualStyle; // clear | lowe | smoke | bronze | mirror | frost | pattern | lam | panel
  final double pricePerSquareMeter;

  const GlassInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.visualStyle,
    required this.pricePerSquareMeter,
    this.thicknessMm,
  });

  factory GlassInfo.fromJson(Map<String, dynamic> j) => GlassInfo(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        thicknessMm: (j['thicknessMm'] as num?)?.toInt(),
        visualStyle: j['visualStyle'] as String? ?? 'clear',
        pricePerSquareMeter: (j['pricePerSquareMeter'] as num?)?.toDouble() ?? 0,
      );
}

class ProfileInfo {
  final int id;
  final int? seriesId;
  final String code;
  final String name;
  final String type;
  final double pricePerMeter;

  const ProfileInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.pricePerMeter,
    this.seriesId,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> j) => ProfileInfo(
        id: (j['id'] as num).toInt(),
        seriesId: (j['seriesId'] as num?)?.toInt(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: j['type'] as String? ?? '',
        pricePerMeter: (j['pricePerMeter'] as num?)?.toDouble() ?? 0,
      );
}
