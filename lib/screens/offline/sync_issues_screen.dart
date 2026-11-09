import 'package:flutter/material.dart';

import '../../services/offline/survey_outbox.dart';
import '../../services/survey_api.dart';

class SyncIssuesScreen extends StatefulWidget {
  const SyncIssuesScreen({super.key});

  @override
  State<SyncIssuesScreen> createState() => _SyncIssuesScreenState();
}

class _SyncIssuesScreenState extends State<SyncIssuesScreen> {
  @override
  void initState() {
    super.initState();
    SurveyOutbox.instance.ensureReady().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final failed = SurveyOutbox.instance.failed;
    return Scaffold(
      appBar: AppBar(title: const Text('Eşitleme sorunları')),
      body: failed.isEmpty
          ? const Center(child: Text('Sorunlu kayıt yok.'))
          : ListView.separated(
              itemCount: failed.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e = failed[i];
                return ListTile(
                  title: Text('${e.type.name} · ${e.clientId}'),
                  subtitle: Text(e.errorMessage ?? 'Hata'),
                  trailing: Wrap(children: [
                    TextButton(
                      onPressed: () async {
                        await SurveyOutbox.instance.retryFailed(e.id);
                        await SurveyOutbox.instance.sync(SurveyApi());
                        if (mounted) setState(() {});
                      },
                      child: const Text('Tekrar dene'),
                    ),
                    TextButton(
                      onPressed: () async {
                        await SurveyOutbox.instance.discardFailed(e.id);
                        if (mounted) setState(() {});
                      },
                      child: const Text('Vazgeç'),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
