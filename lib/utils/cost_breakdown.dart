import '../models/company.dart';
import '../models/project_quote.dart';

/// Pencere maliyeti satırı: backend boşsa SalesPricer formülüyle doldurur.
CostWindowRow enrichCostWindowRow(
  QuoteWindow w,
  CompanyProfile company, {
  CostWindowRow? fromServer,
}) {
  final material = fromServer?.material ?? ((w.materialUnitPrice ?? 0) * w.quantity);
  final sale = fromServer?.sale ?? w.lineTotal;
  var labor = fromServer?.labor ?? 0;
  var install = fromServer?.install ?? 0;

  if (labor == 0 && install == 0) {
    final areaRaw = (w.width / 1000) * (w.height / 1000);
    final area = areaRaw < company.minBillableAreaM2 ? company.minBillableAreaM2 : areaRaw;
    labor = area * company.laborPerM2 * w.quantity;
    install = area * company.installPerM2 * w.quantity;
  }

  final profit = sale - material - labor - install;
  return CostWindowRow(
    windowId: w.windowId,
    name: fromServer?.name ?? w.name,
    material: material,
    labor: labor,
    install: install,
    sale: sale,
    profit: profit,
  );
}

/// Özet + pencere satırlarını tamamlar; brüt kâr % = kâr / satış × 100.
CostSummary enrichCostSummary(ProjectQuote q) {
  final raw = q.costSummary;
  if (raw == null) {
    throw StateError('costSummary yok');
  }
  final byId = {for (final r in raw.windows) r.windowId: r};
  final rows = [
    for (final w in q.windows) enrichCostWindowRow(w, q.company, fromServer: byId[w.windowId]),
  ];

  final material = raw.materialTotal != 0 ? raw.materialTotal : rows.fold<double>(0, (a, r) => a + r.material);
  final labor = raw.laborTotal != 0 ? raw.laborTotal : rows.fold<double>(0, (a, r) => a + r.labor);
  final install = raw.installTotal != 0 ? raw.installTotal : rows.fold<double>(0, (a, r) => a + r.install);
  final sale = raw.saleSubtotal != 0 ? raw.saleSubtotal : rows.fold<double>(0, (a, r) => a + r.sale);
  final profit = sale - material - labor - install;
  final pct = sale <= 0 ? 0.0 : profit / sale * 100;

  return CostSummary(
    materialTotal: material,
    laborTotal: labor,
    installTotal: install,
    saleSubtotal: sale,
    grossProfit: profit,
    grossProfitPct: pct,
    windows: rows,
  );
}

String formatProfitPct(double pct) {
  final s = pct.toStringAsFixed(2).replaceAll('.', ',');
  return '%$s';
}
