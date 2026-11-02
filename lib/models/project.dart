import 'window_unit.dart';

class Project {
  final int id;
  final String name;
  final String description;
  final double totalPrice; // <--- YENİ EKLENEN ALAN
  final List<WindowUnit> windowUnits;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.totalPrice, // <--- Constructor'a eklendi
    required this.windowUnits,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    var list = json['windowUnits'] as List? ?? [];
    List<WindowUnit> unitsList = list.map((i) => WindowUnit.fromJson(i)).toList();

    return Project(
      id: json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      // Backend'den bazen int (0), bazen double (10.5) gelebilir.
      // 'num' ikisini de kapsar. Null gelirse 0.0 yap diyoruz.
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0, 
      windowUnits: unitsList,
    );
  }
}