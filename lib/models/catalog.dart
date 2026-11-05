import 'package:windoor_core/windoor_core.dart';

/// GET /api/v1/catalog/snapshot cevabı. Çevrimdışı çizim için yerelde de saklanır.
class CatalogSnapshot {
  final List<SeriesInfo> series;
  final List<GlassInfo> glasses;
  final List<ProfileInfo> profiles;
  final List<Accessory> accessories;
  final DateTime? generatedAt;
  final bool fromCache;

  const CatalogSnapshot({
    required this.series,
    required this.glasses,
    required this.profiles,
    this.accessories = const [],
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
        accessories: [
          for (final a in (j['accessories'] as List? ?? const [])) Accessory.fromJson(Map<String, dynamic>.from(a as Map))
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

  /// Yeni camlar için varsayılan: tercihen 24 mm şeffaf (aktif olanlar).
  String get defaultGlassCode {
    final list = glassOnly.where((g) => g.isActive).toList();
    final pool = list.isNotEmpty ? list : glassOnly;
    if (pool.isEmpty) return '';
    return pool
        .firstWhere((g) => g.visualStyle == 'clear' && (g.thicknessMm ?? 0) >= 20, orElse: () => pool.first)
        .code;
  }

  String? get defaultPanelCode {
    final active = panels.where((g) => g.isActive).toList();
    final pool = active.isNotEmpty ? active : panels;
    return pool.isEmpty ? null : pool.first.code;
  }
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
  final bool isActive;

  const GlassInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.visualStyle,
    required this.pricePerSquareMeter,
    this.thicknessMm,
    this.isActive = true,
  });

  factory GlassInfo.fromJson(Map<String, dynamic> j) => GlassInfo(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        thicknessMm: (j['thicknessMm'] as num?)?.toInt(),
        visualStyle: j['visualStyle'] as String? ?? 'clear',
        pricePerSquareMeter: (j['pricePerSquareMeter'] as num?)?.toDouble() ?? 0,
        isActive: j['isActive'] as bool? ?? j['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        if (thicknessMm != null) 'thicknessMm': thicknessMm,
        'visualStyle': visualStyle,
        'pricePerSquareMeter': pricePerSquareMeter,
        'isActive': isActive,
      };
}

class ProfileInfo {
  final int id;
  final int? seriesId;
  final String code;
  final String name;
  final String type;
  final double pricePerMeter;
  final int? barLengthMm;
  final bool isDefault;
  final bool isActive;

  const ProfileInfo({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.pricePerMeter,
    this.seriesId,
    this.barLengthMm,
    this.isDefault = false,
    this.isActive = true,
  });

  factory ProfileInfo.fromJson(Map<String, dynamic> j) => ProfileInfo(
        id: (j['id'] as num).toInt(),
        seriesId: (j['seriesId'] as num?)?.toInt(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        type: '${j['type'] ?? ''}',
        pricePerMeter: (j['pricePerMeter'] as num?)?.toDouble() ?? 0,
        barLengthMm: (j['barLengthMm'] as num?)?.toInt() ?? (j['barLength'] as num?)?.toInt(),
        isDefault: j['isDefault'] as bool? ?? j['defaultForType'] as bool? ?? false,
        // ProfileDto alanı "active"; bazı yanıtlar "isActive" kullanabilir.
        isActive: j['isActive'] as bool? ?? j['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (seriesId != null) 'seriesId': seriesId,
        'code': code,
        'name': name,
        'type': type,
        'pricePerMeter': pricePerMeter,
        if (barLengthMm != null) 'barLengthMm': barLengthMm,
        'isDefault': isDefault,
        'isActive': isActive,
      };
}

/// Aksesuar (kol, conta, set…). Birim: PIECE | METER | SET.
class Accessory {
  final int id;
  final String code;
  final String name;
  final String unit;
  final double price;
  final String currency;
  final bool isActive;

  const Accessory({
    required this.id,
    required this.code,
    required this.name,
    required this.unit,
    required this.price,
    this.currency = 'TRY',
    this.isActive = true,
  });

  factory Accessory.fromJson(Map<String, dynamic> j) => Accessory(
        id: (j['id'] as num).toInt(),
        code: j['code'] as String? ?? '',
        name: j['name'] as String? ?? '',
        unit: '${j['unit'] ?? 'PIECE'}',
        price: (j['price'] as num?)?.toDouble() ?? 0,
        currency: j['currency'] as String? ?? 'TRY',
        isActive: j['isActive'] as bool? ?? j['active'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'unit': unit,
        'price': price,
        'currency': currency,
        'isActive': isActive,
      };
}

/// Kanat donanım kuralı: hangi aksesuar, hangi açılım türüne, nasıl sayılır.
class HardwareRule {
  final int id;
  final String kind; // TURN | TILT | TILT_TURN | SLIDE
  final int? seriesId;
  final String accessoryCode;
  final String? accessoryName;
  final String qtyType; // PER_SASH | PER_PERIMETER_METER
  final double qty;

  const HardwareRule({
    required this.id,
    required this.kind,
    required this.accessoryCode,
    required this.qtyType,
    required this.qty,
    this.seriesId,
    this.accessoryName,
  });

  factory HardwareRule.fromJson(Map<String, dynamic> j) => HardwareRule(
        id: (j['id'] as num).toInt(),
        kind: j['kind'] as String? ?? '',
        seriesId: (j['seriesId'] as num?)?.toInt(),
        accessoryCode: j['accessoryCode'] as String? ?? '',
        accessoryName: j['accessoryName'] as String?,
        qtyType: j['qtyType'] as String? ?? 'PER_SASH',
        qty: (j['qty'] as num?)?.toDouble() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind,
        if (seriesId != null) 'seriesId': seriesId,
        'accessoryCode': accessoryCode,
        if (accessoryName != null) 'accessoryName': accessoryName,
        'qtyType': qtyType,
        'qty': qty,
      };
}

/// Toplu zam dry-run / uygulama sonucu.
class PriceAdjustmentResult {
  final int updated;
  const PriceAdjustmentResult(this.updated);

  factory PriceAdjustmentResult.fromJson(Map<String, dynamic> j) =>
      PriceAdjustmentResult((j['updated'] as num?)?.toInt() ?? 0);
}

/// Toplu zam hedefi → beklenen güncellenecek kayıt sayısı (yerel önizleme).
int estimatePriceAdjustmentCount({
  required String target,
  required int profileCount,
  required int glassCount,
  required int accessoryCount,
}) {
  return switch (target.toUpperCase()) {
    'PROFILE' => profileCount,
    'GLASS' => glassCount,
    'ACCESSORY' => accessoryCount,
    'ALL' => profileCount + glassCount + accessoryCount,
    _ => 0,
  };
}

String accessoryUnitTr(String unit) => switch (unit.toUpperCase()) {
      'PIECE' => 'Adet',
      'METER' => 'Metre',
      'SET' => 'Takım',
      _ => unit,
    };

String hardwareKindTr(String kind) => switch (kind.toUpperCase()) {
      'TURN' => 'Açılır',
      'TILT' => 'Vasistas',
      'TILT_TURN' => 'Çift açılım',
      'SLIDE' => 'Sürme',
      _ => kind,
    };

String hardwareQtyTypeTr(String qtyType, num qty) {
  final q = qty == qty.roundToDouble() ? '${qty.round()}' : qty.toString();
  return switch (qtyType.toUpperCase()) {
    'PER_SASH' => 'kanat başına $q',
    'PER_PERIMETER_METER' => 'çevre metresi başına $q',
    _ => '$qtyType × $q',
  };
}
