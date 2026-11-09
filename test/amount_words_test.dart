import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/utils/amount_words.dart';

void main() {
  test('tutarı yazıyla', () {
    expect(amountToWordsTr(15000), 'On beş bin');
    expect(amountToWordsTr(29501.93), 'Yirmi dokuz bin beş yüz bir Türk Lirası doksan üç kuruş');
  });
}
