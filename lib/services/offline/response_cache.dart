import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class CacheEntry {
  final String key;
  final DateTime cachedAt;
  final DateTime lastUsedAt;
  final bool isBytes;
  final int sizeBytes;
  final String? jsonBody;
  final Uint8List? bytes;

  const CacheEntry({
    required this.key,
    required this.cachedAt,
    required this.lastUsedAt,
    required this.isBytes,
    required this.sizeBytes,
    this.jsonBody,
    this.bytes,
  });
}

/// Dosya tabanlı GET yanıt önbelleği (max 100 MB, LRU silme).
class ResponseCache {
  static const maxBytes = 100 * 1024 * 1024;
  static const _indexFile = 'index.json';

  Directory? _root;
  final Map<String, _IndexRow> _index = {};
  bool _ready = false;
  final int maxBytesLimit;

  /// Test için özel kök / boyut sınırı.
  ResponseCache({Directory? root, this.maxBytesLimit = maxBytes}) : _root = root;

  static String cacheKey(String method, String path, [Map<String, dynamic>? query]) {
    final q = query == null || query.isEmpty
        ? ''
        : '?${(query.keys.toList()..sort()).map((k) => '$k=${query[k]}').join('&')}';
    return '${method.toUpperCase()} $path$q';
  }

  Future<void> ensureReady() async {
    if (_ready) return;
    _root ??= Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}iwindoor_cache');
    if (!await _root!.exists()) await _root!.create(recursive: true);
    final idx = File('${_root!.path}${Platform.pathSeparator}$_indexFile');
    if (await idx.exists()) {
      try {
        final map = jsonDecode(await idx.readAsString()) as Map<String, dynamic>;
        for (final e in map.entries) {
          final v = Map<String, dynamic>.from(e.value as Map);
          _index[e.key] = _IndexRow(
            file: v['file'] as String,
            cachedAt: DateTime.tryParse('${v['cachedAt']}') ?? DateTime.now(),
            lastUsedAt: DateTime.tryParse('${v['lastUsedAt']}') ?? DateTime.now(),
            sizeBytes: (v['size'] as num?)?.toInt() ?? 0,
            isBytes: v['isBytes'] == true,
          );
        }
      } catch (_) {}
    }
    _ready = true;
  }

  Future<int> totalBytes() async {
    await ensureReady();
    return _index.values.fold<int>(0, (a, b) => a + b.sizeBytes);
  }

  Future<List<String>> keys() async {
    await ensureReady();
    return _index.keys.toList();
  }

  Future<void> putJson(String key, Object body) async {
    await ensureReady();
    final encoded = jsonEncode(body);
    final bytes = utf8.encode(encoded);
    await _write(key, Uint8List.fromList(bytes), isBytes: false);
  }

  Future<void> putBytes(String key, Uint8List bytes) async {
    await ensureReady();
    await _write(key, bytes, isBytes: true);
  }

  Future<CacheEntry?> get(String key) async {
    await ensureReady();
    final row = _index[key];
    if (row == null) return null;
    final file = File('${_root!.path}${Platform.pathSeparator}${row.file}');
    if (!await file.exists()) {
      _index.remove(key);
      await _persistIndex();
      return null;
    }
    final data = await file.readAsBytes();
    row.lastUsedAt = DateTime.now();
    await _persistIndex();
    if (row.isBytes) {
      return CacheEntry(
        key: key,
        cachedAt: row.cachedAt,
        lastUsedAt: row.lastUsedAt,
        isBytes: true,
        sizeBytes: data.length,
        bytes: data,
      );
    }
    return CacheEntry(
      key: key,
      cachedAt: row.cachedAt,
      lastUsedAt: row.lastUsedAt,
      isBytes: false,
      sizeBytes: data.length,
      jsonBody: utf8.decode(data),
    );
  }

  Future<void> remove(String key) async {
    await ensureReady();
    final row = _index.remove(key);
    if (row != null) {
      final f = File('${_root!.path}${Platform.pathSeparator}${row.file}');
      if (await f.exists()) await f.delete();
      await _persistIndex();
    }
  }

  Future<void> clear() async {
    await ensureReady();
    for (final row in _index.values) {
      final f = File('${_root!.path}${Platform.pathSeparator}${row.file}');
      if (await f.exists()) await f.delete();
    }
    _index.clear();
    await _persistIndex();
  }

  Future<void> _write(String key, Uint8List data, {required bool isBytes}) async {
    final safe = base64Url.encode(utf8.encode(key)).replaceAll('=', '');
    final name = '${safe.length > 80 ? safe.substring(0, 80) : safe}_${key.hashCode.abs()}.bin';
    final old = _index[key];
    if (old != null) {
      final f = File('${_root!.path}${Platform.pathSeparator}${old.file}');
      if (await f.exists()) await f.delete();
    }
    final file = File('${_root!.path}${Platform.pathSeparator}$name');
    await file.writeAsBytes(data, flush: true);
    final now = DateTime.now();
    _index[key] = _IndexRow(file: name, cachedAt: now, lastUsedAt: now, sizeBytes: data.length, isBytes: isBytes);
    await _evictIfNeeded();
    await _persistIndex();
  }

  Future<void> _evictIfNeeded() async {
    var total = _index.values.fold<int>(0, (a, b) => a + b.sizeBytes);
    if (total <= maxBytesLimit) return;
    final ordered = _index.entries.toList()
      ..sort((a, b) => a.value.lastUsedAt.compareTo(b.value.lastUsedAt));
    for (final e in ordered) {
      if (total <= maxBytesLimit) break;
      final f = File('${_root!.path}${Platform.pathSeparator}${e.value.file}');
      if (await f.exists()) await f.delete();
      total -= e.value.sizeBytes;
      _index.remove(e.key);
    }
  }

  Future<void> _persistIndex() async {
    final map = <String, dynamic>{
      for (final e in _index.entries)
        e.key: {
          'file': e.value.file,
          'cachedAt': e.value.cachedAt.toIso8601String(),
          'lastUsedAt': e.value.lastUsedAt.toIso8601String(),
          'size': e.value.sizeBytes,
          'isBytes': e.value.isBytes,
        },
    };
    final idx = File('${_root!.path}${Platform.pathSeparator}$_indexFile');
    await idx.writeAsString(jsonEncode(map), flush: true);
  }
}

class _IndexRow {
  final String file;
  final DateTime cachedAt;
  DateTime lastUsedAt;
  final int sizeBytes;
  final bool isBytes;

  _IndexRow({
    required this.file,
    required this.cachedAt,
    required this.lastUsedAt,
    required this.sizeBytes,
    required this.isBytes,
  });
}
