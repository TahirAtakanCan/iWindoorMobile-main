import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/utils/survey_helpers.dart';

void main() {
  test('cm→mm', () {
    expect(toMm(140, isCm: true), 1400);
    expect(toMm(1400, isCm: false), 1400);
  });

  test('önerilen ölçü (1420, gap 10 → 1400)', () {
    final s = suggestedWindowSize(1420, 1420, 10);
    expect(s.$1, 1400);
    expect(s.$2, 1400);
  });

  test('varsayılan şablon eşlemesi', () {
    expect(defaultTemplateNameFor(SurveyProductType.window, 1400), 'Çift kanat (orta kayıtsız)');
    expect(defaultTemplateNameFor(SurveyProductType.window, 700), 'Tek kanat çift açılım');
    expect(defaultTemplateNameFor(SurveyProductType.door, 900), 'Servis kapısı');
    expect(defaultTemplateNameFor(SurveyProductType.balcony, 900), 'Balkon kapısı (eşikli)');
    expect(defaultTemplateNameFor(SurveyProductType.sliding, 2000), 'Sürme iki kanat');
    expect(defaultTemplateNameFor(SurveyProductType.other, 1000), 'Sabit cam');
  });
}
