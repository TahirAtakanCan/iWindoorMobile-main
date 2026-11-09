/// Tutarı Türkçe yazıyla (makbuz).
/// Tam sayı: "On beş bin"; kuruşlu: "... Türk Lirası ... kuruş".
String amountToWordsTr(num amount) {
  final negative = amount < 0;
  final v = amount.abs();
  final whole = v.floor();
  final kurus = ((v - whole) * 100).round();

  final liraPart = _intToWords(whole);
  if (kurus <= 0) {
    final s = liraPart.isEmpty ? 'Sıfır' : _cap(liraPart);
    return negative ? 'Eksi $s' : s;
  }
  final kurusPart = _intToWords(kurus);
  final s = '${_cap(liraPart.isEmpty ? 'sıfır' : liraPart)} Türk Lirası $kurusPart kuruş';
  return negative ? 'Eksi $s' : s;
}

String _cap(String s) {
  if (s.isEmpty) return s;
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

String _intToWords(int n) {
  if (n == 0) return 'sıfır';
  if (n < 0) return 'eksi ${_intToWords(-n)}';

  const ones = ['', 'bir', 'iki', 'üç', 'dört', 'beş', 'altı', 'yedi', 'sekiz', 'dokuz'];
  const teens = [
    'on',
    'on bir',
    'on iki',
    'on üç',
    'on dört',
    'on beş',
    'on altı',
    'on yedi',
    'on sekiz',
    'on dokuz',
  ];
  const tens = ['', '', 'yirmi', 'otuz', 'kırk', 'elli', 'altmış', 'yetmiş', 'seksen', 'doksan'];

  String under1000(int x) {
    if (x == 0) return '';
    final parts = <String>[];
    final h = x ~/ 100;
    final r = x % 100;
    if (h > 0) {
      if (h == 1) {
        parts.add('yüz');
      } else {
        parts.add('${ones[h]} yüz');
      }
    }
    if (r > 0) {
      if (r < 10) {
        parts.add(ones[r]);
      } else if (r < 20) {
        parts.add(teens[r - 10]);
      } else {
        final t = r ~/ 10;
        final o = r % 10;
        parts.add(tens[t]);
        if (o > 0) parts.add(ones[o]);
      }
    }
    return parts.join(' ');
  }

  final parts = <String>[];
  var rem = n;

  final milyar = rem ~/ 1000000000;
  rem %= 1000000000;
  if (milyar > 0) {
    parts.add(milyar == 1 ? 'bir milyar' : '${under1000(milyar)} milyar');
  }

  final milyon = rem ~/ 1000000;
  rem %= 1000000;
  if (milyon > 0) {
    parts.add(milyon == 1 ? 'bir milyon' : '${under1000(milyon)} milyon');
  }

  final bin = rem ~/ 1000;
  rem %= 1000;
  if (bin > 0) {
    parts.add(bin == 1 ? 'bin' : '${under1000(bin)} bin');
  }

  if (rem > 0) parts.add(under1000(rem));
  return parts.join(' ');
}
