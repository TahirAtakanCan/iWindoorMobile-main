import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';

import '../../config/app_config.dart';
import 'offline_interceptor.dart';

/// Çevrimiçi/çevrimdışı durumu + periyodik yoklama.
class ConnectivityState extends ChangeNotifier with WidgetsBindingObserver {
  bool _online = true;
  DateTime? _lastOnlineAt;
  int _pendingOutbox = 0;
  Timer? _timer;
  bool _observing = false;

  bool get isOnline => _online;
  bool get isOffline => !_online;
  DateTime? get lastOnlineAt => _lastOnlineAt;
  int get pendingOutboxCount => _pendingOutbox;

  static final ConnectivityState instance = ConnectivityState._();
  ConnectivityState._();

  /// Test için.
  ConnectivityState.forTest();

  void attachLifecycle() {
    if (_observing) return;
    WidgetsBinding.instance.addObserver(this);
    _observing = true;
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) {
      if (isOffline) probe();
    });
  }

  void detachLifecycle() {
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    _timer?.cancel();
    _timer = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) probe();
  }

  void markOnline() {
    final was = _online;
    _online = true;
    _lastOnlineAt = DateTime.now();
    if (!was) notifyListeners();
  }

  void markOffline() {
    if (_online) {
      _online = false;
      notifyListeners();
    }
  }

  void setPendingOutbox(int n) {
    if (_pendingOutbox == n) return;
    _pendingOutbox = n;
    notifyListeners();
  }

  Future<bool> probe() async {
    try {
      final dio = Dio(BaseOptions(
        baseUrl: AppConfig.apiUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ));
      await dio.get('/company');
      markOnline();
      return true;
    } on DioException catch (e) {
      if (OfflineInterceptor.isConnectivityError(e)) {
        markOffline();
        return false;
      }
      // HTTP cevabı geldiyse bağlantı var
      markOnline();
      return true;
    } catch (_) {
      markOffline();
      return false;
    }
  }
}
