import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'connectivity_state.dart';
import 'offline_exception.dart';
import 'response_cache.dart';

/// GET önbellekleme + bağlantı hatasında çevrimdışı dönüş.
class OfflineInterceptor extends Interceptor {
  final ResponseCache cache;
  final ConnectivityState connectivity;

  /// true ise yazma hatası SurveyApi outbox katmanına bırakılır.
  final bool Function(RequestOptions options)? allowOutboxWrite;

  OfflineInterceptor({
    required this.cache,
    required this.connectivity,
    this.allowOutboxWrite,
  });

  static bool isConnectivityError(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return true;
    }
    return e.error is SocketException;
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    connectivity.markOnline();
    final req = response.requestOptions;
    if (req.method.toUpperCase() == 'GET' && (response.statusCode ?? 500) < 400) {
      final key = ResponseCache.cacheKey(
        req.method,
        pathOf(req),
        req.queryParameters.isEmpty ? null : Map<String, dynamic>.from(req.queryParameters),
      );
      final data = response.data;
      if (data is List<int>) {
        cache.putBytes(key, Uint8List.fromList(data));
      } else if (data != null) {
        cache.putJson(key, data);
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (!isConnectivityError(err)) {
      handler.next(err);
      return;
    }
    connectivity.markOffline();
    final req = err.requestOptions;
    final method = req.method.toUpperCase();

    if (method == 'GET') {
      final key = ResponseCache.cacheKey(
        method,
        pathOf(req),
        req.queryParameters.isEmpty ? null : Map<String, dynamic>.from(req.queryParameters),
      );
      final entry = await cache.get(key);
      if (entry != null) {
        Object? data;
        if (entry.isBytes) {
          data = entry.bytes;
        } else if (entry.jsonBody != null) {
          data = jsonDecode(entry.jsonBody!);
        }
        handler.resolve(
          Response(
            requestOptions: req,
            data: data,
            statusCode: 200,
            headers: Headers.fromMap({
              'x-offline': ['1'],
              'x-cached-at': [entry.cachedAt.toIso8601String()],
            }),
          ),
        );
        return;
      }
      handler.reject(
        DioException(
          requestOptions: req,
          error: OfflineException.readMissing(),
          type: DioExceptionType.unknown,
          message: OfflineException.readMissing().message,
        ),
      );
      return;
    }

    if (allowOutboxWrite?.call(req) == true) {
      handler.next(err);
      return;
    }

    handler.reject(
      DioException(
        requestOptions: req,
        error: OfflineException.writeRequired(),
        type: DioExceptionType.unknown,
        message: OfflineException.writeRequired().message,
      ),
    );
  }

  static String pathOf(RequestOptions req) {
    var p = req.path;
    if (p.startsWith('http')) {
      p = Uri.parse(p).path;
      if (p.startsWith('/api/v1')) p = p.substring('/api/v1'.length);
    }
    if (!p.startsWith('/')) p = '/$p';
    return p;
  }
}
