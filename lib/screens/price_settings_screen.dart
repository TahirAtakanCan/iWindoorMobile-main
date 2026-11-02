import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/profile.dart';

class PriceSettingsScreen extends StatefulWidget {
  const PriceSettingsScreen({super.key});

  @override
  State<PriceSettingsScreen> createState() => _PriceSettingsScreenState();
}

class _PriceSettingsScreenState extends State<PriceSettingsScreen> with SingleTickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  late TabController _tabController;
  
  late Future<List<Profile>> _profilesFuture;
  late Future<List<Glass>> _glassesFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshList();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshList() {
    setState(() {
      _profilesFuture = _apiService.getAllProfilesForConfig();
      _glassesFuture = _apiService.getAllGlasses();
    });
  }

  // Profil Fiyat Düzenleme
  void _showEditProfileDialog(Profile profile) {
    final priceController = TextEditingController(text: profile.pricePerMeter.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${profile.name} Fiyatı"),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Birim Fiyat (TL/m)",
            suffixText: "TL",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              double? newPrice = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (newPrice == null) return;

              Navigator.pop(context);
              
              bool success = await _apiService.updateProfilePrice(profile.id, newPrice);
              if (success) {
                _refreshList();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fiyat güncellendi!")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu!")));
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // Cam Fiyat Düzenleme
  void _showEditGlassDialog(Glass glass) {
    final priceController = TextEditingController(text: glass.pricePerSquareMeter.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${glass.name} Fiyatı"),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: "Birim Fiyat (TL/m²)",
            suffixText: "TL",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              double? newPrice = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (newPrice == null) return;

              Navigator.pop(context);
              
              bool success = await _apiService.updateGlassPrice(glass.id, newPrice);
              if (success) {
                _refreshList();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cam fiyatı güncellendi!")));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hata oluştu!")));
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // Profil Listesi Widget'ı
  Widget _buildProfileList() {
    return FutureBuilder<List<Profile>>(
      future: _profilesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Listelenecek profil bulunamadı."));
        }

        final profiles = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: profiles.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            final profile = profiles[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade50,
                child: Icon(Icons.inventory_2, color: Colors.blue.shade800),
              ),
              title: Text(profile.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Kod: PR-${profile.id}"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200)
                ),
                child: Text(
                  "${profile.pricePerMeter} TL/m",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
              onTap: () => _showEditProfileDialog(profile),
            );
          },
        );
      },
    );
  }

  // Cam Listesi Widget'ı
  Widget _buildGlassList() {
    return FutureBuilder<List<Glass>>(
      future: _glassesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("Listelenecek cam bulunamadı."));
        }

        final glasses = snapshot.data!;

        return ListView.separated(
          padding: const EdgeInsets.all(10),
          itemCount: glasses.length,
          separatorBuilder: (c, i) => const Divider(),
          itemBuilder: (context, index) {
            final glass = glasses[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.cyan.shade50,
                child: Icon(Icons.grid_on, color: Colors.cyan.shade800),
              ),
              title: Text(glass.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Kod: GL-${glass.id}"),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade200)
                ),
                child: Text(
                  "${glass.pricePerSquareMeter} TL/m²",
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800),
                ),
              ),
              onTap: () => _showEditGlassDialog(glass),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Birim Fiyat Ayarları"),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.window), text: "Profiller"),
            Tab(icon: Icon(Icons.grid_on), text: "Camlar"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileList(),
          _buildGlassList(),
        ],
      ),
    );
  }
}