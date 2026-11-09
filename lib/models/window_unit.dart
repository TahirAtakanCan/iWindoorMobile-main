import 'package:windoor_core/windoor_core.dart';
import 'window_node.dart';

class WindowUnit {
  final int id;
  final String name;
  final double width;
  final double height;
  final int quantity;
  final int? seriesId;
  final double? unitPrice;
  final double? saleUnitPrice;
  final bool priceOverridden;

  /// Eski düğüm ağacı (eski editör). Yeni pencerelerde de sunucu üretir.
  final WindowNode? rootNode;

  /// Tasarım belgesi (yeni editör). null ise pencere henüz eski biçimde.
  final Map<String, dynamic>? design;

  /// Ham JSON: eski ağaçtan önizleme üretmek için saklanır.
  final Map<String, dynamic> raw;

  WindowUnit({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.raw,
    this.quantity = 1,
    this.seriesId,
    this.unitPrice,
    this.saleUnitPrice,
    this.priceOverridden = false,
    this.rootNode,
    this.design,
  });

  double? get displaySaleUnit => saleUnitPrice ?? unitPrice;

  /// Önizleme için belge: kayıtlı belge varsa o, yoksa eski ağaçtan dönüştürülmüş hâli.
  WindowDesign get previewDesign {
    try {
      if (design != null) return WindowDesign.fromJson(design!);
      return LegacyConverter.fromUnitJson(raw);
    } catch (_) {
      return WindowDesign.single(width, height);
    }
  }

  factory WindowUnit.fromJson(Map<String, dynamic> json) {
    return WindowUnit(
      id: json['id'],
      name: json['name'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      seriesId: (json['seriesId'] as num?)?.toInt(),
      unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      saleUnitPrice: (json['saleUnitPrice'] as num?)?.toDouble() ?? (json['salePrice'] as num?)?.toDouble(),
      priceOverridden: json['overridden'] as bool? ??
          json['priceOverridden'] as bool? ??
          json['manualPrice'] as bool? ??
          false,
      rootNode: json['rootNode'] != null ? WindowNode.fromJson(json['rootNode']) : null,
      design: json['design'] is Map ? Map<String, dynamic>.from(json['design'] as Map) : null,
      raw: json,
    );
  }
}
