// Keşif ölçü yardımcıları.

/// cm → mm (zaten mm ise aynen).
double toMm(num value, {required bool isCm}) => isCm ? value * 10 : value.toDouble();

/// Boşluk ölçüsünden önerilen pencere ölçüsü: her kenardan gapMm düş.
(double width, double height) suggestedWindowSize(num openingW, num openingH, num gapMm) {
  final g = gapMm.toDouble();
  return (
    (openingW.toDouble() - 2 * g).clamp(0, double.infinity),
    (openingH.toDouble() - 2 * g).clamp(0, double.infinity),
  );
}

enum SurveyProductType { window, door, balcony, sliding, other }

SurveyProductType surveyProductFromApi(Object? v) {
  final s = '${v ?? ''}'.trim().toUpperCase();
  return switch (s) {
    'DOOR' || 'KAPI' => SurveyProductType.door,
    'BALCONY' || 'BALKON' || 'BALCONY_DOOR' => SurveyProductType.balcony,
    'SLIDING' || 'SLIDE' || 'SURME' || 'SÜRME' => SurveyProductType.sliding,
    'OTHER' || 'DIGER' || 'DİĞER' => SurveyProductType.other,
    _ => SurveyProductType.window,
  };
}

String surveyProductApi(SurveyProductType t) => switch (t) {
      SurveyProductType.window => 'WINDOW',
      SurveyProductType.door => 'DOOR',
      SurveyProductType.balcony => 'BALCONY',
      SurveyProductType.sliding => 'SLIDING',
      SurveyProductType.other => 'OTHER',
    };

String surveyProductTr(SurveyProductType t) => switch (t) {
      SurveyProductType.window => 'Pencere',
      SurveyProductType.door => 'Kapı',
      SurveyProductType.balcony => 'Balkon kapısı',
      SurveyProductType.sliding => 'Sürme',
      SurveyProductType.other => 'Diğer',
    };

/// Varsayılan yerleşik şablon adı (toplu çevir için).
String defaultTemplateNameFor(SurveyProductType type, double suggestedWidthMm) {
  switch (type) {
    case SurveyProductType.window:
      return suggestedWidthMm > 1000 ? 'Çift kanat (orta kayıtsız)' : 'Tek kanat açılır-vasistas';
    case SurveyProductType.door:
      return 'Servis kapısı';
    case SurveyProductType.balcony:
      return 'Balkon kapısı (eşikli)';
    case SurveyProductType.sliding:
      return 'Sürme iki kanat';
    case SurveyProductType.other:
      return 'Sabit cam';
  }
}

/// Şablon seçici sekme indeksi: 0 pencere, 1 kapı, 2 birleşik, 3 sürme, 4 şekilli, 5 firma.
int templateTabForProduct(SurveyProductType t) => switch (t) {
      SurveyProductType.window || SurveyProductType.other => 0,
      SurveyProductType.door || SurveyProductType.balcony => 1,
      SurveyProductType.sliding => 3,
    };
