import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/quote_version.dart';
import 'auth_service.dart';
import 'design_api.dart';

class VersionApi {
  final Dio _dio;

  VersionApi({Dio? dio})
      : _dio = dio ??
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

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<QuoteVersionSummary>> list(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/versions');
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['versions'] as List? ?? const []) : const []);
        return [for (final e in list) QuoteVersionSummary.fromJson(Map<String, dynamic>.from(e as Map))];
      });

  Future<QuoteVersionSummary> create(int projectId, {String? label}) => _call(() async {
        final r = await _dio.post('/projects/$projectId/versions', data: {
          if (label != null && label.trim().isNotEmpty) 'label': label.trim(),
        });
        return QuoteVersionSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<QuoteVersionSnapshot> get(int versionId) => _call(() async {
        final r = await _dio.get('/versions/$versionId');
        return QuoteVersionSnapshot.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> delete(int versionId) => _call(() => _dio.delete('/versions/$versionId'));

  Future<void> restore(int versionId) => _call(() => _dio.post('/versions/$versionId/restore'));
}
