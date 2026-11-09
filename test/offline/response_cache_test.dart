import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/services/offline/response_cache.dart';

void main() {
  late Directory tmp;
  late ResponseCache cache;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('iwindoor_cache_test_');
    cache = ResponseCache(root: tmp, maxBytesLimit: 10 * 1024);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('yaz/oku', () async {
    await cache.putJson('GET /projects/1', {'id': 1, 'name': 'A'});
    final e = await cache.get('GET /projects/1');
    expect(e, isNotNull);
    expect(e!.jsonBody, contains('A'));
  });

  test('boyut sınırı ile eski kayıt silinir', () async {
    final chunk = Uint8List(3 * 1024);
    for (var i = 0; i < 6; i++) {
      await cache.putBytes('GET /big/$i', chunk);
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }
    final keys = await cache.keys();
    expect(keys.contains('GET /big/0'), isFalse);
    expect(await cache.totalBytes(), lessThanOrEqualTo(10 * 1024));
  });
}
