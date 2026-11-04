import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../config/app_config.dart';

/// Sunucu adresi ayarı. Telefonda bilgisayarın yerel IP'si (örn. 192.168.0.37:8080),
/// masaüstünde genelde localhost:8080.
class ServerSettingsDialog extends StatefulWidget {
  const ServerSettingsDialog({super.key});

  static Future<void> show(BuildContext context) =>
      showDialog(context: context, builder: (_) => const ServerSettingsDialog());

  @override
  State<ServerSettingsDialog> createState() => _ServerSettingsDialogState();
}

class _ServerSettingsDialogState extends State<ServerSettingsDialog> {
  late final TextEditingController _ctl = TextEditingController(text: AppConfig.baseUrl);
  String? _status;
  bool _testing = false;

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _status = null;
    });
    final url = _ctl.text.trim().replaceAll(RegExp(r'/+$'), '');
    try {
      // Kimliksiz istek: sunucu ayaktaysa 401 döner (bu da "ulaşıldı" demektir).
      final r = await Dio(BaseOptions(connectTimeout: const Duration(seconds: 5), validateStatus: (_) => true))
          .get('${url.startsWith('http') ? url : 'http://$url'}/api/v1/projects');
      _status = (r.statusCode == 401 || r.statusCode == 200) ? 'Sunucuya ulaşıldı.' : 'Cevap: HTTP ${r.statusCode}';
    } catch (_) {
      _status = 'Ulaşılamadı. Adresi, portu ve aynı ağda olduğunuzu kontrol edin.';
    }
    if (mounted) setState(() => _testing = false);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sunucu adresi'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(
          controller: _ctl,
          decoration: const InputDecoration(
            labelText: 'Adres',
            hintText: 'http://192.168.0.37:8080',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text('Varsayılan: ${AppConfig.defaultUrl}', style: Theme.of(context).textTheme.bodySmall),
        if (_status != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_status!)),
      ]),
      actions: [
        TextButton(onPressed: _testing ? null : _test, child: Text(_testing ? 'Deneniyor…' : 'Bağlantıyı dene')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Vazgeç')),
        FilledButton(
          onPressed: () async {
            await AppConfig.setBaseUrl(_ctl.text);
            if (context.mounted) Navigator.pop(context);
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
