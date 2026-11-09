import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:windoor_core/windoor_core.dart';

import '../config/app_config.dart';
import '../models/catalog.dart';
import 'auth_service.dart';

/// Sunucunun döndüğü pencere + tasarım belgesi (GET/PUT /api/v1/windows/{id}).
class WindowDoc {
  final int id;
  final int? projectId;
  final String name;
  final int quantity;
  final int? seriesId;
  final WindowDesign design;
  final bool legacyDesign;
  final double? unitPrice;
  final int rowVersion;

  const WindowDoc({
    required this.id,
    required this.name,
    required this.quantity,
    required this.design,
    required this.legacyDesign,
    required this.rowVersion,
    this.projectId,
    this.seriesId,
    this.unitPrice,
  });

  factory WindowDoc.fromJson(Map<String, dynamic> j) => WindowDoc(
        id: (j['id'] as num).toInt(),
        projectId: (j['projectId'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        seriesId: (j['seriesId'] as num?)?.toInt(),
        design: WindowDesign.fromJson(Map<String, dynamic>.from(j['design'] as Map)),
        legacyDesign: j['legacyDesign'] == true,
        unitPrice: (j['unitPrice'] as num?)?.toDouble(),
        rowVersion: (j['rowVersion'] as num?)?.toInt() ?? 0,
      );
}

class QuoteLine {
  final String group, code, name, unit;
  final double quantity, unitPrice, total;
  const QuoteLine(this.group, this.code, this.name, this.quantity, this.unit, this.unitPrice, this.total);

  factory QuoteLine.fromJson(Map<String, dynamic> j) => QuoteLine(
        j['group'] as String? ?? '',
        j['code'] as String? ?? '',
        j['name'] as String? ?? '',
        (j['quantity'] as num?)?.toDouble() ?? 0,
        j['unit'] as String? ?? '',
        (j['unitPrice'] as num?)?.toDouble() ?? 0,
        (j['total'] as num?)?.toDouble() ?? 0,
      );
}

class Quote {
  final List<QuoteLine> lines;
  final double unitTotal, total;
  final int quantity;
  final String currency;
  final List<String> warnings;
  const Quote(this.lines, this.unitTotal, this.quantity, this.total, this.currency, this.warnings);

  factory Quote.fromJson(Map<String, dynamic> j) => Quote(
        [for (final l in (j['lines'] as List? ?? const [])) QuoteLine.fromJson(Map<String, dynamic>.from(l as Map))],
        (j['unitTotal'] as num?)?.toDouble() ?? 0,
        (j['quantity'] as num?)?.toInt() ?? 1,
        (j['total'] as num?)?.toDouble() ?? 0,
        j['currency'] as String? ?? 'TRY',
        [for (final w in (j['warnings'] as List? ?? const [])) '$w'],
      );
}

/// Sunucunun anlaşılır hata yanıtı (ProblemDetail: code + detail + errors).
class ApiError implements Exception {
  final int? status;
  final String code;
  final String message;
  final List<String> details;
  const ApiError(this.status, this.code, this.message, [this.details = const []]);

  bool get isConflict => status == 409 && code == 'STALE_VERSION';
  bool get isUnauthorized => status == 401;
  bool get isNetwork => status == null;

  factory ApiError.from(Object e) {
    if (e is ApiError) return e;
    if (e is DioException) {
      final r = e.response;
      if (r == null) {
        return const ApiError(null, 'NETWORK', 'Sunucuya ulaşılamadı. Sunucu adresini ve bağlantıyı kontrol edin.');
      }
      final data = r.data;
      if (data is Map) {
        final errors = data['errors'];
        final details = <String>[
          if (errors is List)
            for (final x in errors)
              x is Map ? '${x['path'] ?? x['field'] ?? ''} ${x['message'] ?? ''}'.trim() : '$x',
        ];
        return ApiError(r.statusCode, '${data['code'] ?? data['title'] ?? 'HTTP_${r.statusCode}'}',
            '${data['detail'] ?? 'İstek başarısız (${r.statusCode}).'}', details);
      }
      return ApiError(r.statusCode, 'HTTP_${r.statusCode}', 'İstek başarısız (${r.statusCode}).');
    }
    return ApiError(null, 'UNKNOWN', '$e');
  }

  @override
  String toString() => details.isEmpty ? message : '$message\n${details.join('\n')}';
}

/// Yeni çizim motorunun kullandığı uçlar: katalog paketi ve tasarım belgesi.
class DesignApi {
  static const _catalogCacheKey = 'catalog_snapshot_v1';

  final Dio _dio;

  DesignApi({Dio? dio})
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

  /// Katalog: önce sunucu, olmazsa son kaydedilen kopya, o da yoksa varsayılan.
  Future<CatalogSnapshot> catalog({bool allowCache = true}) async {
    try {
      final r = await _dio.get('/catalog/snapshot');
      final map = Map<String, dynamic>.from(r.data as Map);
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_catalogCacheKey, jsonEncode(map));
      } catch (_) {}
      return CatalogSnapshot.fromJson(map);
    } catch (e) {
      if (!allowCache) throw ApiError.from(e);
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_catalogCacheKey);
      if (cached != null) {
        return CatalogSnapshot.fromJson(Map<String, dynamic>.from(jsonDecode(cached) as Map), fromCache: true);
      }
      return CatalogSnapshot.fallback;
    }
  }

  /// Katalog yazma işlemlerinden sonra yerel önbelleği siler.
  Future<void> invalidateCatalogCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_catalogCacheKey);
  }

  Future<WindowDoc> getWindow(int id) => _call(() async {
        final r = await _dio.get('/windows/$id');
        return WindowDoc.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  /// Tüm belge + kesim listesi tek seferde. rowVersion eskiyse ApiError(isConflict) fırlatır.
  Future<WindowDoc> saveWindow({
    required int id,
    required String name,
    required int quantity,
    required int? seriesId,
    required WindowDesign design,
    required List<Map<String, dynamic>> bom,
    required int rowVersion,
  }) =>
      _call(() async {
        final r = await _dio.put('/windows/$id', data: {
          'name': name,
          'quantity': quantity,
          'seriesId': seriesId,
          'design': design.toJson(),
          'bom': bom,
          'rowVersion': rowVersion,
        });
        return WindowDoc.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<WindowDoc> createWindow({
    required int projectId,
    required String name,
    required WindowDesign design,
    int? seriesId,
    int quantity = 1,
  }) =>
      _call(() async {
        final r = await _dio.post('/projects/$projectId/windows', data: {
          'name': name,
          'width': design.width,
          'height': design.height,
          'quantity': quantity,
          'seriesId': seriesId,
          'design': design.toJson(),
        });
        return WindowDoc.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> deleteWindow(int id) => _call(() => _dio.delete('/windows/$id'));

  /// Elle satış fiyatı. [override] null → otomatik fiyata dön.
  Future<void> setSalePrice(int windowId, {double? override}) => _call(() async {
        await _dio.put('/windows/$windowId/sale-price', data: {'override': override});
      });

  Future<Quote> quote(int id) => _call(() async {
        final r = await _dio.get('/windows/$id/quote');
        return Quote.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
}
