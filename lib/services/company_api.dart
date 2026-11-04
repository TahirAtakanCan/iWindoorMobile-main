import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/company.dart';
import '../models/project_quote.dart';
import 'auth_service.dart';
import 'design_api.dart';

class CompanyApi {
  final Dio _dio;

  CompanyApi({Dio? dio})
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
      throw ApiError.from(e);
    }
  }

  Future<CompanyProfile> getCompany() => _call(() async {
        final r = await _dio.get('/company');
        return CompanyProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<CompanyProfile> updateCompany(CompanyProfile profile) => _call(() async {
        final r = await _dio.put('/company', data: profile.toJson());
        return CompanyProfile.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<ProjectQuote> getProjectQuote(int projectId, {double? discountPct}) => _call(() async {
        final r = await _dio.get(
          '/projects/$projectId/quote',
          queryParameters: {
            if (discountPct != null) 'discountPct': discountPct,
          },
        );
        return ProjectQuote.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}
