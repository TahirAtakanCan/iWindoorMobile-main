import 'package:dio/dio.dart';
import 'package:iwindoor_mobil/models/cost_summary.dart';
import 'package:iwindoor_mobil/models/profile.dart';
import '../models/project.dart';
import '../models/project_specs.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

class ApiService {
  // Android Emulator için: 10.0.2.2
  // iOS Simulator için: 127.0.0.1 veya localhost
  // Gerçek Cihaz için: Bilgisayarının IP adresi (örn: 192.168.1.35)
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://192.168.0.37:8080/api/v1', 
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 5),
  ));
  
  ApiService() {
    // HER İSTEKTE TOKEN EKLEME MANTIĞI
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await AuthService().getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token'; // Token'ı başlığa ekle
        }
        return handler.next(options);
      },
      onError: (DioException e, handler) {
        if (e.response?.statusCode == 403) {
          // Token süresi dolmuş olabilir, kullanıcıyı Login'e atmak gerekebilir.
          print("Yetkisiz Erişim (403)");
        }
        return handler.next(e);
      },
    ));
  }  

  Future<Project?> getProject(int id) async {
    try {
      final response = await _dio.get('/projects/$id');
      
      if (response.statusCode == 200) {
        return Project.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print("API Hatası: $e");
      return null;
    }
  }

  // Node Bölme İsteği
  Future<bool> splitNode(int nodeId, bool isVertical) async {
    try {
      final response = await _dio.post(
        '/design/split/$nodeId',
        queryParameters: {'isVertical': isVertical},
      );
      
      return response.statusCode == 200;
    } catch (e) {
      print("Bölme Hatası: $e");
      return false;
    }
  }

  // Tip Güncelleme İsteği
  Future<bool> updateNodeType(int nodeId, String type) async {
    try {
      final response = await _dio.post(
        '/design/update-type/$nodeId',
        queryParameters: {'type': type},
      );
      return response.statusCode == 200;
    } catch (e) {
      print("Tip Güncelleme Hatası: $e");
      return false;
    }
  }

  // Filtreli Profil Getir
  Future<List<Profile>> getProfilesByType(String type) async {
    try {
      final response = await _dio.get('/catalog/profiles/filter', queryParameters: {'type': type});
      if (response.statusCode == 200) {
        var list = response.data as List;
        return list.map((i) => Profile.fromJson(i)).toList();
      }
      return [];
    } catch (e) {
      print("Profil Çekme Hatası: $e");
      return [];
    }
  }

  // Malzeme Ata
  Future<bool> assignMaterial(int nodeId, int materialId, String type) async {
    try {
      await _dio.post('/design/assign-material/$nodeId', queryParameters: {
        'materialId': materialId,
        'type': type // 'PROFILE' veya 'GLASS'
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // Fiyat Hesaplat
  Future<void> calculatePrice(int projectId) async {
    try {
      // DİKKAT: URL'in başındaki '/projects' kısmına ve {projectId}'ye dikkat et
      // Backend URL yapımız: /api/v1/projects/{id}/calculate-price
      // Dio BaseURL zaten /api/v1 ise, burası sadece /projects/... olmalı.
      
      await _dio.post('/projects/$projectId/calculate-price');
      
    } catch (e) {
      print("Fiyat Hesaplama Hatası: $e");
    }
  }

  // 1. Tüm Projeleri Çek
  Future<List<Project>> getAllProjects() async {
    try {
      final response = await _dio.get('/projects');
      if (response.statusCode == 200) {
        var list = response.data as List;
        return list.map((i) => Project.fromJson(i)).toList();
      }
      return [];
    } catch (e) {
      print("Proje Listesi Hatası: $e");
      return [];
    }
  }

  // 2. Yeni Proje Oluştur
  Future<Project?> createProject(String name, String description) async {
    try {
      final response = await _dio.post('/projects', data: {
        "name": name,
        "description": description,
        // Backend'de totalPrice ve windowUnits otomatik set ediliyor
      });
      
      if (response.statusCode == 200) {
        return Project.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print("Proje Oluşturma Hatası: $e");
      return null;
    }
  }

  // Pencere Ekle
  Future<bool> addWindow(int projectId, String name, double width, double height) async {
    try {
      await _dio.post('/projects/$projectId/windows', data: {
        "name": name,
        "width": width,
        "height": height
      });
      return true; // Başarılı
    } catch (e) {
      print("Pencere Ekleme Hatası: $e");
      return false;
    }
  }

  // Proje Güncelle
  Future<bool> updateProject(int id, String name, String description) async {
    try {
      final response = await _dio.put('/projects/$id', data: {
        "name": name,
        "description": description,
        // Backend entity yapısına göre diğer alanlar null gidebilir veya mevcut korunur
      });
      return response.statusCode == 200;
    } catch (e) {
      print("Güncelleme Hatası: $e");
      return false;
    }
  }

  // Proje Sil
  Future<bool> deleteProject(int id) async {
    try {
      final response = await _dio.delete('/projects/$id');
      return response.statusCode == 200;
    } catch (e) {
      print("Silme Hatası: $e");
      return false;
    }
  }

  Future<List<Profile>> getAllProfilesForConfig() async {
    try {
      // Önce Frame, sonra Sash, sonra Mullion çekip birleştirelim
      final frames = await getProfilesByType('FRAME');
      final sashes = await getProfilesByType('SASH');
      return [...frames, ...sashes];
    } catch (e) {
      return [];
    }
  }

  // Fiyat Güncelle
  Future<bool> updateProfilePrice(int id, double newPrice) async {
    try {
      // Query param olarak gönderiyoruz (?price=...)
      final response = await _dio.put('/catalog/profiles/$id/price', queryParameters: {
        "price": newPrice
      });
      return response.statusCode == 200;
    } catch (e) {
      print("Fiyat Güncelleme Hatası: $e");
      return false;
    }
  }

  Future<bool> syncProjectPrices(int projectId) async {
    try {
      await _dio.post('/projects/$projectId/sync-prices');
      return true;
    } catch (e) {
      return false;
    }
  }

  // Tüm Camları Getir
  Future<List<Glass>> getAllGlasses() async {
    try {
      final response = await _dio.get('/catalog/glasses');
      if (response.statusCode == 200) {
        var list = response.data as List;
        return list.map((i) => Glass.fromJson(i)).toList();
      }
      return [];
    } catch (e) {
      print("Cam Listesi Hatası: $e");
      return [];
    }
  }

  // Cam Fiyatı Güncelle
  Future<bool> updateGlassPrice(int id, double newPrice) async {
    try {
      final response = await _dio.put('/catalog/glasses/$id/price', queryParameters: {
        "price": newPrice
      });
      return response.statusCode == 200;
    } catch (e) {
      print("Cam Fiyat Güncelleme Hatası: $e");
      return false;
    }
  }

  // Maliyet Özeti Getir (MEO4)
  Future<ProjectCostSummary?> getCostSummary(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/cost-summary');
      if (response.statusCode == 200) {
        return ProjectCostSummary.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print("Maliyet Raporu Hatası: $e");
      return null;
    }
  }

  // MEO5: Teknik Özeti Getir
  Future<ProjectSpecs?> getProjectSpecs(int projectId) async {
    try {
      final response = await _dio.get('/projects/$projectId/specs');
      if (response.statusCode == 200) {
        return ProjectSpecs.fromJson(response.data);
      }
      return null;
    } catch (e) {
      print("Specs Hatası: $e");
      return null;
    }
  }

  // Çalışanları Listele
  Future<List<UserModel>> getEmployees() async {
    try {
      final response = await _dio.get('/users');
      if (response.statusCode == 200) {
        var list = response.data as List;
        return list.map((e) => UserModel.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      print("Çalışan Listesi Hatası: $e");
      return [];
    }
  }

  // Yeni Çalışan Ekle
  Future<bool> createEmployee(String fullName, String email, String password) async {
    try {
      final response = await _dio.post('/users', data: {
        'fullName': fullName,
        'email': email,
        'password': password,
      });
      return response.statusCode == 200;
    } catch (e) {
      print("Çalışan Ekleme Hatası: $e");
      return false;
    }
  }

}