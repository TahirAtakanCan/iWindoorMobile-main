import 'package:dio/dio.dart';

import '../models/company.dart';
import '../models/project_quote.dart';
import 'design_api.dart';
import 'offline/api_dio.dart';

class CompanyApi {
  final Dio _dio;

  CompanyApi({Dio? dio}) : _dio = dio ?? createApiDio();

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

  Future<List<QuoteExtra>> listExtras(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/extras');
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['extras'] as List? ?? const []) : const []);
        return [for (final e in list) QuoteExtra.fromJson(Map<String, dynamic>.from(e as Map))];
      });

  Future<QuoteExtra> createExtra(int projectId, QuoteExtra extra) => _call(() async {
        final r = await _dio.post('/projects/$projectId/extras', data: extra.toJson());
        return QuoteExtra.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<QuoteExtra> updateExtra(int projectId, int itemId, QuoteExtra extra) => _call(() async {
        final r = await _dio.put('/projects/$projectId/extras/$itemId', data: extra.toJson());
        return QuoteExtra.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> deleteExtra(int projectId, int itemId) => _call(() => _dio.delete('/projects/$projectId/extras/$itemId'));
}
