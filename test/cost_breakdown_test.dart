import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/company.dart';
import 'package:iwindoor_mobil/models/project_quote.dart';
import 'package:iwindoor_mobil/utils/cost_breakdown.dart';
import 'package:windoor_core/windoor_core.dart';

void main() {
  test('Kaya örneği brüt kâr % 26,31', () {
    // Satış 50.000; malzeme+işçilik+montaj = 36.845 → kâr 13.155 → %26,31
    const sale = 50000.0;
    const material = 28000.0;
    const labor = 5500.0;
    const install = 3345.0; // 28000+5500+3345 = 36845; 13155/50000 = 0.2631
    final company = const CompanyProfile(name: 'Kaya', laborPerM2: 100, installPerM2: 50, minBillableAreaM2: 1);
    const design = WindowDesign(width: 1000, height: 1000, root: FillNode(id: '1', glassCode: '4+12+4'));
    final q = ProjectQuote(
      company: company,
      project: const QuoteProjectInfo(id: 1, name: 'Kaya'),
      windows: [
        QuoteWindow(
          windowId: 1,
          name: 'P1',
          quantity: 1,
          width: 1000,
          height: 1000,
          design: design,
          unitPrice: sale,
          lineTotal: sale,
          materialUnitPrice: material,
        ),
      ],
      materials: const [],
      subtotal: sale,
      discountPct: 0,
      discountAmount: 0,
      netTotal: sale,
      vatRate: 20,
      vatAmount: sale * 0.2,
      grandTotal: sale * 1.2,
      costSummary: const CostSummary(
        materialTotal: material,
        laborTotal: labor,
        installTotal: install,
        saleSubtotal: sale,
        grossProfit: 0,
        grossProfitPct: 0,
        windows: [
          CostWindowRow(
            windowId: 1,
            name: 'P1',
            material: material,
            labor: labor,
            install: install,
            sale: sale,
            profit: 0,
          ),
        ],
      ),
    );

    final cost = enrichCostSummary(q);
    expect(formatProfitPct(cost.grossProfitPct), '%26,31');
    expect(cost.grossProfit, closeTo(13155, 0.01));
  });

  test('işçilik/montaj boşsa alan×oran ile dolar', () {
    final company = const CompanyProfile(name: 'T', laborPerM2: 200, installPerM2: 100, minBillableAreaM2: 1.5);
    // 1000x1000 mm = 1 m² → min 1.5; qty 2 → labor = 1.5*200*2 = 600, install = 1.5*100*2 = 300
    const design = WindowDesign(width: 1000, height: 1000, root: FillNode(id: '1', glassCode: 'x'));
    final q = ProjectQuote(
      company: company,
      project: const QuoteProjectInfo(id: 1, name: 'T'),
      windows: [
        QuoteWindow(
          windowId: 7,
          name: 'W',
          quantity: 2,
          width: 1000,
          height: 1000,
          design: design,
          unitPrice: 5000,
          lineTotal: 10000,
          materialUnitPrice: 1000,
        ),
      ],
      materials: const [],
      subtotal: 10000,
      discountPct: 0,
      discountAmount: 0,
      netTotal: 10000,
      vatRate: 20,
      vatAmount: 2000,
      grandTotal: 12000,
      costSummary: const CostSummary(
        materialTotal: 0,
        laborTotal: 0,
        installTotal: 0,
        saleSubtotal: 0,
        grossProfit: 0,
        grossProfitPct: 0,
        windows: [],
      ),
    );
    final cost = enrichCostSummary(q);
    expect(cost.windows.single.labor, closeTo(600, 0.01));
    expect(cost.windows.single.install, closeTo(300, 0.01));
    expect(cost.windows.single.material, closeTo(2000, 0.01));
  });
}
