import 'dart:convert';

import 'package:dio/dio.dart';

import '../models/project.dart';
import 'design_api.dart';
import 'offline/api_dio.dart';

class ProjectFileApi {
  final Dio _dio;

  ProjectFileApi({Dio? dio})
      : _dio = dio ??
            createApiDio(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 60),
            );

  Future<(String fileName, String json)> exportProject(int id) async {
    try {
      final r = await _dio.get('/projects/$id/export');
      final data = r.data;
      final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
      final json = const JsonEncoder.withIndent('  ').convert(map);
      final fileName = _fileNameFromHeaders(r.headers, fallback: _fallbackName(map));
      return (fileName, json);
    } catch (e) {
      throw _mapError(e);
    }
  }

  Future<Project> importProject(String json) async {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! Map) {
        throw const ApiError(400, 'INVALID_PROJECT_FILE', 'Proje dosyası geçersiz.');
      }
      final r = await _dio.post('/projects/import', data: decoded);
      return Project.fromJson(Map<String, dynamic>.from(r.data as Map));
    } catch (e) {
      throw _mapError(e);
    }
  }

  ApiError _mapError(Object e) {
    final err = ApiError.from(e);
    if (err.code == 'INVALID_PROJECT_FILE') {
      return ApiError(err.status, err.code, 'Proje dosyası geçersiz.', err.details);
    }
    return err;
  }

  static String _fileNameFromHeaders(Headers headers, {required String fallback}) {
    final cd = headers.value('content-disposition') ?? headers.value('Content-Disposition');
    if (cd != null) {
      final m = RegExp(r'''filename\*?=(?:UTF-8''|")?([^\";]+)''', caseSensitive: false).firstMatch(cd);
      if (m != null) {
        var name = m.group(1)!.trim().replaceAll('"', '');
        try {
          name = Uri.decodeComponent(name);
        } catch (_) {}
        if (name.isNotEmpty) return name.endsWith('.iwd') ? name : '$name.iwd';
      }
    }
    return fallback;
  }

  static String _fallbackName(Map<String, dynamic> map) {
    final project = map['project'];
    final name = project is Map ? (project['name'] as String?) : null;
    final safe = (name ?? 'proje').replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
    return '${safe.isEmpty ? 'proje' : safe}.iwd';
  }
}
