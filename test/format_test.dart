import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/utils/format.dart';

void main() {
  test('formatMoney Türkçe binlik ve TL', () {
    expect(formatMoney(50903.63), '50.903,63 TL');
    expect(formatMoney(1000), '1.000,00 TL');
    expect(formatMoney(0), '0,00 TL');
  });

  test('formatQty Türkçe ondalık ve birim', () {
    expect(formatQty(116.48, 'm'), '116,48 m');
    expect(formatQty(18.024), '18,02');
    expect(formatQty(1), '1,00');
    expect(formatQty(2.5, 'm2'), '2,50 m²');
  });

  test('groupTr / bomGroupTr grup adlarını Türkçeleştirir', () {
    expect(groupTr('PROFILE'), 'Profil');
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

  test('formatLastUpdateShort bugün / dün / yok', () {
    final now = DateTime(2026, 11, 11, 15, 0);
    expect(formatLastUpdateShort(null, now: now), 'henüz indirilmedi');
    expect(formatLastUpdateShort(DateTime(2026, 11, 11, 14, 32), now: now), '14:32');
    expect(formatLastUpdateShort(DateTime(2026, 11, 10, 18, 5), now: now), 'dün 18:05');
  });
}
