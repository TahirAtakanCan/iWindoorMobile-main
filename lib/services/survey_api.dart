import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/survey.dart';
import 'design_api.dart';
import 'offline/api_dio.dart';
import 'offline/offline_exception.dart';
import 'offline/offline_interceptor.dart';
import 'offline/survey_outbox.dart';

class SurveyApi {
  final Dio _dio;
  final SurveyOutbox outbox;

  SurveyApi({Dio? dio, SurveyOutbox? outbox})
      : outbox = outbox ?? SurveyOutbox.instance,
        _dio = dio ??
            createApiDio(
              allowOutboxWrite: (o) {
                final m = o.method.toUpperCase();
                final p = OfflineInterceptor.pathOf(o);
                return m != 'GET' && (p.contains('/survey') || p.contains('/survey-photos'));
              },
            );

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<SurveyItem>> list(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/survey');
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['survey'] as List? ?? const []) : const []);
        final server = [for (final e in list) SurveyItem.fromJson(Map<String, dynamic>.from(e as Map))];
        await outbox.ensureReady();
        return outbox.mergeView(server, projectId);
      });

  Future<SurveyItem> create(int projectId, SurveyItem item, {String? clientId}) async {
    final cid = clientId ?? SurveyOutbox.newClientId();
    try {
      return await _call(() async {
        final r = await _dio.post('/projects/$projectId/survey', data: {
          ...item.toJson(),
          'clientId': cid,
        });
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
    } catch (e) {
      final err = ApiError.from(e);
      if (_isOffline(e)) {
        await outbox.enqueueCreate(projectId, item, clientId: cid);
        final sugW = item.suggestedWidthMm;
        final sugH = item.suggestedHeightMm;
        return SurveyItem(
          id: SurveyOutbox.tempIdFromClient(cid),
          room: item.room,
          productType: item.productType,
          openingWidthMm: item.openingWidthMm,
          openingHeightMm: item.openingHeightMm,
          suggestedWidthMm: sugW,
          suggestedHeightMm: sugH,
          quantity: item.quantity,
          note: item.note,
        );
      }
      throw err;
    }
  }

  Future<SurveyItem> update(int projectId, int itemId, SurveyItem item, {String? clientId}) async {
    final cid = clientId ?? (itemId < 0 ? 'temp-$itemId' : '$itemId');
    try {
      return await _call(() async {
        final r = await _dio.put('/projects/$projectId/survey/$itemId', data: item.toJson());
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
    } catch (e) {
      if (_isOffline(e)) {
        await outbox.enqueueUpdate(projectId, item.copyWithId(itemId), clientId: cid);
        return item.copyWithId(itemId);
      }
      rethrow;
    }
  }

  Future<void> delete(int projectId, int itemId, {String? clientId}) async {
    final cid = clientId ?? (itemId < 0 ? 'temp-$itemId' : '$itemId');
    try {
      await _call(() => _dio.delete('/projects/$projectId/survey/$itemId'));
    } catch (e) {
      if (_isOffline(e)) {
        await outbox.enqueueDelete(projectId, clientId: cid, serverItemId: itemId > 0 ? itemId : null);
        return;
      }
      rethrow;
    }
  }

  Future<SurveyPhoto> uploadPhoto(
    int projectId,
    int itemId,
    Uint8List bytes, {
    String filename = 'photo.jpg',
    String? clientId,
  }) async {
    final cid = clientId ?? SurveyOutbox.newClientId();
    try {
      return await _call(() async {
        final form = FormData.fromMap({
          'file': MultipartFile.fromBytes(bytes, filename: filename),
          'clientId': cid,
        });
        final r = await _dio.post(
          '/projects/$projectId/survey/$itemId/photos',
          data: form,
          options: Options(contentType: 'multipart/form-data'),
        );
        return SurveyPhoto.fromJson(Map<String, dynamic>.from(r.data as Map));
      });
    } catch (e) {
      if (_isOffline(e)) {
        await outbox.enqueuePhoto(projectId, clientId: cid, bytes: bytes, serverItemId: itemId > 0 ? itemId : null);
        return SurveyPhoto(id: -1, url: null);
      }
      rethrow;
    }
  }

  Future<Uint8List> getPhotoBytes(int photoId) => _call(() async {
        final r = await _dio.get<List<int>>(
          '/survey-photos/$photoId',
          options: Options(responseType: ResponseType.bytes),
        );
        return Uint8List.fromList(r.data ?? const []);
      });

  Future<void> deletePhoto(int photoId) => _call(() => _dio.delete('/survey-photos/$photoId'));

  Future<SurveyItem> link(int projectId, int itemId, int windowId) => _call(() async {
        final r = await _dio.put('/projects/$projectId/survey/$itemId/link', data: {'windowId': windowId});
        return SurveyItem.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  bool _isOffline(Object e) {
    if (e is OfflineException) return true;
    if (e is DioException) {
      return e.error is OfflineException || OfflineInterceptor.isConnectivityError(e);
    }
    if (e is ApiError) return e.message.contains('çevrimdışı') || e.message.contains('Çevrimdışı');
    return false;
  }
}

extension on SurveyItem {
  SurveyItem copyWithId(int id) => SurveyItem(
        id: id,
        room: room,
        productType: productType,
        openingWidthMm: openingWidthMm,
        openingHeightMm: openingHeightMm,
        suggestedWidthMm: suggestedWidthMm,
        suggestedHeightMm: suggestedHeightMm,
        quantity: quantity,
        note: note,
        linkedWindowId: linkedWindowId,
        linkedWindowName: linkedWindowName,
        photos: photos,
      );
}
