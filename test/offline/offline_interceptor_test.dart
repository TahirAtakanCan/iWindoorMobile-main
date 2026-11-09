import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/services/offline/connectivity_state.dart';
import 'package:iwindoor_mobil/services/offline/offline_exception.dart';
import 'package:iwindoor_mobil/services/offline/offline_interceptor.dart';
import 'package:iwindoor_mobil/services/offline/response_cache.dart';

class _FailAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future? cancelFuture) async {
    throw DioException(
      requestOptions: options,
      type: DioExceptionType.connectionError,
      error: const SocketException('Network is unreachable'),
      message: 'connection error',
    );
  }
}

void main() {
  late Directory tmp;
  late ResponseCache cache;
  late ConnectivityState connectivity;
  late Dio dio;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('iwindoor_int_test_');
    cache = ResponseCache(root: tmp);
    connectivity = ConnectivityState.forTest();
    dio = Dio(BaseOptions(baseUrl: 'http://example.test/api/v1'));
    dio.httpClientAdapter = _FailAdapter();
    dio.interceptors.add(OfflineInterceptor(cache: cache, connectivity: connectivity));
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('bağlantı hatasında önbellekten dönüş ve x-offline', () async {
    await cache.putJson('GET /projects/1', {'id': 1});
    final r = await dio.get('/projects/1');
    expect(r.statusCode, 200);
    expect(r.headers.value('x-offline'), '1');
    expect(r.headers.value('x-cached-at'), isNotNull);
    expect(r.data['id'], 1);
    expect(connectivity.isOffline, isTrue);
  });

  test('önbellek yoksa OfflineException', () async {
    try {
      await dio.get('/projects/999');
      fail('exception beklenirdi');
    } on DioException catch (e) {
      expect(e.error, isA<OfflineException>());
    }
  });

  test('POST bağlantı hatasında OfflineException', () async {
    try {
      await dio.post('/projects', data: {'name': 'x'});
      fail('exception beklenirdi');
    } on DioException catch (e) {
      expect(e.error, isA<OfflineException>());
      expect((e.error as OfflineException).isWrite, isTrue);
    }
  });
}
