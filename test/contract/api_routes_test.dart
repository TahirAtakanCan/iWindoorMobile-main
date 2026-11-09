import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// lib/ altındaki Dio çağrılarının backend api-routes listesinde olduğunu doğrular.
void main() {
  test('API sözleşme: istemci yolları backend listesinde', () {
    final backendCandidates = [
      File('../iWindoorBackend-main/docs/api-routes.txt'),
      File('test/fixtures/api-routes.txt'),
    ];
    File? routesFile;
    for (final f in backendCandidates) {
      if (f.existsSync()) {
        routesFile = f;
        break;
      }
    }
    if (routesFile == null) {
      // ignore: avoid_print
      print('SKIP: api-routes.txt bulunamadı (../iWindoorBackend-main/docs veya test/fixtures).');
      return;
    }

    final backend = routesFile
        .readAsLinesSync()
        .map((l) => l.replaceAll('\uFEFF', '').trim()) // Windows BOM
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .map(_normalizeRouteLine)
        .toSet();

    final calls = <String>{};
    final lib = Directory('lib');
    for (final f in lib.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final src = f.readAsStringSync();
      calls.addAll(_extractCalls(src));
    }

    // ignore: avoid_print
    print('Sözleşme: ${calls.length} istemci çağrısı kontrol edildi (kaynak: ${routesFile.path}).');

    final missing = <String>[];
    for (final c in calls.toList()..sort()) {
      if (!backend.contains(c)) missing.add(c);
    }

    expect(
      missing,
      isEmpty,
      reason: 'Backend listesinde olmayan istemci çağrıları:\n${missing.join('\n')}',
    );
  });
}

String _normalizeRouteLine(String line) {
  final sp = line.indexOf(' ');
  if (sp < 0) return line;
  final method = line.substring(0, sp).toUpperCase();
  final path = _normalizePath(line.substring(sp + 1));
  return '$method $path';
}

Set<String> _extractCalls(String src) {
  final out = <String>{};
  // _dio.get('/x' | _dio.get<List<int>>('\n  '/x' | dio.post(
  final re = RegExp(
    r'''(?:_dio|dio)\.(get|post|put|delete|patch)(?:\s*<[^;{]+?>)?\s*\(\s*(['"])([^'"]+)\2''',
    multiLine: true,
  );
  for (final m in re.allMatches(src)) {
    final method = m.group(1)!.toUpperCase();
    var path = m.group(3)!;
    if (path.contains(r'$_baseUrl')) {
      path = path.replaceAll(r'$_baseUrl', '/api/v1/auth');
    }
    path = _normalizePath(path);
    if (path.isEmpty || path == '/') continue;
    if (!path.startsWith('/api/v1')) {
      path = '/api/v1$path';
    }
    out.add('$method $path');
  }
  return out;
}

String _normalizePath(String raw) {
  var p = raw.trim();
  final q = p.indexOf('?');
  if (q >= 0) p = p.substring(0, q);
  // '${id}' / '$id' / '{id}' / '{projectId}' → {}
  p = p.replaceAllMapped(RegExp(r'\$\{[^}]+\}'), (_) => '{}');
  p = p.replaceAllMapped(RegExp(r'\$[A-Za-z_][A-Za-z0-9_]*'), (_) => '{}');
  p = p.replaceAllMapped(RegExp(r'\{[^}]+\}'), (_) => '{}');
  while (p.contains('//') && !p.startsWith('http')) {
    p = p.replaceAll('//', '/');
  }
  if (p.isEmpty) return p;
  if (!p.startsWith('/')) p = '/$p';
  return p;
}
