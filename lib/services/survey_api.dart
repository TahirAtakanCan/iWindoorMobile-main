import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../models/survey.dart';
import 'auth_service.dart';
import 'design_api.dart';

class SurveyApi {
  final Dio _dio;

  SurveyApi({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.apiUrl,
              connectTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 30),
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

  Future<List<SurveyItem>> list(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/survey');
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['survey'] as List? ?? const []) : const []);
        return [for (final e in list) SurveyItem.fromJson(Map<String, dynamic>.from(e as Map))];
      });

  Future<SurveyItem> create(int projectId, SurveyItem item) => _call(() async {
        final r = await _dio.post('/projects/$projectId/survey', data: item.toJson());
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<SurveyItem> update(int projectId, int itemId, SurveyItem item) => _call(() async {
        final r = await _dio.put('/projects/$projectId/survey/$itemId', data: item.toJson());
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> delete(int projectId, int itemId) =>
      _call(() => _dio.delete('/projects/$projectId/survey/$itemId'));

  Future<SurveyPhoto> uploadPhoto(int projectId, int itemId, Uint8List bytes, {String filename = 'photo.jpg'}) =>
      _call(() async {
        final lower = filename.toLowerCase();
        final mime = lower.endsWith('.png')
            ? 'image/png'
            : (lower.endsWith('.webp') ? 'image/webp' : 'image/jpeg');
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename, contentType: DioMediaType.parse(mime)),
        });
        final r = await _dio.post(
          '/projects/$projectId/survey/$itemId/photos',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
        return SurveyPhoto.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<Uint8List> getPhotoBytes(int photoId) => _call(() async {
        final r = await _dio.get<List<int>>(
          '/survey-photos/$photoId',
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(r.data ?? const []);
      });

  Future<void> deletePhoto(int photoId) => _call(() => _dio.delete('/survey-photos/$photoId'));

  Future<SurveyItem> link(int projectId, int itemId, int windowId) => _call(() async {
        final r = await _dio.put('/projects/$projectId/survey/$itemId/link', data: {'windowUnitId': windowId});
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}
