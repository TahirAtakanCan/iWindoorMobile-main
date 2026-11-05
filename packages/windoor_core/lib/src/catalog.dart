// Seri (profil sistemi) geometri parametreleri. Hepsi mm.
// Bunlar backend'deki profiles/series tablolarından gelir; çizim ve kesim bunlara bağlıdır.

class SeriesGeometry {
  final String id;
  final double frameFace; // kasa görünen genişliği
  final double sashFace; // kanat görünen genişliği
  final double mullionFace; // orta kayıt görünen genişliği
  final double beadFace; // cam çıtası görünen genişliği
  final double sashLap; // kanadın kasa/kayıt üstüne bindirmesi
  final double glassRebateFrame; // cam, kasa iç yüzünden içeri ne kadar girer
  final double glassRebateSash;
  final double glassRebateMullion;
  final double weldAllowance; // PVC kaynak payı (uç başına). Alüminyumda 0.
  final double mullionEndAllowance; // kayıt uç payı (uç başına)
  final double slideInterlock; // sürme kanat bindirmesi
  final double duplexWidth; // dubleks çıta genişliği
  final double minSashWidth;
  final double minSashHeight;
  final double maxSashWidth;
  final double maxSashHeight;
  final double maxSlideSashWidth;
  final double maxFixedGlassArea; // m²

  const SeriesGeometry({
    required this.id,
    this.frameFace = 62,
    this.sashFace = 78,
    this.mullionFace = 80,
    this.beadFace = 20,
    this.sashLap = 8,
    this.glassRebateFrame = 14,
    this.glassRebateSash = 14,
    this.glassRebateMullion = 14,
    this.weldAllowance = 3,
    this.mullionEndAllowance = 3,
    this.slideInterlock = 40,
    this.duplexWidth = 18,
    this.minSashWidth = 350,
    this.minSashHeight = 350,
    this.maxSashWidth = 1400,
    this.maxSashHeight = 2400,
    this.maxSlideSashWidth = 2000,
    this.maxFixedGlassArea = 6.0,
  });

  double rebateFor(EdgeKind e) => switch (e) {
        EdgeKind.frame => glassRebateFrame,
        EdgeKind.sash => glassRebateSash,
        EdgeKind.mullion => glassRebateMullion,
      };

  factory SeriesGeometry.fromJson(Map<String, dynamic> j) {
    double d(String k, double def) => (j[k] as num?)?.toDouble() ?? def;
    return SeriesGeometry(
      id: j['id'].toString(),
      frameFace: d('frameFace', 62),
      sashFace: d('sashFace', 78),
      mullionFace: d('mullionFace', 80),
      beadFace: d('beadFace', 20),
      sashLap: d('sashLap', 8),
      glassRebateFrame: d('glassRebateFrame', 14),
      glassRebateSash: d('glassRebateSash', 14),
      glassRebateMullion: d('glassRebateMullion', 14),
      weldAllowance: d('weldAllowance', 3),
      mullionEndAllowance: d('mullionEndAllowance', 3),
      slideInterlock: d('slideInterlock', 40),
      duplexWidth: d('duplexWidth', 18),
      minSashWidth: d('minSashWidth', 350),
      minSashHeight: d('minSashHeight', 350),
      maxSashWidth: d('maxSashWidth', 1400),
      maxSashHeight: d('maxSashHeight', 2400),
      maxSlideSashWidth: d('maxSlideSashWidth', 2000),
      maxFixedGlassArea: d('maxFixedGlassArea', 6.0),
    );
  }
}

/// Bir cam alanının kenarını hangi profil tutuyor? Cam payı buna göre değişir.
enum EdgeKind { frame, sash, mullion }
