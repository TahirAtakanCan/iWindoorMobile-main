import 'window_unit.dart';

class Project {
  final int id;
  final String name;
  final String description;
  final double totalPrice;
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
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.customerAddress,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    var list = json['windowUnits'] as List? ?? [];
    List<WindowUnit> unitsList = list.map((i) => WindowUnit.fromJson(i)).toList();

    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      windowUnits: unitsList,
      customerName: json['customerName'] as String?,
      customerPhone: json['customerPhone'] as String?,
      customerEmail: json['customerEmail'] as String?,
      customerAddress: json['customerAddress'] as String?,
    );
  }
}
