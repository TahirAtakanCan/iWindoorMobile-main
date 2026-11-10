import 'package:dio/dio.dart';

import '../../config/app_config.dart';
import '../auth_service.dart';
import '../session_guard.dart';
import 'connectivity_state.dart';
import 'offline_interceptor.dart';
import 'response_cache.dart';

final ResponseCache sharedResponseCache = ResponseCache();

/// Ortak Dio: auth + çevrimdışı önbellek interceptor.
Dio createApiDio({
  Duration connectTimeout = const Duration(seconds: 8),
  Duration receiveTimeout = const Duration(seconds: 15),
  ResponseCache? cache,
  ConnectivityState? connectivity,
  bool Function(RequestOptions options)? allowOutboxWrite,
  bool enableOffline = true,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: connectTimeout,
    receiveTimeout: receiveTimeout,
    contentType: Headers.jsonContentType,
  ));

  dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) async {
    final token = await AuthService().getToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }, onError: (err, handler) {
    // Süresi dolmuş / geçersiz oturum: giriş ekranına dön (giriş ve kayıt istekleri hariç).
    final path = err.requestOptions.path;
    if (err.response?.statusCode == 401 && !path.contains('/auth/')) {
      SessionGuard.onUnauthorized();
    }
    handler.next(err);
  }));

  if (enableOffline) {
    dio.interceptors.add(OfflineInterceptor(
      cache: cache ?? sharedResponseCache,
      connectivity: connectivity ?? ConnectivityState.instance,
      allowOutboxWrite: allowOutboxWrite,
    ));
  }

  return dio;
}
