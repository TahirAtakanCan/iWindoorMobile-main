import 'package:dio/dio.dart';
import 'package:windoor_core/windoor_core.dart';

import '../config/app_config.dart';
import 'auth_service.dart';
import 'design_api.dart';

/// Firma şablonu: GET/POST /api/v1/templates.
class CompanyTemplate {
  final int id;
  final String name;
  final String category;
  final int sortOrder;
  final WindowDesign design;
  final DateTime? updatedAt;

  const CompanyTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.design,
    this.sortOrder = 0,
    this.updatedAt,
  });

  factory CompanyTemplate.fromJson(Map<String, dynamic> j) => CompanyTemplate(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        category: j['category'] as String? ?? 'WINDOW',
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
        design: WindowDesign.fromJson(Map<String, dynamic>.from(j['design'] as Map)),
        updatedAt: DateTime.tryParse('${j['updatedAt'] ?? ''}'),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'sortOrder': sortOrder,
        'design': design.toJson(),
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };
}

class TemplateApi {
  final Dio _dio;

  TemplateApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 15),
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

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw _mapError(e);
    }
  }

  ApiError _mapError(Object e) {
    final err = ApiError.from(e);
    if (err.status == 403) {
      return ApiError(403, err.code, 'Bu işlem için yönetici yetkisi gerekiyor.', err.details);
    }
    if (err.status == 409 && (err.code == 'TEMPLATE_NAME_TAKEN' || err.message.contains('TEMPLATE_NAME_TAKEN'))) {
      return ApiError(409, 'TEMPLATE_NAME_TAKEN', 'Bu adda bir şablon zaten var.', err.details);
    }
    if (err.status == 400 && err.code == 'TEMPLATE_LIMIT') {
      return ApiError(400, 'TEMPLATE_LIMIT', 'Şablon limitine ulaşıldı.', err.details);
    }
    return err;
  }

  Future<List<CompanyTemplate>> list({String? category}) => _call(() async {
        final r = await _dio.get('/templates', queryParameters: {
          if (category != null && category.isNotEmpty) 'category': category,
        });
        final list = r.data as List? ?? const [];
        return [for (final t in list) CompanyTemplate.fromJson(Map<String, dynamic>.from(t as Map))];
      });

  Future<CompanyTemplate> create({
    required String name,
    required String category,
    required WindowDesign design,
  }) =>
      _call(() async {
        final r = await _dio.post('/templates', data: {
          'name': name,
          'category': category,
          'design': design.toJson(),
        });
        return CompanyTemplate.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<CompanyTemplate> update(
    int id, {
    String? name,
    String? category,
    int? sortOrder,
    WindowDesign? design,
  }) =>
      _call(() async {
        final r = await _dio.put('/templates/$id', data: {
          if (name != null) 'name': name,
          if (category != null) 'category': category,
          if (sortOrder != null) 'sortOrder': sortOrder,
          if (design != null) 'design': design.toJson(),
        });
        return CompanyTemplate.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> delete(int id) => _call(() => _dio.delete('/templates/$id'));
}
