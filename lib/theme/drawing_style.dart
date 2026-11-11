import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/glass_look.dart';

/// Marka çizim paleti (docs/branding/cizim_referans).
class DrawingStyle {
  DrawingStyle._();

  static const contour = Color(0xFF9FB1B5);
  static const amber = Color(0xFFF2A33A);
  static const glassStart = Color(0xFFD4F1F1);
  static const glassEnd = Color(0xFF7FC6CB);
  static const glassFlatPdf = Color(0xFFA9DDE0);
  static const glassStroke = Color(0xFF2F5D66);
  static const panelFill = Color(0xFFF1F4F4);
  static const panelLine = Color(0xFFC9D3D5);
  static const dim = Color(0xFF5E7A80);
  static const handleBase = Color(0xFF9FB1B5);
  static const lockDot = Color(0xFF6F7D81);
  static const screenGrid = Color(0xFF5E7A80);
  static const shutterBox = Color(0xFF8C9A9E);
  static const shutterLine = Color(0xFFB7C2C5);
  static const shutterRail = Color(0xFFA9B5B8);
  static const sill = Color(0xFFD9E1E3);
  static const threshold = Color(0xFFB8C4C7);
  static const slideLabel = Color(0xFF2F5D66);

  static const whiteBevel = [Color(0xFFFFFFFF), Color(0xFFE3ECEE), Color(0xFFC9D7DA), Color(0xFFEEF4F5)];
  static const anthraciteBevel = [Color(0xFF5A6166), Color(0xFF464C51), Color(0xFF383D41), Color(0xFF50565B)];
  static const oakBevel = [Color(0xFFC88A4A), Color(0xFFAE723A), Color(0xFF94602F), Color(0xFFBC7F42)];
  static const walnutBevel = [Color(0xFF7A4E31), Color(0xFF663F27), Color(0xFF55341F), Color(0xFF70472C)];
  static const creamBevel = [Color(0xFFFBF6E9), Color(0xFFEFE6D0), Color(0xFFDFD3B6), Color(0xFFF5EEDB)];

  static const _codeBevel = <String, List<Color>>{
    'white': whiteBevel,
    'beyaz': whiteBevel,
    'anthracite': anthraciteBevel,
    'antrasit': anthraciteBevel,
    'oak': oakBevel,
    'goldoak': oakBevel,
    'altinmese': oakBevel,
    'walnut': walnutBevel,
    'ceviz': walnutBevel,
    'cream': creamBevel,
    'krem': creamBevel,
  };

  /// 4 bevel tonu: [üst, sağ, alt, sol].
  static List<Color> bevelFrom(Color base) => [
        Color.lerp(base, Colors.white, 0.32)!,
        Color.lerp(base, Colors.white, 0.12)!,
        Color.lerp(base, Colors.black, 0.16)!,
        Color.lerp(base, Colors.white, 0.20)!,
      ];

  static List<Color> bevelForProfile(ProfileColor c) {
    final key = c.code.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final e in _codeBevel.entries) {
      if (key == e.key || key.contains(e.key)) return e.value;
    }
    final label = c.label.toLowerCase();
    for (final e in _codeBevel.entries) {
      if (label.contains(e.key)) return e.value;
    }
    if (_nearHex(c.fill, whiteBevel[0])) return whiteBevel;
    if (_nearHex(c.fill, anthraciteBevel[0])) return anthraciteBevel;
    if (_nearHex(c.fill, oakBevel[0])) return oakBevel;
    if (_nearHex(c.fill, walnutBevel[0])) return walnutBevel;
    if (_nearHex(c.fill, creamBevel[0])) return creamBevel;
    return bevelFrom(c.fill);
  }

  static bool _nearHex(Color a, Color b) {
    final dr = (a.r * 255 - b.r * 255).abs();
    final dg = (a.g * 255 - b.g * 255).abs();
    final db = (a.b * 255 - b.b * 255).abs();
    return dr + dg + db < 48;
  }

  static Color bevelTone(ProfileColor c, ProfileSide side, {bool bead = false}) {
    final tones = bevelForProfile(c);
    final i = switch (side) {
      ProfileSide.top => 0,
      ProfileSide.right => 1,
      ProfileSide.bottom => 2,
      ProfileSide.left => 3,
    };
    final tone = tones[i];
    if (!bead) return tone;
    return Color.lerp(tone, Colors.black, 0.10)!;
  }
}
