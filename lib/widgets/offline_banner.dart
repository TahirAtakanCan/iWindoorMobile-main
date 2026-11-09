import 'package:flutter/material.dart';

import '../services/offline/connectivity_state.dart';
import '../services/offline/survey_outbox.dart';
import '../services/survey_api.dart';
import '../screens/offline/sync_issues_screen.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ConnectivityState.instance,
      builder: (context, _) {
        final c = ConnectivityState.instance;
        if (c.isOnline && c.pendingOutboxCount == 0) return const SizedBox.shrink();
        final time = c.lastOnlineAt;
        final hh = time == null ? '—' : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
        final parts = <String>[];
        if (c.isOffline) parts.add('Çevrimdışı · son güncelleme $hh');
        if (c.pendingOutboxCount > 0) parts.add('${c.pendingOutboxCount} kayıt gönderilmeyi bekliyor');
        return Material(
          color: c.isOffline ? Colors.orange.shade800 : Colors.blueGrey.shade700,
          child: SafeArea(
            bottom: false,
            child: InkWell(
              onTap: () async {
                if (c.pendingOutboxCount > 0) {
                  await SurveyOutbox.instance.sync(SurveyApi());
                  if (SurveyOutbox.instance.failed.isNotEmpty && context.mounted) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncIssuesScreen()));
                  }
                } else {
                  await c.probe();
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(c.isOffline ? Icons.cloud_off : Icons.cloud_upload, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(parts.join(' · '), style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                    if (c.pendingOutboxCount > 0)
                      TextButton(
                        onPressed: () async {
                          await SurveyOutbox.instance.sync(SurveyApi());
                          if (SurveyOutbox.instance.failed.isNotEmpty && context.mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SyncIssuesScreen()));
                          }
                        },
                        child: const Text('Şimdi eşitle', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
