import 'package:windoor_core/windoor_core.dart';

import '../models/catalog.dart';
import '../services/design_api.dart';

/// Yerleşik şablon adıyla pencere oluşturur.
Future<WindowDoc> createWindowFromTemplateName({
  required DesignApi api,
  required int projectId,
  required String templateName,
  required double width,
  required double height,
  required String name,
  int quantity = 1,
  CatalogSnapshot? catalog,
  int? seriesId,
}) async {
  final cat = catalog ?? CatalogSnapshot.fallback;
  DesignTemplate? t;
  for (final x in builtInTemplates()) {
    if (x.name == templateName) {
      t = x;
      break;
    }
  }
  if (t == null) throw StateError('Şablon bulunamadı: $templateName');
  final active = cat.series.where((s) => s.id != 0).toList();
  final sid = seriesId ?? (active.isNotEmpty ? active.first.id : null);
  final design = DesignOps.fillMissingCodes(
    t.build(width, height, sid?.toString() ?? ''),
    glass: cat.defaultGlassCode,
    panel: cat.defaultPanelCode,
  );
  return api.createWindow(
    projectId: projectId,
    name: name,
    seriesId: sid,
    quantity: quantity,
    design: design.copyWith(seriesId: sid?.toString() ?? design.seriesId),
  );
}
