import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  // Emülatör için: 'http://10.0.2.2:8080/api/v1/auth'
  // Gerçek Cihaz için: Bilgisayarının IP adresi (Örn: 'http://192.168.1.35:8080/api/v1/auth')
  final String _baseUrl = 'http://192.168.0.37:8080/api/v1/auth';
  // Dio ayarlarını güncelle
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10), // Bağlanmak için 10 sn bekle
    receiveTimeout: const Duration(seconds: 10), // Cevap için 10 sn bekle
    contentType: Headers.jsonContentType,
  ));

  // Giriş Yap
  Future<bool> login(String email, String password) async {
    try {
      print("İstek gönderiliyor: $_baseUrl/authenticate"); // Log ekle
      
      final response = await _dio.post('$_baseUrl/authenticate', data: {
        'email': email,
        'password': password,
      });

      print("Sunucu Cevabı: ${response.statusCode}"); // Log ekle

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final role = response.data['role'];
        final fullName = response.data['fullName']; // <-- AL
        final email = response.data['email'];       // <-- AL

        if (token != null) {
          await _saveToken(token);
          if (role != null) await _saveRole(role);
          // İsim ve emaili kaydet
          if (fullName != null) await _saveUserInfo(fullName, email ?? ""); 
          return true;
        }
      }
      return false;
    } on DioException catch (e) {
      // Hatayı detaylı gör
      print('Dio Hatası: ${e.message}');
      if (e.response != null) {
        print('Hata Verisi: ${e.response?.data}');
        print('Hata Kodu: ${e.response?.statusCode}');
      }
      return false;
    } catch (e) {
      print('Genel Hata: $e');
      return false;
    }
  }

  // Kayıt Ol (Register) - Şimdilik basit hali
  Future<bool> register(String fullName, String email, String password) async {
    try {
      final response = await _dio.post('$_baseUrl/register', data: {
        'fullName': fullName,
        'email': email,
        'password': password,
      });

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final role = response.data['role'];
        final fullName = response.data['fullName']; // <-- AL
        final email = response.data['email'];       // <-- AL

        if (token != null) {
          await _saveToken(token);
          if (role != null) await _saveRole(role);
          // İsim ve emaili kaydet
          if (fullName != null) await _saveUserInfo(fullName, email ?? ""); 
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Kayıt Hatası: $e');
      return false;
    }
  }

  // Token'ı Telefona Kaydet
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token', token);
  }

  // Token Var mı? (Oturum açık mı?)
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('jwt_token');
  }

  // Çıkış Yap
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
  }

  // Token'ı Getir (API isteklerinde kullanmak için)
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Rolü Telefona Kaydet
  Future<void> _saveRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_role', role);
  }

  // Rolü Getir
  Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('user_role');
  }

  Future<void> _saveUserInfo(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', name);
    await prefs.setString('user_email', email);
  }

  // Kullanıcı bilgilerini (Ad ve Email) getiren metod
  Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name': prefs.getString('user_name') ?? "Kullanıcı",
      'email': prefs.getString('user_email') ?? "",
    };
  }

}