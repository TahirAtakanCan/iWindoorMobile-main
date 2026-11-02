import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/project_specs.dart';

class ProjectSpecsScreen extends StatefulWidget {
  final int projectId;
  const ProjectSpecsScreen({super.key, required this.projectId});

  @override
  State<ProjectSpecsScreen> createState() => _ProjectSpecsScreenState();
}

class _ProjectSpecsScreenState extends State<ProjectSpecsScreen> {
  final ApiService _apiService = ApiService();
  late Future<ProjectSpecs?> _specsFuture;

  @override
  void initState() {
    super.initState();
    _specsFuture = _apiService.getProjectSpecs(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Teknik Özellikler (MEO5)")),
      body: FutureBuilder<ProjectSpecs?>(
        future: _specsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("Veri alınamadı."));
          }

          final specs = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildHeaderCard(specs),
              const SizedBox(height: 20),
              _buildSectionTitle("Kullanılan Profil Serileri"),
              _buildListCard(specs.usedProfileTypes, Icons.view_week),
              const SizedBox(height: 20),
              _buildSectionTitle("Kullanılan Cam Tipleri"),
              _buildListCard(specs.usedGlassTypes, Icons.grid_view),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(ProjectSpecs specs) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(specs.projectName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(Icons.window, "${specs.totalWindowCount}", "Pencere"),
                _buildStatItem(Icons.square_foot, "${specs.totalAreaM2} m²", "Toplam Alan"),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, size: 30, color: Colors.blueGrey),
        const SizedBox(height: 5),
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
    );
  }

  Widget _buildListCard(List<String> items, IconData icon) {
    if (items.isEmpty) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: Text("Veri yok.")));
    }
    return Card(
      elevation: 2,
      child: Column(
        children: items.map((item) => ListTile(
          leading: Icon(icon, color: Colors.orangeAccent),
          title: Text(item),
        )).toList(),
      ),
    );
  }
}