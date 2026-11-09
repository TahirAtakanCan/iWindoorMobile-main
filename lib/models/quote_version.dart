import 'package:windoor_core/windoor_core.dart';

import '../utils/version_compare.dart';
import 'project_quote.dart';

class QuoteVersionSummary {
  final int id;
  final int versionNo;
  final String? label;
  final DateTime createdAt;
  final String? createdByName;
  final double grandTotal;
  final int windowCount;
  final bool approved;

  const QuoteVersionSummary({
    required this.id,
    required this.versionNo,
    this.label,
    required this.createdAt,
    this.createdByName,
    this.grandTotal = 0,
    this.windowCount = 0,
    this.approved = false,
  });

  factory QuoteVersionSummary.fromJson(Map<String, dynamic> j) => QuoteVersionSummary(
        id: (j['id'] as num).toInt(),
        versionNo: (j['versionNo'] as num?)?.toInt() ??
            (j['number'] as num?)?.toInt() ??
            (j['version'] as num?)?.toInt() ??
            0,
        label: j['label'] as String? ?? j['name'] as String?,
        createdAt: DateTime.tryParse('${j['createdAt'] ?? j['at'] ?? ''}') ?? DateTime.now(),
        createdByName: j['createdByName'] as String? ?? j['createdBy'] as String? ?? j['byName'] as String?,
        grandTotal: (j['grandTotal'] as num?)?.toDouble() ?? (j['total'] as num?)?.toDouble() ?? 0,
        windowCount: (j['windowCount'] as num?)?.toInt() ?? (j['windowsCount'] as num?)?.toInt() ?? 0,
        approved: j['approved'] as bool? ?? j['isApproved'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) => other is QuoteVersionSummary && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class VersionWindow {
  final int? windowId;
  final String name;
  final double width;
  final double height;
  final int quantity;
  final double unitPrice;
  final double lineTotal;
  final String? seriesName;
  final String? glass;
  final String? color;
  final WindowDesign design;

  const VersionWindow({
    required this.name,
    required this.width,
    required this.height,
    required this.design,
    this.windowId,
    this.quantity = 1,
    this.unitPrice = 0,
    this.lineTotal = 0,
    this.seriesName,
    this.glass,
    this.color,
  });

  factory VersionWindow.fromJson(Map<String, dynamic> j, {Map<String, String> seriesNames = const {}}) {
    final designMap = j['design'] is Map ? Map<String, dynamic>.from(j['design'] as Map) : null;
    final w = (j['width'] as num?)?.toDouble() ?? 0;
    final h = (j['height'] as num?)?.toDouble() ?? 0;
    final design = designMap != null
        ? WindowDesign.fromJson(designMap)
        : WindowDesign.single(w, h, seriesId: j['seriesId']?.toString());
    final qty = (j['quantity'] as num?)?.toInt() ?? 1;
    // Sürüm anlık görüntüsünde unitPrice MALZEME maliyetidir; satış fiyatı saleUnitPrice'tır.
    final unit = (j['saleUnitPrice'] as num?)?.toDouble() ??
        (j['salePriceOverride'] as num?)?.toDouble() ??
        (j['unitPrice'] as num?)?.toDouble() ??
        0;
    final codes = <String>{for (final f in DesignOps.fills(design.root)) f.glassCode}..removeWhere((c) => c.isEmpty);
    final seriesKey = (j['seriesId'] ?? design.seriesId)?.toString();
    return VersionWindow(
      windowId: (j['windowId'] as num?)?.toInt() ?? (j['id'] as num?)?.toInt(),
      name: j['name'] as String? ?? '',
      width: w,
      height: h,
      quantity: qty,
      unitPrice: unit,
      lineTotal: (j['lineTotal'] as num?)?.toDouble() ?? unit * qty,
      seriesName: j['seriesName'] as String? ?? (seriesKey == null ? null : seriesNames[seriesKey]),
      glass: j['glass'] as String? ?? j['glassCode'] as String? ?? (codes.isEmpty ? null : (codes.toList()..sort()).join(', ')),
      color: j['color'] as String? ?? j['colorCode'] as String? ?? design.colorCode,
      design: design,
    );
  }

  VersionWindowSnap toSnap() => VersionWindowSnap(
        name: name,
        width: width,
        height: height,
        quantity: quantity,
        glass: glass,
        color: color,
        unitPrice: unitPrice,
      );
}

class QuoteVersionSnapshot {
  final int id;
  final int versionNo;
  final String? label;
  final DateTime createdAt;
  final String? createdByName;
  final bool approved;
  final List<VersionWindow> windows;
  final List<QuoteExtra> extras;
  final Map<String, String> seriesNames;
  final double subtotal;
  final double discountPct;
  final double discountAmount;
  final double netTotal;
  final double vatRate;
  final double vatAmount;
  final double grandTotal;
  final String currency;
  final Map<String, dynamic>? company;
  final Map<String, dynamic>? project;

  const QuoteVersionSnapshot({
    required this.id,
    required this.versionNo,
    required this.createdAt,
    required this.windows,
    this.label,
    this.createdByName,
    this.approved = false,
    this.extras = const [],
    this.seriesNames = const {},
    this.subtotal = 0,
    this.discountPct = 0,
    this.discountAmount = 0,
    this.netTotal = 0,
    this.vatRate = 20,
    this.vatAmount = 0,
    this.grandTotal = 0,
    this.currency = 'TRY',
    this.company,
    this.project,
  });

  factory QuoteVersionSnapshot.fromJson(Map<String, dynamic> j) {
    final snap = j['snapshot'] is Map ? Map<String, dynamic>.from(j['snapshot'] as Map) : j;
    final seriesRaw = snap['seriesNames'] ?? j['seriesNames'];
    final series = <String, String>{};
    if (seriesRaw is Map) {
      for (final e in seriesRaw.entries) {
        series['${e.key}'] = '${e.value}';
      }
    }
    final q = snap['quote'] is Map ? Map<String, dynamic>.from(snap['quote'] as Map) : snap;
    return QuoteVersionSnapshot(
      id: (j['id'] as num?)?.toInt() ?? (snap['id'] as num?)?.toInt() ?? 0,
      versionNo: (j['versionNo'] as num?)?.toInt() ?? (snap['versionNo'] as num?)?.toInt() ?? 0,
      label: j['label'] as String? ?? snap['label'] as String?,
      createdAt: DateTime.tryParse('${j['createdAt'] ?? snap['createdAt'] ?? ''}') ?? DateTime.now(),
      createdByName: j['createdByName'] as String? ?? snap['createdByName'] as String?,
      approved: j['approved'] as bool? ?? snap['approved'] as bool? ?? false,
      windows: [
        for (final w in (snap['windows'] as List? ?? j['windows'] as List? ?? const []))
          VersionWindow.fromJson(Map<String, dynamic>.from(w as Map), seriesNames: series),
      ],
      extras: [
        for (final e in (snap['extras'] as List? ?? j['extras'] as List? ?? const []))
          QuoteExtra.fromJson(Map<String, dynamic>.from(e as Map)),
      ],
      seriesNames: series,
      subtotal: (q['subtotal'] as num?)?.toDouble() ?? (j['saleSubtotal'] as num?)?.toDouble() ?? 0,
      discountPct: (q['discountPct'] as num?)?.toDouble() ?? 0,
      discountAmount: (q['discountAmount'] as num?)?.toDouble() ?? (q['discount'] as num?)?.toDouble() ?? 0,
      netTotal: (q['netTotal'] as num?)?.toDouble() ?? (q['net'] as num?)?.toDouble() ?? 0,
      vatRate: (q['vatRate'] as num?)?.toDouble() ?? 20,
      vatAmount: (q['vatAmount'] as num?)?.toDouble() ?? (q['vat'] as num?)?.toDouble() ?? 0,
      grandTotal: (q['grandTotal'] as num?)?.toDouble() ?? (j['grandTotal'] as num?)?.toDouble() ?? 0,
      currency: snap['currency'] as String? ?? j['currency'] as String? ?? 'TRY',
      company: snap['company'] is Map ? Map<String, dynamic>.from(snap['company'] as Map) : null,
      project: snap['project'] is Map ? Map<String, dynamic>.from(snap['project'] as Map) : null,
    );
  }
}
