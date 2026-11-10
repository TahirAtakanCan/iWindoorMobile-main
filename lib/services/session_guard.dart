import 'package:flutter/material.dart';

import '../screens/login_screen.dart';
import 'auth_service.dart';

/// Oturum süresi dolduğunda (sunucu 401 döndüğünde) kullanıcıyı giriş ekranına götürür.
class SessionGuard {
  SessionGuard._();

  /// MaterialApp.navigatorKey olarak verilir.
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static bool _handling = false;

  static Future<void> onUnauthorized() async {
    if (_handling) return; // aynı anda gelen birden çok 401 için tek yönlendirme
    _handling = true;
    try {
      await AuthService().logout();
      final nav = navigatorKey.currentState;
      if (nav == null) return;
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
      final ctx = navigatorKey.currentContext;
      if (ctx != null && ctx.mounted) {
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          const SnackBar(content: Text('Oturum süresi doldu. Lütfen tekrar giriş yapın.')),
        );
      }
    } finally {
      // Giriş ekranı açıldıktan sonra yeni 401'ler yeniden ele alınabilsin.
      Future.delayed(const Duration(seconds: 2), () => _handling = false);
    }
  }
}
