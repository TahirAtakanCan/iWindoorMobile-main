import 'package:windoor_core/windoor_core.dart';

import '../services/design_api.dart';
import 'company.dart';

class QuoteProjectInfo {
  final int id;
  final String name;
  final String? description;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;

  const QuoteProjectInfo({
    required this.id,
    required this.name,
    this.description,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
  });

  factory QuoteProjectInfo.fromJson(Map<String, dynamic> j) => QuoteProjectInfo(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        customerName: j['customerName'] as String?,
        customerPhone: j['customerPhone'] as String?,
        customerEmail: j['customerEmail'] as String?,
        customerAddress: j['customerAddress'] as String?,
      );
}

/// Proje ek kalemi (nakliye, söküm…).
class QuoteExtra {
  final int? id;
  final String name;
  final double quantity;
  final String unit;
  final double unitPrice;
  final int sortOrder;

  const QuoteExtra({
    this.id,
    required this.name,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    this.sortOrder = 0,
  });

  double get total => quantity * unitPrice;

  factory QuoteExtra.fromJson(Map<String, dynamic> j) => QuoteExtra(
        id: (j['id'] as num?)?.toInt() ?? (j['itemId'] as num?)?.toInt(),
        name: j['name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toDouble() ?? 1,
        unit: j['unit'] as String? ?? 'adet',
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        sortOrder: (j['sortOrder'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'sortOrder': sortOrder,
      };
}

class CostWindowRow {
  final int windowId;
  final String name;
  final double material;
  final double labor;
  final double install;
  final double sale;
  final double profit;

  const CostWindowRow({
    required this.windowId,
    required this.name,
    required this.material,
    required this.labor,
    required this.install,
    required this.sale,
    required this.profit,
  });

  factory CostWindowRow.fromJson(Map<String, dynamic> j) => CostWindowRow(
        windowId: (j['windowId'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt() ?? 0,
        name: j['name'] as String? ?? '',
        material: (j['material'] as num?)?.toDouble() ?? (j['materialCost'] as num?)?.toDouble() ?? 0,
        labor: (j['labor'] as num?)?.toDouble() ?? (j['laborCost'] as num?)?.toDouble() ?? 0,
        install: (j['install'] as num?)?.toDouble() ?? (j['installation'] as num?)?.toDouble() ?? 0,
        sale: (j['sale'] as num?)?.toDouble() ?? (j['saleTotal'] as num?)?.toDouble() ?? 0,
        profit: (j['profit'] as num?)?.toDouble() ?? (j['grossProfit'] as num?)?.toDouble() ?? 0,
      );
}

/// Yöneticiye özel maliyet özeti (diğer roller için null).
class CostSummary {
  final double materialTotal;
  final double laborTotal;
  final double installTotal;
  final double saleSubtotal;
  final double grossProfit;
  final double grossProfitPct;
  final List<CostWindowRow> windows;

  const CostSummary({
    required this.materialTotal,
    required this.laborTotal,
    required this.installTotal,
    required this.saleSubtotal,
    required this.grossProfit,
    required this.grossProfitPct,
    this.windows = const [],
  });

  factory CostSummary.fromJson(Map<String, dynamic> j) => CostSummary(
        materialTotal: (j['materialTotal'] as num?)?.toDouble() ?? (j['materials'] as num?)?.toDouble() ?? 0,
        laborTotal: (j['laborTotal'] as num?)?.toDouble() ?? (j['labor'] as num?)?.toDouble() ?? 0,
        installTotal: (j['installTotal'] as num?)?.toDouble() ?? (j['installation'] as num?)?.toDouble() ?? 0,
        saleSubtotal: (j['saleSubtotal'] as num?)?.toDouble() ?? (j['salesSubtotal'] as num?)?.toDouble() ?? 0,
        grossProfit: (j['grossProfit'] as num?)?.toDouble() ?? (j['profit'] as num?)?.toDouble() ?? 0,
        grossProfitPct: (j['grossProfitPct'] as num?)?.toDouble() ?? (j['profitPct'] as num?)?.toDouble() ?? 0,
        windows: [
          for (final w in (j['windows'] as List? ?? j['windowCosts'] as List? ?? const []))
            CostWindowRow.fromJson(Map<String, dynamic>.from(w as Map)),
        ],
      );
}

class QuoteWindow {
  final int windowId;
  final String name;
  final int quantity;
  final double width;
  final double height;
  final String? seriesName;
  final WindowDesign design;
  /// Gösterim / satır toplamı için kullanılan satış birim fiyatı.
  final double unitPrice;
  final double lineTotal;
  final double? materialUnitPrice;
  final double? saleUnitPrice;
  final bool overridden;
  final List<QuoteLine> lines;
  final List<String> warnings;

  const QuoteWindow({
    required this.windowId,
    required this.name,
    required this.quantity,
    required this.width,
    required this.height,
    required this.design,
    required this.unitPrice,
    required this.lineTotal,
    this.seriesName,
    this.materialUnitPrice,
    this.saleUnitPrice,
    this.overridden = false,
    this.lines = const [],
    this.warnings = const [],
  });

  /// Satış birim fiyatı (saleUnitPrice yoksa unitPrice).
  double get displaySaleUnit => saleUnitPrice ?? unitPrice;

  factory QuoteWindow.fromJson(Map<String, dynamic> j) {
    final sale = (j['saleUnitPrice'] as num?)?.toDouble();
    final unit = (j['unitPrice'] as num?)?.toDouble() ?? sale ?? 0;
    return QuoteWindow(
      windowId: (j['windowId'] as num).toInt(),
      name: j['name'] as String? ?? '',
      quantity: (j['quantity'] as num?)?.toInt() ?? 1,
      width: (j['width'] as num?)?.toDouble() ?? 0,
      height: (j['height'] as num?)?.toDouble() ?? 0,
      seriesName: j['seriesName'] as String?,
      design: WindowDesign.fromJson(Map<String, dynamic>.from(j['design'] as Map)),
      unitPrice: sale ?? unit,
      lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? 0,
      materialUnitPrice: (j['materialUnitPrice'] as num?)?.toDouble() ?? (j['costUnitPrice'] as num?)?.toDouble(),
      saleUnitPrice: sale ?? (j['unitPrice'] as num?)?.toDouble(),
      overridden: j['overridden'] as bool? ?? j['priceOverridden'] as bool? ?? j['manualPrice'] as bool? ?? false,
      lines: [
        for (final l in (j['lines'] as List? ?? const []))
          QuoteLine.fromJson(Map<String, dynamic>.from(l as Map)),
      ],
      warnings: [for (final w in (j['warnings'] as List? ?? const [])) '$w'],
    );
  }
}

class ProjectQuote {
  final DateTime? generatedAt;
  final DateTime? validUntil;
  final String currency;
  final CompanyProfile company;
  final QuoteProjectInfo project;
  final List<QuoteWindow> windows;
  final List<QuoteLine> materials;
  final List<QuoteExtra> extras;
  final CostSummary? costSummary;
  final double subtotal;
  final double discountPct;
  final double discountAmount;
  final double netTotal;
  final double vatRate;
  final double vatAmount;
  final double grandTotal;

  const ProjectQuote({
    required this.company,
    required this.project,
    required this.windows,
    required this.materials,
    required this.subtotal,
    required this.discountPct,
    required this.discountAmount,
    required this.netTotal,
    required this.vatRate,
    required this.vatAmount,
    required this.grandTotal,
    this.extras = const [],
    this.costSummary,
    this.generatedAt,
    this.validUntil,
    this.currency = 'TRY',
  });

  factory ProjectQuote.fromJson(Map<String, dynamic> j) {
    final net = (j['net'] as num?)?.toDouble() ?? (j['netTotal'] as num?)?.toDouble() ?? 0;
    final vat = (j['vat'] as num?)?.toDouble() ?? (j['vatAmount'] as num?)?.toDouble() ?? 0;
    final disc = (j['discount'] as num?)?.toDouble() ?? (j['discountAmount'] as num?)?.toDouble() ?? 0;
    CostSummary? cost;
    final rawCost = j['costSummary'];
    if (rawCost is Map) {
      cost = CostSummary.fromJson(Map<String, dynamic>.from(rawCost));
    }
    return ProjectQuote(
      generatedAt: DateTime.tryParse('${j['generatedAt']}'),
      validUntil: DateTime.tryParse('${j['validUntil']}'),
      currency: j['currency'] as String? ?? 'TRY',
      company: CompanyProfile.fromJson(Map<String, dynamic>.from(j['company'] as Map)),
      project: QuoteProjectInfo.fromJson(Map<String, dynamic>.from(j['project'] as Map)),
      windows: [
        for (final w in (j['windows'] as List? ?? const []))
          QuoteWindow.fromJson(Map<String, dynamic>.from(w as Map)),
      ],
      materials: [
        for (final m in (j['materials'] as List? ?? const []))
          QuoteLine.fromJson(Map<String, dynamic>.from(m as Map)),
      ],
      extras: [
        for (final e in (j['extras'] as List? ?? const []))
          QuoteExtra.fromJson(Map<String, dynamic>.from(e as Map)),
      ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      costSummary: cost,
      subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
      discountPct: (j['discountPct'] as num?)?.toDouble() ?? 0,
      discountAmount: disc,
      netTotal: net,
      vatRate: (j['vatRate'] as num?)?.toDouble() ?? 0,
      vatAmount: vat,
      grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
    );
  }
}
