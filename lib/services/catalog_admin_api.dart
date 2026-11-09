import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/catalog.dart';
import 'auth_service.dart';
import 'design_api.dart';

/// Katalog yönetim uçları. Her yazmadan sonra [DesignApi] önbelleğini geçersiz kılar.
class CatalogAdminApi {
  final Dio _dio;
  final DesignApi _designApi;

  CatalogAdminApi({Dio? dio, DesignApi? designApi})
      : _designApi = designApi ?? DesignApi(),
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
            )) {
    if (dio == null) {
      _dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
        final token = await AuthService().getToken();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      }));
    }
  }

  Future<T> _call<T>(Future<T> Function() f, {bool invalidate = false}) async {
    try {
      final result = await f();
      if (invalidate) await _designApi.invalidateCatalogCache();
      return result;
    } catch (e) {
      throw _mapError(e);
    }
  }

  ApiError _mapError(Object e) {
    final err = ApiError.from(e);
    if (err.status == 403) {
      return ApiError(403, err.code, 'Bu işlem için yönetici yetkisi gerekiyor.', err.details);
    }
    if (err.status == 409 && (err.code == 'CODE_TAKEN' || err.message.contains('CODE_TAKEN'))) {
      return ApiError(409, 'CODE_TAKEN', 'Bu kod zaten kullanılıyor.', err.details);
    }
    return err;
  }

  Future<CatalogSnapshot> snapshot() => _call(() async {
        final r = await _dio.get('/catalog/snapshot');
        return CatalogSnapshot.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  // --- Profiller ---

  Future<ProfileInfo> updateProfile(
    int id, {
    required String name,
    required double pricePerMeter,
    int? barLength,
    bool? isActive,
    bool? isDefault,
  }) =>
      _call(() async {
        final r = await _dio.put('/catalog/profiles/$id', data: {
          'name': name,
          'pricePerMeter': pricePerMeter,
          if (barLength != null) 'barLength': barLength,
          if (isActive != null) 'isActive': isActive,
          if (isDefault != null) 'isDefault': isDefault,
        });
        return ProfileInfo.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  // --- Camlar ---

  Future<GlassInfo> createGlass({
    required String code,
    required String name,
    int? thicknessMm,
    required String visualStyle,
    required double pricePerSquareMeter,
  }) =>
      _call(() async {
        final r = await _dio.post('/catalog/glasses', data: {
          'code': code,
          'name': name,
          if (thicknessMm != null) 'thicknessMm': thicknessMm,
          'visualStyle': visualStyle,
          'pricePerSquareMeter': pricePerSquareMeter,
        });
        return GlassInfo.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  Future<GlassInfo> updateGlass(
    int id, {
    required String name,
    int? thicknessMm,
    required String visualStyle,
    required double pricePerSquareMeter,
    bool? isActive,
  }) =>
      _call(() async {
        final r = await _dio.put('/catalog/glasses/$id', data: {
          'name': name,
          if (thicknessMm != null) 'thicknessMm': thicknessMm,
          'visualStyle': visualStyle,
          'pricePerSquareMeter': pricePerSquareMeter,
          if (isActive != null) 'isActive': isActive,
        });
        return GlassInfo.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  // --- Aksesuarlar ---

  Future<List<Accessory>> listAccessories({bool includeInactive = false}) => _call(() async {
        final r = await _dio.get('/catalog/accessories', queryParameters: {
          'includeInactive': includeInactive,
        });
        final list = r.data as List? ?? const [];
        return [for (final a in list) Accessory.fromJson(Map<String, dynamic>.from(a as Map))];
      });

  Future<Accessory> createAccessory({
    required String code,
    required String name,
    required String unit,
    required double price,
    bool isActive = true,
  }) =>
      _call(() async {
        final r = await _dio.post('/catalog/accessories', data: {
          'code': code,
          'name': name,
          'unit': unit,
          'price': price,
          'isActive': isActive,
        });
        return Accessory.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  Future<Accessory> updateAccessory(
    int id, {
    required String code,
    required String name,
    required String unit,
    required double price,
    bool? isActive,
  }) =>
      _call(() async {
        final r = await _dio.put('/catalog/accessories/$id', data: {
          'code': code,
          'name': name,
          'unit': unit,
          'price': price,
          if (isActive != null) 'isActive': isActive,
        });
        return Accessory.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  // --- Donanım kuralları ---

  Future<List<HardwareRule>> listHardwareRules() => _call(() async {
        final r = await _dio.get('/catalog/hardware-rules');
        final list = r.data as List? ?? const [];
        return [for (final h in list) HardwareRule.fromJson(Map<String, dynamic>.from(h as Map))];
      });

  Future<HardwareRule> createHardwareRule({
    required String kind,
    int? seriesId,
    required String accessoryCode,
    required String qtyType,
    required double qty,
    int? sortOrder,
  }) =>
      _call(() async {
        final r = await _dio.post('/catalog/hardware-rules', data: {
          'kind': kind,
          if (seriesId != null) 'seriesId': seriesId,
          'accessoryCode': accessoryCode,
          'qtyType': qtyType,
          'qty': qty,
          if (sortOrder != null) 'sortOrder': sortOrder,
        });
        return HardwareRule.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  Future<HardwareRule> updateHardwareRule(
    int id, {
    required String kind,
    int? seriesId,
    required String accessoryCode,
    required String qtyType,
    required double qty,
    int? sortOrder,
  }) =>
      _call(() async {
        final r = await _dio.put('/catalog/hardware-rules/$id', data: {
          'kind': kind,
          'seriesId': seriesId,
          'accessoryCode': accessoryCode,
          'qtyType': qtyType,
          'qty': qty,
          if (sortOrder != null) 'sortOrder': sortOrder,
        });
        return HardwareRule.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  Future<void> deleteHardwareRule(int id) => _call(() async {
        await _dio.delete('/catalog/hardware-rules/$id');
      }, invalidate: true);

  // --- Renkler ---

  Future<List<CatalogColor>> listColors({bool includeInactive = true}) => _call(() async {
        final r = await _dio.get('/catalog/colors', queryParameters: {
          if (!includeInactive) 'activeOnly': true,
        });
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['colors'] as List? ?? const []) : const []);
        return [for (final c in list) CatalogColor.fromJson(Map<String, dynamic>.from(c as Map))];
      });

  Future<CatalogColor> createColor({
    required String code,
    required String name,
    required String hexOutside,
    required String hexInside,
    double surchargePct = 0,
    bool isActive = true,
  }) =>
      _call(() async {
        final r = await _dio.post('/catalog/colors', data: {
          'code': code,
          'name': name,
          'hexOutside': hexOutside,
          'hexInside': hexInside,
          'surchargePct': surchargePct,
          'isActive': isActive,
        });
        return CatalogColor.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  Future<CatalogColor> updateColor(
    int id, {
    required String code,
    required String name,
    required String hexOutside,
    required String hexInside,
    double surchargePct = 0,
    bool isActive = true,
  }) =>
      _call(() async {
        final r = await _dio.put('/catalog/colors/$id', data: {
          'code': code,
          'name': name,
          'hexOutside': hexOutside,
          'hexInside': hexInside,
          'surchargePct': surchargePct,
          'isActive': isActive,
        });
        return CatalogColor.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: true);

  // --- Toplu zam ---

  Future<PriceAdjustmentResult> adjustPrices({
    required String target,
    required double percent,
    required bool dryRun,
  }) =>
      _call(() async {
        final r = await _dio.post(
          '/catalog/price-adjustment',
          queryParameters: {'dryRun': dryRun},
          data: {'target': target, 'percent': percent},
        );
        return PriceAdjustmentResult.fromJson(Map<String, dynamic>.from(r.data as Map));
      }, invalidate: !dryRun);
}
