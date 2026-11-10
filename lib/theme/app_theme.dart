import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Pervaz marka kimliği: petrol mavisi (PVC kasa / gölge), kehribar (açılım üçgeni / kol),
/// buz mavisi (cam). Renkler logodaki tonlardan alınmıştır.
class Brand {
  Brand._();

  static const String appName = 'Pervaz';
  static const String tagline = 'Pencere · Kapı · Teklif';

  static const Color petrol = Color(0xFF0F4C5C);
  static const Color petrolDark = Color(0xFF0A3540);
  static const Color petrolLight = Color(0xFF17677A);
  static const Color amber = Color(0xFFF2A33A);
  static const Color amberDark = Color(0xFFC77D16);
  static const Color glass = Color(0xFF8FD3D6);
  static const Color glassLight = Color(0xFFD4F1F1);
  static const Color background = Color(0xFFF4F7F7);
  static const Color ink = Color(0xFF14272D);

  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [petrolLight, petrolDark],
  );

  static const String markAsset = 'assets/branding/pervaz_mark.png';
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.petrol,
      brightness: Brightness.light,
      primary: Brand.petrol,
      onPrimary: Colors.white,
      secondary: Brand.amber,
      onSecondary: Brand.ink,
      tertiary: Brand.petrolLight,
    );
    final radius = BorderRadius.circular(12);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: Brand.background,
      // Masaüstünde fare ile daha sık yerleşim
      visualDensity: AppConfig.isDesktop ? VisualDensity.compact : VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Brand.petrolDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(color: Brand.petrolDark, fontSize: 20, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Brand.petrol,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius)),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: radius)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Brand.amber,
        foregroundColor: Brand.ink,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: radius),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: const BorderSide(color: Brand.petrol, width: 2),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: Brand.petrol),
      tabBarTheme: const TabBarThemeData(
        labelColor: Brand.petrol,
        indicatorColor: Brand.amber,
      ),
    );
  }
}
