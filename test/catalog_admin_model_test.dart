import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/catalog.dart';

void main() {
  test('Accessory fromJson/toJson', () {
    final a = Accessory.fromJson({
      'id': 3,
      'code': 'KOL-STD',
      'name': 'Pencere kolu',
      'unit': 'PIECE',
      'price': 250.5,
      'currency': 'TRY',
      'isActive': true,
    });
    expect(a.code, 'KOL-STD');
    expect(a.unit, 'PIECE');
    expect(a.price, 250.5);
    expect(a.isActive, isTrue);
    expect(a.toJson()['code'], 'KOL-STD');
    expect(a.toJson()['isActive'], isTrue);
  });

  test('HardwareRule fromJson/toJson', () {
    final r = HardwareRule.fromJson({
      'id': 9,
      'kind': 'TILT_TURN',
      'seriesId': null,
      'accessoryCode': 'CIFT-ACILIM-SET',
      'accessoryName': 'Çift açılım takımı',
      'qtyType': 'PER_SASH',
      'qty': 1,
    });
    expect(r.kind, 'TILT_TURN');
    expect(r.qtyType, 'PER_SASH');
    expect(r.qty, 1);
    expect(r.toJson()['accessoryCode'], 'CIFT-ACILIM-SET');
    expect(hardwareQtyTypeTr(r.qtyType, r.qty), 'kanat başına 1');
    expect(hardwareKindTr('SLIDE'), 'Sürme');
  });

  test('ProfileInfo active alanı (backend ProfileDto)', () {
    final p = ProfileInfo.fromJson({
      'id': 1,
      'code': 'KASA',
      'name': 'Kasa',
      'type': 'FRAME',
      'pricePerMeter': 120,
      'barLengthMm': 6500,
      'isDefault': true,
      'active': false,
    });
    expect(p.isActive, isFalse);
    expect(p.barLengthMm, 6500);
    expect(p.isDefault, isTrue);
  });

  test('GlassInfo isActive ve CatalogSnapshot accessories', () {
    final snap = CatalogSnapshot.fromJson({
      'series': [],
      'profiles': [],
      'glasses': [
        {'id': 1, 'code': '4+16+4', 'name': 'Şeffaf', 'visualStyle': 'clear', 'pricePerSquareMeter': 400, 'isActive': false},
      ],
      'accessories': [
        {'id': 2, 'code': 'CONTA', 'name': 'Conta', 'unit': 'METER', 'price': 12, 'isActive': true},
      ],
    });
    expect(snap.glasses.single.isActive, isFalse);
    expect(snap.accessories.single.code, 'CONTA');
  });

  test('estimatePriceAdjustmentCount hedefleri', () {
    expect(estimatePriceAdjustmentCount(target: 'PROFILE', profileCount: 5, glassCount: 3, accessoryCount: 2), 5);
    expect(estimatePriceAdjustmentCount(target: 'GLASS', profileCount: 5, glassCount: 3, accessoryCount: 2), 3);
    expect(estimatePriceAdjustmentCount(target: 'ACCESSORY', profileCount: 5, glassCount: 3, accessoryCount: 2), 2);
    expect(estimatePriceAdjustmentCount(target: 'ALL', profileCount: 5, glassCount: 3, accessoryCount: 2), 10);
  });
}
