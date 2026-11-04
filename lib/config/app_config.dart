import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucu adresi. Sırayla: kullanıcının kaydettiği adres > --dart-define=API_BASE_URL > platform varsayılanı.
/// Masaüstünde backend genelde aynı bilgisayarda çalışır (localhost); telefonda bilgisayarın yerel IP'si gerekir.
class AppConfig {
  AppConfig._();

  static const _prefKey = 'server_url';
  static const _fromDefine = String.fromEnvironment('API_BASE_URL');

  static String _baseUrl = defaultUrl;

  static String get defaultUrl {
    if (_fromDefine.isNotEmpty) return _fromDefine;
    if (kIsWeb) return 'http://localhost:8080';
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return 'http://localhost:8080';
      default:
        return 'http://192.168.0.37:8080';
    }
  }

  /// Örn: http://192.168.0.37:8080
  static String get baseUrl => _baseUrl;

  /// Örn: http://192.168.0.37:8080/api/v1
  static String get apiUrl => '$_baseUrl/api/v1';

  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _baseUrl = _normalize(prefs.getString(_prefKey) ?? defaultUrl);
  }

  static Future<void> setBaseUrl(String url) async {
    _baseUrl = _normalize(url);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, _baseUrl);
  }

  static String _normalize(String url) {
    var u = url.trim();
    if (u.isEmpty) return defaultUrl;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    if (u.endsWith('/api/v1')) u = u.substring(0, u.length - '/api/v1'.length);
    return u;
  }
}
