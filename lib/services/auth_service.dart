import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

class AuthResult {
  final bool ok;
  final String? message;

  const AuthResult({required this.ok, this.message});
}

class AuthService {
  String get _baseUrl => '${AppConfig.apiUrl}/auth';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    contentType: Headers.jsonContentType,
  ));

  Future<AuthResult> login(String email, String password) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      debugPrint('İstek gönderiliyor: $_baseUrl/authenticate');

      final response = await _dio.post('$_baseUrl/authenticate', data: {
        'email': normalizedEmail,
        'password': password,
      });

      debugPrint('Sunucu Cevabı: ${response.statusCode}');

      if (response.statusCode == 200) {
        final saved = await _persistAuth(response.data);
        if (saved) return const AuthResult(ok: true);
      }
      return const AuthResult(ok: false, message: 'İşlem başarısız.');
    } on DioException catch (e) {
      debugPrint('Dio Hatası: ${e.message}');
      if (e.response != null) {
        debugPrint('Hata Verisi: ${e.response?.data}');
        debugPrint('Hata Kodu: ${e.response?.statusCode}');
      }
      return AuthResult(ok: false, message: _messageFromDio(e));
    } catch (e) {
      debugPrint('Genel Hata: $e');
      return AuthResult(ok: false, message: 'İşlem başarısız: $e');
    }
  }

  Future<AuthResult> register(
    String fullName,
    String email,
    String password, {
    String? companyName,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final data = <String, dynamic>{
        'fullName': fullName.trim(),
        'email': normalizedEmail,
        'password': password,
      };
      final company = companyName?.trim();
      if (company != null && company.isNotEmpty) {
        data['companyName'] = company;
      }

      final response = await _dio.post('$_baseUrl/register', data: data);

      if (response.statusCode == 200) {
        final saved = await _persistAuth(response.data);
        if (saved) return const AuthResult(ok: true);
      }
      return const AuthResult(ok: false, message: 'İşlem başarısız.');
    } on DioException catch (e) {
      debugPrint('Kayıt Hatası: ${e.message}');
      if (e.response != null) {
        debugPrint('Hata Verisi: ${e.response?.data}');
      }
      return AuthResult(ok: false, message: _messageFromDio(e));
    } catch (e) {
      debugPrint('Kayıt Hatası: $e');
      return AuthResult(ok: false, message: 'İşlem başarısız: $e');
    }
  }

  Future<bool> _persistAuth(dynamic data) async {
    if (data is! Map) return false;
    final token = data['token'];
    final role = data['role'];
    final fullName = data['fullName'];
    final email = data['email'];
    if (token == null) return false;
    await _saveToken(token.toString());
    if (role != null) await _saveRole(role.toString());
    if (fullName != null) await _saveUserInfo(fullName.toString(), email?.toString() ?? '');
    return true;
  }

  String _messageFromDio(DioException e) {
    final response = e.response;
    if (response == null) {
      return 'Sunucuya ulaşılamadı. Giriş ekranındaki ağ simgesinden sunucu adresini kontrol edin.';
    }

    final data = response.data;
    final code = data is Map ? data['code']?.toString() : null;
    final detail = data is Map ? data['detail']?.toString() : null;
    final status = response.statusCode;

    if (code == 'EMAIL_TAKEN') {
      return 'Bu e-posta ile kayıtlı bir hesap var.';
    }
    if (code == 'VALIDATION_FAILED') {
      final errors = data is Map ? data['errors'] : null;
      if (errors is List && errors.isNotEmpty) {
        final lines = <String>[];
        for (final item in errors) {
          if (item is Map && item['message'] != null) {
            lines.add(item['message'].toString());
          }
        }
        if (lines.isNotEmpty) return lines.join('\n');
      }
      if (detail != null && detail.isNotEmpty) return detail;
    }
    if (status == 401 || code == 'BAD_CREDENTIALS') {
      return 'E-posta veya şifre hatalı.';
    }
    if (detail != null && detail.isNotEmpty) return detail;
    return 'İşlem başarısız (HTTP ${status ?? '?'}).';
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<void> _saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<void> _saveUserInfo(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
  }

  Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? 'Kullanıcı',
      'email': prefs.getString('user_email') ?? '',
    };
  }
}
