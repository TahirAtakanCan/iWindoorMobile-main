class CostItem {
  final String name;
  final String category; // "Profil", "Cam" vb.
  final double quantity;
  final String unit; // "m", "m2"
  final double price;

  CostItem({
    required this.name,
    required this.category,
    required this.quantity,
    required this.unit,
    required this.price,
  });

  factory CostItem.fromJson(Map<String, dynamic> json) {
    return CostItem(
      name: json['name'] ?? '',
      category: json['category'] ?? 'Diğer',
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] ?? '',
      price: (json['price'] as num).toDouble(),
    );
  }
}

class ProjectCostSummary {
  final List<CostItem> items;
  final double totalCost;

  ProjectCostSummary({required this.items, required this.totalCost});

  factory ProjectCostSummary.fromJson(Map<String, dynamic> json) {
    var list = json['items'] as List;
    List<CostItem> itemsList = list.map((i) => CostItem.fromJson(i)).toList();
    return ProjectCostSummary(
      items: itemsList,
      totalCost: (json['totalCost'] as num).toDouble(),
    );
  }
}