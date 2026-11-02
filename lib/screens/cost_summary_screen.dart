import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/cost_summary.dart';

class CostSummaryScreen extends StatefulWidget {
  final int projectId;
  const CostSummaryScreen({super.key, required this.projectId});

  @override
  State<CostSummaryScreen> createState() => _CostSummaryScreenState();
}

class _CostSummaryScreenState extends State<CostSummaryScreen> {
  final ApiService _apiService = ApiService();
  late Future<ProjectCostSummary?> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _apiService.getCostSummary(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Maliyet Analizi (MEO4)")),
      body: FutureBuilder<ProjectCostSummary?>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Veri alınamadı."));
          }

          final summary = snapshot.data!;
          
          // Verileri Kategoriye Göre Grupla
          Map<String, List<CostItem>> groupedItems = {};
          for (var item in summary.items) {
            if (!groupedItems.containsKey(item.category)) {
              groupedItems[item.category] = [];
            }
            groupedItems[item.category]!.add(item);
          }

          return Column(
            children: [
              // 1. LİSTE (Detaylar)
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(10),
                  children: groupedItems.entries.map((entry) {
                    return _buildCategoryCard(entry.key, entry.value);
                  }).toList(),
                ),
              ),

              // 2. ALT TOPLAM ÇUBUĞU
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade900,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, offset: const Offset(0, -2))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("GENEL TOPLAM:", style: TextStyle(color: Colors.white70, fontSize: 16)),
                    Text(
                      "${summary.totalCost.toStringAsFixed(2)} TL",
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCategoryCard(String category, List<CostItem> items) {
    double categoryTotal = items.fold(0, (sum, item) => sum + item.price);

    return Card(
      margin: const EdgeInsets.only(bottom: 15),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Başlık
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(category.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Text("${categoryTotal.toStringAsFixed(2)} TL", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              ],
            ),
          ),
          const Divider(height: 1),
          // Kalemler
          ...items.map((item) => ListTile(
            dense: true,
            title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text("${item.quantity.toStringAsFixed(2)} ${item.unit}"),
            trailing: Text("${item.price.toStringAsFixed(2)} TL"),
          )),
        ],
      ),
    );
  }
}