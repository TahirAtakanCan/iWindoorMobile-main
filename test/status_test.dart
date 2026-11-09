import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/utils/status.dart';

void main() {
  test('tüm durumların Türkçe adı ve rengi', () {
    expect(ProjectStatus.quote.labelTr, 'Teklif');
    expect(ProjectStatus.approved.labelTr, 'Onaylandı');
    expect(ProjectStatus.production.labelTr, 'Üretimde');
    expect(ProjectStatus.installation.labelTr, 'Montajda');
    expect(ProjectStatus.delivered.labelTr, 'Teslim edildi');
    expect(ProjectStatus.cancelled.labelTr, 'İptal');

    expect(ProjectStatus.quote.color, Colors.grey);
    expect(ProjectStatus.approved.color, Colors.blue);
    expect(ProjectStatus.production.color, Colors.orange);
    expect(ProjectStatus.installation.color, Colors.purple);
    expect(ProjectStatus.delivered.color, Colors.green);
    expect(ProjectStatus.cancelled.color, Colors.red);
  });

  test('izinli sonraki adım haritası', () {
    expect(statusForwardMap[ProjectStatus.quote], ProjectStatus.approved);
    expect(statusForwardMap[ProjectStatus.approved], ProjectStatus.production);
    expect(statusForwardMap[ProjectStatus.production], ProjectStatus.installation);
    expect(statusForwardMap[ProjectStatus.installation], ProjectStatus.delivered);
    expect(statusForwardMap[ProjectStatus.delivered], isNull);
    expect(statusForwardMap[ProjectStatus.cancelled], isNull);

    expect(ProjectStatus.quote.nextForwardActionLabel, 'Onayla');
    expect(ProjectStatus.approved.nextForwardActionLabel, 'Üretime al');
    expect(ProjectStatus.production.nextForwardActionLabel, 'Montaja çıkar');
    expect(ProjectStatus.installation.nextForwardActionLabel, 'Teslim et');
  });

  test('fromApi / apiValue', () {
    expect(ProjectStatus.fromApi('QUOTE'), ProjectStatus.quote);
    expect(ProjectStatus.fromApi('INSTALL'), ProjectStatus.installation);
    expect(ProjectStatus.production.apiValue, 'PRODUCTION');
  });
}
