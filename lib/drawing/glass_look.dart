import 'package:flutter/material.dart';

/// Profil (PVC/ALU) rengi.
class ProfileColor {
  final String code, label;
  final Color fill, stroke, hardware;
  const ProfileColor(this.code, this.label, this.fill, this.stroke, this.hardware);

  static const white = ProfileColor('white', 'Beyaz', Color(0xFFF7F8F8), Color(0xFF6D757B), Color(0xFFD9DDE0));
  static const anthracite = ProfileColor('anthracite', 'Antrasit', Color(0xFF454C52), Color(0xFF1C2125), Color(0xFF9AA2A8));
  static const oak = ProfileColor('oak', 'Altın meşe', Color(0xFFB9853F), Color(0xFF5A3A1C), Color(0xFFC9A24A));

  static const all = [white, anthracite, oak];

  static ProfileColor of(String code) => all.firstWhere((c) => c.code == code, orElse: () => white);
}

/// Cam görünümü. Katalogdaki Glass.visualStyle değerinden seçilir.
class GlassLook {
  final List<Color> gradient;
  final double reflection; // parlama şeritlerinin opaklığı (0 = yok)
  final bool frosted, patterned, laminated, panel;

  const GlassLook(this.gradient,
      {this.reflection = .38, this.frosted = false, this.patterned = false, this.laminated = false, this.panel = false});

  static const clear = GlassLook([Color(0xFFE3F3FC), Color(0xFFB6DEF5), Color(0xFF8EC7EA)]);
  static const lowe = GlassLook([Color(0xFFE2F5EF), Color(0xFFB5E1D6), Color(0xFF8CCBBD)]);
  static const smoke = GlassLook([Color(0xFFB9C3C9), Color(0xFF8D9AA2), Color(0xFF6C7A83)]);
  static const bronze = GlassLook([Color(0xFFE2C9A4), Color(0xFFBF9A6C), Color(0xFF9C774B)]);
  static const mirror = GlassLook([Color(0xFFF4F7F9), Color(0xFFB8C3CB), Color(0xFF8F9CA6)], reflection: .55);
  static const frost = GlassLook([Color(0xFFEEF5F9), Color(0xFFD5E3EB)], reflection: 0, frosted: true);
  static const pattern = GlassLook([Color(0xFFE6F3FA), Color(0xFFC3DFEE)], reflection: 0, patterned: true);
  static const lam = GlassLook([Color(0xFFE3F3FC), Color(0xFFB2DBF3), Color(0xFF86C0E6)], laminated: true);
  static const panelLook = GlassLook([Color(0xFFF1F2F3), Color(0xFFD9DCDE)], reflection: 0, panel: true);

  static const styles = <String, String>{
    'clear': 'Şeffaf',
    'lowe': 'Low-E',
    'smoke': 'Füme',
    'bronze': 'Bronz',
    'mirror': 'Reflekte',
    'frost': 'Buzlu',
    'pattern': 'Desenli',
    'lam': 'Lamine',
    'panel': 'Panel',
  };

  static GlassLook forStyle(String? style) => switch (style) {
        'lowe' => lowe,
        'smoke' => smoke,
        'bronze' => bronze,
        'mirror' => mirror,
        'frost' => frost,
        'pattern' => pattern,
        'lam' => lam,
        'panel' => panelLook,
        _ => clear,
      };

  /// Listelerde küçük renk örneği.
  Widget swatch({double size = 22}) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
          border: Border.all(color: const Color(0xFF5F8AA6), width: .8),
          borderRadius: BorderRadius.circular(3),
        ),
      );
}
