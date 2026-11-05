import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/services/pdf_service.dart';

void main() {
  test('formatQty Türkçe ondalık kullanır', () {
    expect(formatQty(18.024), '18,02');
    expect(formatQty(1), '1,00');
  });

  test('bomGroupTr grup adlarını Türkçeleştirir', () {
    expect(bomGroupTr('PROFILE'), 'Profil');
    expect(bomGroupTr('BEAD'), 'Çıta');
    expect(bomGroupTr('DUPLEX'), 'Dubleks');
    expect(bomGroupTr('GLASS'), 'Cam');
    expect(bomGroupTr('PANEL'), 'Panel');
    expect(bomGroupTr('HARDWARE'), 'Donanım');
    expect(bomGroupTr('ACCESSORY'), 'Aksesuar');
  });

  test('formatUnit m2 → m²', () {
    expect(formatUnit('m2'), 'm²');
    expect(formatUnit('m'), 'm');
  });
}
