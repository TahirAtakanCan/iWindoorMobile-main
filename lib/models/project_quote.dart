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

class QuoteWindow {
  final int windowId;
  final String name;
  final int quantity;
  final double width;
  final double height;
  final String? seriesName;
  final WindowDesign design;
  final double unitPrice;
  final double lineTotal;
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
    this.lines = const [],
    this.warnings = const [],
  });

  factory QuoteWindow.fromJson(Map<String, dynamic> j) => QuoteWindow(
        windowId: (j['windowId'] as num).toInt(),
        name: j['name'] as String? ?? '',
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        width: (j['width'] as num?)?.toDouble() ?? 0,
        height: (j['height'] as num?)?.toDouble() ?? 0,
        seriesName: j['seriesName'] as String?,
        design: WindowDesign.fromJson(Map<String, dynamic>.from(j['design'] as Map)),
        unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
        lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? 0,
        lines: [
          for (final l in (j['lines'] as List? ?? const []))
            QuoteLine.fromJson(Map<String, dynamic>.from(l as Map)),
        ],
        warnings: [for (final w in (j['warnings'] as List? ?? const [])) '$w'],
      );
}

class ProjectQuote {
  final DateTime? generatedAt;
  final DateTime? validUntil;
  final String currency;
  final CompanyProfile company;
  final QuoteProjectInfo project;
  final List<QuoteWindow> windows;
  final List<QuoteLine> materials;
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
    this.generatedAt,
    this.validUntil,
    this.currency = 'TRY',
  });

  factory ProjectQuote.fromJson(Map<String, dynamic> j) => ProjectQuote(
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
        subtotal: (j['subtotal'] as num?)?.toDouble() ?? 0,
        discountPct: (j['discountPct'] as num?)?.toDouble() ?? 0,
        discountAmount: (j['discountAmount'] as num?)?.toDouble() ?? 0,
        netTotal: (j['netTotal'] as num?)?.toDouble() ?? 0,
        vatRate: (j['vatRate'] as num?)?.toDouble() ?? 0,
        vatAmount: (j['vatAmount'] as num?)?.toDouble() ?? 0,
        grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? 0,
      );
}
