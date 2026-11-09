import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/survey.dart';
import '../../utils/survey_helpers.dart';
import '../survey_api.dart';
import 'connectivity_state.dart';

enum OutboxOpType { createItem, updateItem, deleteItem, uploadPhoto }

enum OutboxItemStatus { pending, failed }

class OutboxItem {
  final String id;
  final OutboxOpType type;
  final String clientId;
  int? serverItemId;
  final int projectId;
  Map<String, dynamic>? payload;
  String? photoPath;
  OutboxItemStatus status;
  String? errorMessage;

  OutboxItem({
    required this.id,
    required this.type,
    required this.clientId,
    required this.projectId,
    this.serverItemId,
    this.payload,
    this.photoPath,
    this.status = OutboxItemStatus.pending,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'clientId': clientId,
        'serverItemId': serverItemId,
        'projectId': projectId,
        'payload': payload,
        'photoPath': photoPath,
        'status': status.name,
        'errorMessage': errorMessage,
      };

  factory OutboxItem.fromJson(Map<String, dynamic> j) => OutboxItem(
        id: j['id'] as String,
        type: OutboxOpType.values.byName(j['type'] as String),
        clientId: j['clientId'] as String,
        serverItemId: (j['serverItemId'] as num?)?.toInt(),
        projectId: (j['projectId'] as num).toInt(),
        payload: j['payload'] is Map ? Map<String, dynamic>.from(j['payload'] as Map) : null,
        photoPath: j['photoPath'] as String?,
        status: OutboxItemStatus.values.byName(j['status'] as String? ?? 'pending'),
        errorMessage: j['errorMessage'] as String?,
      );
}

/// Keşif yazma kuyruğu (FIFO, dosyada kalıcı).
class SurveyOutbox {
  Directory? _root;
  final List<OutboxItem> _queue = [];
  final List<OutboxItem> _failed = [];
  bool _ready = false;
  bool _syncing = false;

  SurveyOutbox({Directory? root}) : _root = root;

  static final SurveyOutbox instance = SurveyOutbox();

  List<OutboxItem> get pending => List.unmodifiable(_queue);
  List<OutboxItem> get failed => List.unmodifiable(_failed);
  int get pendingCount => _queue.length;
  bool get isSyncing => _syncing;

  static String newClientId() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String h(int b) => b.toRadixString(16).padLeft(2, '0');
    final s = bytes.map(h).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  static int tempIdFromClient(String clientId) => -clientId.hashCode.abs().clamp(1, 0x7fffffff);

  Future<void> ensureReady() async {
    if (_ready) return;
    _root ??= Directory('${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}iwindoor_outbox');
    if (!await _root!.exists()) await _root!.create(recursive: true);
    final f = File('${_root!.path}${Platform.pathSeparator}queue.json');
    if (await f.exists()) {
      try {
        final map = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
        _queue
          ..clear()
          ..addAll([for (final e in (map['queue'] as List? ?? const [])) OutboxItem.fromJson(Map<String, dynamic>.from(e as Map))]);
        _failed
          ..clear()
          ..addAll([for (final e in (map['failed'] as List? ?? const [])) OutboxItem.fromJson(Map<String, dynamic>.from(e as Map))]);
      } catch (_) {}
    }
    _ready = true;
    ConnectivityState.instance.setPendingOutbox(_queue.length);
  }

  Future<void> _persist() async {
    await ensureReady();
    final f = File('${_root!.path}${Platform.pathSeparator}queue.json');
    await f.writeAsString(
      jsonEncode({
        'queue': [for (final e in _queue) e.toJson()],
        'failed': [for (final e in _failed) e.toJson()],
      }),
      flush: true,
    );
    ConnectivityState.instance.setPendingOutbox(_queue.length);
  }

  Future<OutboxItem> enqueueCreate(int projectId, SurveyItem draft, {required String clientId}) async {
    await ensureReady();
    final item = OutboxItem(
      id: newClientId(),
      type: OutboxOpType.createItem,
      clientId: clientId,
      projectId: projectId,
      payload: {
        ...draft.toJson(),
        'id': draft.id,
        'clientId': clientId,
        'suggestedWidthMm': draft.suggestedWidthMm,
        'suggestedHeightMm': draft.suggestedHeightMm,
      },
    );
    _queue.add(item);
    await _persist();
    return item;
  }

  Future<OutboxItem> enqueueUpdate(int projectId, SurveyItem item, {required String clientId}) async {
    await ensureReady();
    final op = OutboxItem(
      id: newClientId(),
      type: OutboxOpType.updateItem,
      clientId: clientId,
      serverItemId: item.id > 0 ? item.id : null,
      projectId: projectId,
      payload: {
        ...item.toJson(),
        'id': item.id,
        'clientId': clientId,
        'suggestedWidthMm': item.suggestedWidthMm,
        'suggestedHeightMm': item.suggestedHeightMm,
      },
    );
    _queue.add(op);
    await _persist();
    return op;
  }

  Future<OutboxItem> enqueueDelete(int projectId, {required String clientId, int? serverItemId}) async {
    await ensureReady();
    final op = OutboxItem(
      id: newClientId(),
      type: OutboxOpType.deleteItem,
      clientId: clientId,
      serverItemId: serverItemId,
      projectId: projectId,
    );
    _queue.add(op);
    await _persist();
    return op;
  }

  Future<OutboxItem> enqueuePhoto(int projectId, {required String clientId, required List<int> bytes, int? serverItemId}) async {
    await ensureReady();
    final photos = Directory('${_root!.path}${Platform.pathSeparator}photos');
    if (!await photos.exists()) await photos.create(recursive: true);
    final name = '${clientId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final path = '${photos.path}${Platform.pathSeparator}$name';
    await File(path).writeAsBytes(bytes, flush: true);
    final op = OutboxItem(
      id: newClientId(),
      type: OutboxOpType.uploadPhoto,
      clientId: clientId,
      serverItemId: serverItemId,
      projectId: projectId,
      photoPath: path,
    );
    _queue.add(op);
    await _persist();
    return op;
  }

  void remapTempId(String clientId, int realId) {
    for (final e in _queue) {
      if (e.clientId == clientId) e.serverItemId = realId;
    }
  }

  Future<void> discardFailed(String id) async {
    await ensureReady();
    _failed.removeWhere((e) => e.id == id);
    await _persist();
  }

  Future<void> retryFailed(String id) async {
    await ensureReady();
    final i = _failed.indexWhere((e) => e.id == id);
    if (i < 0) return;
    final item = _failed.removeAt(i);
    item.status = OutboxItemStatus.pending;
    item.errorMessage = null;
    _queue.insert(0, item);
    await _persist();
  }

  /// Sunucu listesi + kuyruk birleşimi.
  List<SurveyItem> mergeView(List<SurveyItem> server, int projectId) {
    final byClient = <String, SurveyItem>{};
    final result = <SurveyItem>[];
    final deletedClients = <String>{};
    final deletedServerIds = <int>{};

    for (final op in _queue.where((e) => e.projectId == projectId)) {
      if (op.type == OutboxOpType.deleteItem) {
        deletedClients.add(op.clientId);
        if (op.serverItemId != null) deletedServerIds.add(op.serverItemId!);
      }
    }

    for (final s in server) {
      if (deletedServerIds.contains(s.id)) continue;
      result.add(s);
    }

    for (final op in _queue.where((e) => e.projectId == projectId && e.type == OutboxOpType.createItem)) {
      if (deletedClients.contains(op.clientId)) continue;
      final p = op.payload ?? {};
      final tempId = tempIdFromClient(op.clientId);
      byClient[op.clientId] = SurveyItem(
        id: tempId,
        room: p['room'] as String? ?? '',
        productType: surveyProductFromApi(p['productType']),
        openingWidthMm: (p['openingWidthMm'] as num?)?.toDouble() ?? 0,
        openingHeightMm: (p['openingHeightMm'] as num?)?.toDouble() ?? 0,
        suggestedWidthMm: (p['openingWidthMm'] as num?)?.toDouble() ?? 0,
        suggestedHeightMm: (p['openingHeightMm'] as num?)?.toDouble() ?? 0,
        quantity: (p['quantity'] as num?)?.toInt() ?? 1,
        note: p['note'] as String?,
      );
    }

    for (final op in _queue.where((e) => e.projectId == projectId && e.type == OutboxOpType.updateItem)) {
      final p = op.payload ?? {};
      final id = op.serverItemId ?? tempIdFromClient(op.clientId);
      final idx = result.indexWhere((e) => e.id == id);
      final updated = SurveyItem(
        id: id,
        room: p['room'] as String? ?? '',
        productType: surveyProductFromApi(p['productType']),
        openingWidthMm: (p['openingWidthMm'] as num?)?.toDouble() ?? 0,
        openingHeightMm: (p['openingHeightMm'] as num?)?.toDouble() ?? 0,
        suggestedWidthMm: (p['openingWidthMm'] as num?)?.toDouble() ?? 0,
        suggestedHeightMm: (p['openingHeightMm'] as num?)?.toDouble() ?? 0,
        quantity: (p['quantity'] as num?)?.toInt() ?? 1,
        note: p['note'] as String?,
      );
      if (idx >= 0) {
        result[idx] = updated;
      } else {
        byClient[op.clientId] = updated;
      }
    }

    result.addAll(byClient.values);
    return result;
  }

  bool isPendingClient(String clientId) => _queue.any((e) => e.clientId == clientId);
  bool isPendingTempId(int id) => id < 0 || _queue.any((e) => tempIdFromClient(e.clientId) == id);

  Future<void> sync(SurveyApi api) async {
    if (_syncing) return;
    await ensureReady();
    _syncing = true;
    try {
      while (_queue.isNotEmpty) {
        final op = _queue.first;
        try {
          switch (op.type) {
            case OutboxOpType.createItem:
              final draft = SurveyItem.fromJson({
                ...op.payload!,
                'id': op.payload!['id'] ?? 0,
              });
              final created = await api.create(op.projectId, draft, clientId: op.clientId);
              remapTempId(op.clientId, created.id);
              for (final e in _queue) {
                if (e.clientId == op.clientId) e.serverItemId = created.id;
              }
            case OutboxOpType.updateItem:
              final id = op.serverItemId;
              if (id == null) throw StateError('Güncelleme için sunucu id yok');
              await api.update(op.projectId, id, SurveyItem.fromJson(op.payload!));
            case OutboxOpType.deleteItem:
              final id = op.serverItemId;
              if (id != null) await api.delete(op.projectId, id);
            case OutboxOpType.uploadPhoto:
              final id = op.serverItemId;
              if (id == null) throw StateError('Fotoğraf için sunucu id yok');
              final bytes = await File(op.photoPath!).readAsBytes();
              await api.uploadPhoto(op.projectId, id, bytes, clientId: op.clientId);
          }
          _queue.removeAt(0);
          await _persist();
        } on DioException catch (e) {
          if (e.response != null && (e.response!.statusCode ?? 0) >= 400 && (e.response!.statusCode ?? 0) < 500) {
            op.status = OutboxItemStatus.failed;
            op.errorMessage = e.message ?? 'HTTP ${e.response?.statusCode}';
            _queue.removeAt(0);
            _failed.add(op);
            await _persist();
            continue;
          }
          // Ağ hatası → dur
          break;
        } catch (e) {
          op.status = OutboxItemStatus.failed;
          op.errorMessage = '$e';
          _queue.removeAt(0);
          _failed.add(op);
          await _persist();
        }
      }
    } finally {
      _syncing = false;
      ConnectivityState.instance.setPendingOutbox(_queue.length);
    }
  }
}
