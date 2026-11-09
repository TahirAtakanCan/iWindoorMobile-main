import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Roboto PDF yazı tipleri: önce asset, olmazsa Google Fonts; önbellekli.
class PdfFonts {
  PdfFonts._();

  static pw.Font? _regular;
  static pw.Font? _bold;

  static Future<pw.Font> regular() async {
    _regular ??= await _load('assets/fonts/Roboto-Regular.ttf', () => PdfGoogleFonts.robotoRegular());
    return _regular!;
  }

  static Future<pw.Font> bold() async {
    _bold ??= await _load('assets/fonts/Roboto-Bold.ttf', () => PdfGoogleFonts.robotoBold());
    return _bold!;
  }

  static Future<(pw.Font, pw.Font)> load() async {
    final r = await regular();
    final b = await bold();
    return (r, b);
  }

  /// Testlerde önbelleği sıfırlamak için.
  static void resetCache() {
    _regular = null;
    _bold = null;
  }

  static Future<pw.Font> _load(String asset, Future<pw.Font> Function() fallback) async {
    try {
      final data = await rootBundle.load(asset);
      return pw.Font.ttf(data);
    } catch (_) {
      return fallback();
    }
  }
}
