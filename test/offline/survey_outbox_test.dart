import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/survey.dart';
import 'package:iwindoor_mobil/services/offline/survey_outbox.dart';
import 'package:iwindoor_mobil/services/survey_api.dart';
import 'package:iwindoor_mobil/utils/survey_helpers.dart';

class _FakeSurveyApi extends SurveyApi {
  _FakeSurveyApi()
      : super(
          dio: Dio(BaseOptions(baseUrl: 'http://x/api/v1')),
          outbox: SurveyOutbox(root: Directory.systemTemp.createTempSync('fake_ob_')),
        );

  int nextId = 100;
  bool failNetwork = false;
  bool fail4xx = false;
  final creates = <String>[];
  final uploads = <int>[];
  final updates = <int>[];

  @override
  Future<SurveyItem> create(int projectId, SurveyItem item, {String? clientId}) async {
    if (failNetwork) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        type: DioExceptionType.connectionError,
      );
    }
    if (fail4xx) {
      throw DioException(
        requestOptions: RequestOptions(path: '/'),
        response: Response(requestOptions: RequestOptions(path: '/'), statusCode: 400),
      );
    }
    creates.add(clientId ?? '');
    return SurveyItem(
      id: nextId++,
      room: item.room,
      productType: item.productType,
      openingWidthMm: item.openingWidthMm,
      openingHeightMm: item.openingHeightMm,
      suggestedWidthMm: item.suggestedWidthMm,
      suggestedHeightMm: item.suggestedHeightMm,
      quantity: item.quantity,
      note: item.note,
    );
  }

  @override
  Future<SurveyItem> update(int projectId, int itemId, SurveyItem item, {String? clientId}) async {
    updates.add(itemId);
    return SurveyItem(
      id: itemId,
      room: item.room,
      productType: item.productType,
      openingWidthMm: item.openingWidthMm,
      openingHeightMm: item.openingHeightMm,
      suggestedWidthMm: item.suggestedWidthMm,
      suggestedHeightMm: item.suggestedHeightMm,
      quantity: item.quantity,
      note: item.note,
    );
  }

  @override
  Future<void> delete(int projectId, int itemId, {String? clientId}) async {}

  @override
  Future<SurveyPhoto> uploadPhoto(
    int projectId,
    int itemId,
    Uint8List bytes, {
    String filename = 'photo.jpg',
    String? clientId,
  }) async {
    uploads.add(itemId);
    return const SurveyPhoto(id: 1);
  }
}

void main() {
  late Directory tmp;
  late SurveyOutbox outbox;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('iwindoor_outbox_');
    outbox = SurveyOutbox(root: tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('create → photo → update zincirinde geçici id eşlemesi', () async {
    final cid = SurveyOutbox.newClientId();
    await outbox.enqueueCreate(
      1,
      const SurveyItem(
        id: 0,
        room: 'Salon',
        productType: SurveyProductType.window,
        openingWidthMm: 1400,
        openingHeightMm: 1400,
        suggestedWidthMm: 1380,
        suggestedHeightMm: 1380,
      ),
      clientId: cid,
    );
    await outbox.enqueuePhoto(1, clientId: cid, bytes: [1, 2, 3]);
    await outbox.enqueueUpdate(
      1,
      SurveyItem(
        id: SurveyOutbox.tempIdFromClient(cid),
        room: 'Salon 2',
        productType: SurveyProductType.window,
        openingWidthMm: 1400,
        openingHeightMm: 1400,
        suggestedWidthMm: 1380,
        suggestedHeightMm: 1380,
      ),
      clientId: cid,
    );

    final api = _FakeSurveyApi();
    await outbox.sync(api);

    expect(outbox.pending, isEmpty);
    expect(api.creates, isNotEmpty);
    expect(api.uploads, [100]);
    expect(api.updates, [100]);
  });

  test('ağ hatasında kuyruk korunur', () async {
    final cid = SurveyOutbox.newClientId();
    await outbox.enqueueCreate(
      1,
      const SurveyItem(
        id: 0,
        room: 'Mutfak',
        productType: SurveyProductType.window,
        openingWidthMm: 1000,
        openingHeightMm: 1000,
        suggestedWidthMm: 980,
        suggestedHeightMm: 980,
      ),
      clientId: cid,
    );
    final api = _FakeSurveyApi()..failNetwork = true;
    await outbox.sync(api);
    expect(outbox.pending.length, 1);
    expect(outbox.failed, isEmpty);
  });

  test('4xx\'te öğe sorunlulara taşınır', () async {
    final cid = SurveyOutbox.newClientId();
    await outbox.enqueueCreate(
      1,
      const SurveyItem(
        id: 0,
        room: 'Banyo',
        productType: SurveyProductType.window,
        openingWidthMm: 800,
        openingHeightMm: 800,
        suggestedWidthMm: 780,
        suggestedHeightMm: 780,
      ),
      clientId: cid,
    );
    final api = _FakeSurveyApi()..fail4xx = true;
    await outbox.sync(api);
    expect(outbox.pending, isEmpty);
    expect(outbox.failed.length, 1);
  });
}
