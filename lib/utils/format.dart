// Ortak Türkçe biçimlendirme (ekran + PDF aynı kaynak).

String _trNumber(num v, int fractionDigits) {
  final s = v.toStringAsFixed(fractionDigits);
  final parts = s.split('.');
  final intPart = parts[0];
  final frac = parts.length > 1 ? parts[1] : '';
  final buf = StringBuffer();
  for (var i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
    buf.write(intPart[i]);
  }
  if (fractionDigits <= 0) return buf.toString();
  return '${buf.toString()},$frac';
}

/// Para: 50.903,63 TL
String formatMoney(num v) => '${_trNumber(v, 2)} TL';

/// Miktar: formatQty(116.48, 'm') → "116,48 m"; birimsiz: "18,02"
String formatQty(num v, [String? unit]) {
  final n = v.toStringAsFixed(2).replaceAll('.', ',');
  if (unit == null || unit.trim().isEmpty) return n;
  return '$n ${formatUnit(unit)}';
}

String formatUnit(String unit) {
  final u = unit.trim().toLowerCase();
  if (u == 'm2' || u == 'm²') return 'm²';
  if (u == 'm') return 'm';
  if (u == 'adet' || u == 'piece' || u == 'pcs') return 'adet';
  return unit;
}

String bomGroupTr(String group) => switch (group.trim().toUpperCase()) {
      'PROFILE' => 'Profil',
      'BEAD' => 'Çıta',
      'DUPLEX' => 'Dubleks',
      'GLASS' => 'Cam',
      'PANEL' => 'Panel',
      'HARDWARE' => 'Donanım',
      'ACCESSORY' => 'Aksesuar',
      'COLOR' => 'Renk farkı',
      'SCREEN' => 'Sineklik',
      _ => group,
    };

/// Görevdeki ad: groupTr ≡ bomGroupTr
String groupTr(String group) => bomGroupTr(group);

String hardwareKindTr(String? kind) => switch ((kind ?? '').toUpperCase()) {
      'TURN' => 'Açılır',
      'TILT' => 'Vasistas',
      'TILT_TURN' => 'Çift açılım',
      'SLIDE' => 'Sürme',
      'LIFT_SLIDE' => 'Kaldır-sür',
      'SLIDE_FIXED' => 'Sürme sabit',
      'PASSIVE' => 'Pasif kanat',
      'DOOR' => 'Kapı',
      'DOOR_PASSIVE' => 'Pasif kapı kanadı',
      _ => kind ?? '—',
    };

String screenKindBomTr(String? kind) => switch ((kind ?? '').toUpperCase()) {
      'PLISE' => 'Pileli',
      'HINGED' => 'Menteşeli',
      'SLIDING' => 'Sürme',
      _ => kind ?? '—',
    };

String profileRoleTr(String? role) => switch ((role ?? '').toUpperCase()) {
      'FRAME' => 'Kasa',
      'THRESHOLD' => 'Eşik',
      'SASH' => 'Kanat',
      'DOOR_SASH' => 'Kapı kanadı',
      'SLIDE_SASH' => 'Sürme kanat',
      'MULLION' => 'Orta kayıt',
      'COUPLING' => 'Birleştirme profili',
      'ADAPTER' => 'Adaptör',
      _ => role ?? 'Profil',
    };

/// dd.MM.yyyy
String formatDate(DateTime? d) {
  if (d == null) return '—';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

/// dd.MM.yyyy HH:mm
String formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final hh = d.hour.toString().padLeft(2, '0');
  final mi = d.minute.toString().padLeft(2, '0');
  return '${formatDate(d)} $hh:$mi';
}
