import 'window_unit.dart';

class Project {
  final int id;
  final String name;
  final String description;
  final double totalPrice;
  /// Satış ara toplamı (KDV hariç). Yoksa [totalPrice] kullanılır.
  final double? saleTotal;
  final List<WindowUnit> windowUnits;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? customerAddress;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.totalPrice,
    required this.windowUnits,
    this.saleTotal,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
  });

  double get displaySaleTotal => saleTotal ?? totalPrice;

  factory Project.fromJson(Map<String, dynamic> json) {
    var list = json['windowUnits'] as List? ?? [];
    List<WindowUnit> unitsList = list.map((i) => WindowUnit.fromJson(i)).toList();

    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      saleTotal: (json['saleTotal'] as num?)?.toDouble() ?? (json['salesTotal'] as num?)?.toDouble(),
      windowUnits: unitsList,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerAddress: json['customerAddress'] as String?,
    );
  }
}
