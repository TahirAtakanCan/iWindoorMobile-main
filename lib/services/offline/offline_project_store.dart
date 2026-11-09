import 'package:shared_preferences/shared_preferences.dart';

import '../api_service.dart';
import '../company_api.dart';
import '../customer_api.dart';
import '../design_api.dart';
import '../survey_api.dart';
import '../version_api.dart';

/// İndirilen (çevrimdışı kullanılabilir) proje listesi.
class OfflineProjectStore {
  static const _key = 'offline_project_ids';

  static Future<Set<int>> ids() async {
    final prefs = await SharedPreferences.getInstance();
    return {for (final e in prefs.getStringList(_key) ?? const []) int.tryParse(e)}.whereType<int>().toSet();
  }

  static Future<bool> contains(int id) async => (await ids()).contains(id);

  static Future<void> add(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await ids()..add(id);
    await prefs.setStringList(_key, [for (final i in set) '$i']);
  }

  static Future<void> remove(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final set = await ids()..remove(id);
    await prefs.setStringList(_key, [for (final i in set) '$i']);
  }

  /// Proje + ilişkili okuma uçlarını sırayla indirir (önbelleğe yazar).
  static Future<void> downloadAll(
    int projectId, {
    void Function(String step, double progress)? onProgress,
  }) async {
    final api = ApiService();
    final design = DesignApi();
    final company = CompanyApi();
    final customer = CustomerApi();
    final versions = VersionApi();
    final survey = SurveyApi();

    final steps = <Future<void> Function()>[
      () async {
        onProgress?.call('Firma', 0.05);
        await company.getCompany();
      },
      () async {
        onProgress?.call('Katalog', 0.1);
        await design.catalog();
      },
      () async {
        onProgress?.call('Proje', 0.2);
        final p = await api.getProject(projectId);
        if (p?.customerId != null) {
          onProgress?.call('Müşteri', 0.25);
          try {
            await customer.getCustomer(p!.customerId!);
          } catch (_) {}
        }
      },
      () async {
        onProgress?.call('Teklif', 0.35);
        try {
          await company.getProjectQuote(projectId);
        } catch (_) {}
      },
      () async {
        onProgress?.call('Tahsilat', 0.45);
        try {
          await customer.listPayments(projectId);
        } catch (_) {}
      },
      () async {
        onProgress?.call('Geçmiş', 0.55);
        try {
          await customer.statusHistory(projectId);
        } catch (_) {}
      },
      () async {
        onProgress?.call('Sürümler', 0.65);
        try {
          final list = await versions.list(projectId);
          for (final v in list) {
            try {
              await versions.get(projectId, v.id);
            } catch (_) {}
          }
        } catch (_) {}
      },
      () async {
        onProgress?.call('Keşif', 0.8);
        try {
          final items = await survey.list(projectId);
          for (final it in items) {
            for (final ph in it.photos) {
              try {
                await survey.getPhotoBytes(ph.id);
              } catch (_) {}
            }
          }
        } catch (_) {}
      },
      () async {
        onProgress?.call('Pencereler', 0.9);
        final p = await api.getProject(projectId);
        if (p != null) {
          for (final w in p.windowUnits) {
            try {
              await design.getWindow(w.id);
            } catch (_) {}
          }
        }
      },
    ];

    for (var i = 0; i < steps.length; i++) {
      await steps[i]();
      onProgress?.call('İlerleme', (i + 1) / steps.length);
    }
    await add(projectId);
    onProgress?.call('Tamam', 1);
  }
}
