/// Katalog profil satırı (çekirdek; uygulama snapshot'tan üretir).
class CatalogProfile {
  final int id;
  final int? seriesId;
  final String type;
  final String code;
  final String name;
  final double barLengthMm;
  final bool isDefault;
  final bool isActive;
  final double? minGlass;
  final double? maxGlass;

  const CatalogProfile({
    required this.id,
    required this.type,
    required this.code,
    required this.name,
    required this.barLengthMm,
    this.seriesId,
    this.isDefault = false,
    this.isActive = true,
    this.minGlass,
    this.maxGlass,
  });
}

/// Sunucudaki BomPricer profil seçim mantığının saf Dart karşılığı.
class ProfileResolver {
  final List<CatalogProfile> profiles;
  final Map<String, double> glassThicknessMm;

  const ProfileResolver({
    required this.profiles,
    this.glassThicknessMm = const {},
  });

  /// Rol adı (FRAME, SASH, …) veya ProfileRole.name → profil tipi.
  static String roleToType(String role) {
    final r = role.trim().toUpperCase();
    return switch (r) {
      'FRAME' => 'FRAME',
      'SASH' => 'SASH',
      'MULLION' => 'MULLION',
      'ADAPTER' => 'ADAPTER',
      'DOOR_SASH' => 'DOOR_SASH',
      'THRESHOLD' => 'THRESHOLD',
      'COUPLING' => 'COUPLING',
      'SLIDE_SASH' => 'SASH',
      'BEAD' => 'BEAD',
      _ => r,
    };
  }

  CatalogProfile? resolve({
    required int? seriesId,
    required String role,
    String? glassCode,
  }) {
    final type = roleToType(role);
    if (type == 'BEAD') {
      return _resolveBead(seriesId: seriesId, glassCode: glassCode);
    }
    var hit = _pick(seriesId: seriesId, type: type);
    if (hit == null && type == 'DOOR_SASH') {
      hit = _pick(seriesId: seriesId, type: 'SASH');
    }
    return hit;
  }

  CatalogProfile? _resolveBead({required int? seriesId, String? glassCode}) {
    final thickness = glassCode == null ? null : glassThicknessMm[glassCode];
    final inSeries = _inSeries(seriesId).where((p) => _typeEq(p.type, 'BEAD')).toList();
    if (thickness != null) {
      final matching = inSeries.where((p) => _inGlassRange(p, thickness)).toList();
      final fromMatch = _select(matching);
      if (fromMatch != null) return fromMatch;
    }
    return _select(inSeries);
  }

  CatalogProfile? _pick({required int? seriesId, required String type}) {
    final list = _inSeries(seriesId).where((p) => _typeEq(p.type, type)).toList();
    return _select(list);
  }

  /// Önce aktifler (isDefault tercih), yoksa pasiflerden aynı kural.
  CatalogProfile? _select(List<CatalogProfile> list) {
    if (list.isEmpty) return null;
    final active = list.where((p) => p.isActive).toList();
    final pool = active.isNotEmpty ? active : list;
    for (final p in pool) {
      if (p.isDefault) return p;
    }
    return pool.first;
  }

  Iterable<CatalogProfile> _inSeries(int? seriesId) {
    if (seriesId == null) return profiles;
    final exact = profiles.where((p) => p.seriesId == seriesId);
    if (exact.isNotEmpty) return exact;
    // Seriye özel yoksa genel (seriesId null) profiller.
    return profiles.where((p) => p.seriesId == null || p.seriesId == seriesId);
  }

  static bool _typeEq(String a, String b) => a.trim().toUpperCase() == b.trim().toUpperCase();

  static bool _inGlassRange(CatalogProfile p, double thickness) {
    final min = p.minGlass;
    final max = p.maxGlass;
    if (min != null && thickness < min) return false;
    if (max != null && thickness > max) return false;
    return true;
  }
}
