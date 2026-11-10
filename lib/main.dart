import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/offline/connectivity_state.dart';
import 'services/offline/survey_outbox.dart';
import 'config/app_config.dart';
import 'widgets/offline_banner.dart';
import 'theme/app_theme.dart';
import 'widgets/brand_logo.dart';

/// Pencere hemen açılır (Windows'ta pencere ilk kare çizilince görünür).
/// Ayarlar ve oturum durumu açılış ekranında okunur; hata olursa ekranda yazılır.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Brand.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) {
        return Column(
          children: [
            const OfflineBanner(),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
      home: const _Bootstrap(),
    );
  }
}

class _Bootstrap extends StatefulWidget {
  const _Bootstrap();

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> {
  bool _loading = true;
  bool _loggedIn = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final errors = <String>[];
    try {
      await AppConfig.load().timeout(const Duration(seconds: 5));
    } catch (e) {
      errors.add('Ayarlar okunamadı: $e');
    }
    try {
      ConnectivityState.instance.attachLifecycle();
      await SurveyOutbox.instance.ensureReady();
      ConnectivityState.instance.setPendingOutbox(SurveyOutbox.instance.pendingCount);
    } catch (_) {}
    try {
      _loggedIn = await AuthService().isLoggedIn().timeout(const Duration(seconds: 5));
    } catch (e) {
      errors.add('Oturum bilgisi okunamadı: $e');
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = errors.isEmpty ? null : errors.join('\n');
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            BrandLogo(size: 96, direction: Axis.vertical, showTagline: true),
            SizedBox(height: 28),
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
          ]),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber, size: 48),
              const SizedBox(height: 12),
              SelectableText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              Wrap(spacing: 12, children: [
                OutlinedButton(onPressed: _init, child: const Text('Tekrar dene')),
                FilledButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Varsayılanlarla devam et'),
                ),
              ]),
            ]),
          ),
        ),
      );
    }
    return _loggedIn ? const HomeScreen() : const LoginScreen();
  }
}
