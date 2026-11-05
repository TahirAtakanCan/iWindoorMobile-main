import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/design_api.dart';
import '../services/project_file_api.dart';
import '../models/project.dart';
import 'project_detail_screen.dart';
import 'catalog/catalog_screen.dart';
import 'company_settings_screen.dart';
import 'employee_list_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  late Future<List<Project>> _projectsFuture;
  
  // Kullanıcı bilgilerini tutacak değişkenler
  String _userName = "Yükleniyor...";
  String _userEmail = "";

  @override
  void initState() {
    super.initState();
    _refreshProjects();
    _loadUserInfo(); // Ekran açılınca kullanıcı bilgilerini çek
  }

  // Bilgileri servisten (SharedPreferences) al
  void _loadUserInfo() async {
    final info = await AuthService().getUserInfo();
    if (mounted) {
      setState(() {
        _userName = info['name']!;
        _userEmail = info['email']!;
      });
    }
  }

  void _refreshProjects() {
    setState(() {
      _projectsFuture = _apiService.getAllProjects();
    });
  }

  // Yeni Proje Oluşturma Dialogu
  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final customerName = TextEditingController();
    final customerPhone = TextEditingController();
    final customerEmail = TextEditingController();
    final customerAddress = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Yeni Proje"),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: "Proje Adı *", hintText: "Örn: Ahmet Bey Villası"),
                  ),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: "Açıklama", hintText: "Örn: Mutfak tadilatı"),
                  ),
                  const SizedBox(height: 8),
                  const Align(alignment: Alignment.centerLeft, child: Text("Müşteri", style: TextStyle(fontWeight: FontWeight.bold))),
                  TextField(controller: customerName, decoration: const InputDecoration(labelText: "Müşteri adı")),
                  TextField(controller: customerPhone, decoration: const InputDecoration(labelText: "Telefon")),
                  TextField(controller: customerEmail, decoration: const InputDecoration(labelText: "E-posta"), keyboardType: TextInputType.emailAddress),
                  TextField(controller: customerAddress, decoration: const InputDecoration(labelText: "Adres"), maxLines: 2),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                Navigator.pop(context);

                final newProject = await _apiService.createProject(
                  nameController.text.trim(),
                  descController.text.trim(),
                  customerName: customerName.text.trim(),
                  customerPhone: customerPhone.text.trim(),
                  customerEmail: customerEmail.text.trim(),
                  customerAddress: customerAddress.text.trim(),
                );

                if (newProject != null) {
                  _refreshProjects();
                  if (!mounted) return;
                  Navigator.push(
                    this.context,
                    MaterialPageRoute(builder: (context) => ProjectDetailScreen(projectId: newProject.id)),
                  );
                }
              },
              child: const Text("Oluştur"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _importProject() async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['iwd', 'json'],
      );
      if (picked.isEmpty) return;
      final file = picked.first;
      final content = utf8.decode(await file.readAsBytes());
      if (content.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya okunamadı.')));
        return;
      }
      final project = await ProjectFileApi().importProject(content);
      _refreshProjects();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
      );
      _refreshProjects();
    } catch (e) {
      debugPrint('İçe aktarma hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("iWindoor Projelerim"),
        centerTitle: true,
        elevation: 2,
        actions: [
          IconButton(
            tooltip: 'İçe aktar',
            icon: const Icon(Icons.upload_file),
            onPressed: _importProject,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'import') _importProject();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'import', child: Text('İçe aktar (.iwd)')),
            ],
          ),
        ],
      ),
      
      // --- YAN MENÜ (DRAWER) ---
      drawer: Drawer(
        child: Column(
          children: [
            // Üst Başlık (Header)
            UserAccountsDrawerHeader(
              accountName: Text(
                _userName,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              accountEmail: Text(_userEmail),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  _userName.isNotEmpty ? _userName[0].toUpperCase() : "A",
                  style: TextStyle(fontSize: 24, color: Colors.blue.shade800),
                ),
              ),
              decoration: BoxDecoration(color: Colors.blue.shade800),
            ),
            
            // Menü Öğeleri
            ListTile(
              leading: const Icon(Icons.settings_applications),
              title: const Text("Katalog ve Fiyatlar"),
              subtitle: const Text("Profil, cam, aksesuar, donanım"),
              onTap: () {
                Navigator.pop(context); // Menüyü kapat
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CatalogScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text("Firma Bilgileri"),
              subtitle: const Text("Adres, vergi, teklif ayarları"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => const CompanySettingsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Çalışanlar"),
              onTap: () {
                Navigator.pop(context); // Menüyü kapat
                Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Hakkımızda"),
              onTap: () {
                 Navigator.pop(context);
                 showAboutDialog(
                   context: context, 
                   applicationName: "iWindoor Mobile",
                   applicationVersion: "1.0.0",
                   children: [const Text("Profesyonel Pencere ve Kapı Çizim Sistemi.")]
                 );
              },
            ),
            
            const Spacer(), // Geriye kalan boşluğu iterek çıkış butonunu alta yaslar
            
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context); // Menüyü kapat
                
                // Çıkış yap
                await AuthService().logout();
                
                // Login ekranına yönlendir ve geri dönüşü engelle
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 20), // En alttan biraz boşluk
          ],
        ),
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      // ... Body kısmı (Liste) AYNI KALSIN ...
      body: FutureBuilder<List<Project>>(
         // ... (Eski body kodlarının aynısı buraya gelecek)
         future: _projectsFuture,
         builder: (context, snapshot) {
            // ... (Kopyala yapıştır yaparken burayı bozmamaya dikkat et)
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text("Hata: ${snapshot.error}"));
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
               return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.folder_open, size: 80, color: Colors.grey),
                    SizedBox(height: 10),
                    Text("Henüz proje yok.\nArtıya basarak oluşturabilirsin!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                  ],
                ),
              );
            }
            
            final projects = snapshot.data!;
            
             return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                return Card(
                  elevation: 3,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(15),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: Text(project.name.isNotEmpty ? project.name[0].toUpperCase() : "?"),
                    ),
                    title: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(project.description),
                        const SizedBox(height: 5),
                        Text(
                          "${project.windowUnits.length} Pencere", 
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])
                        ),
                      ],
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "${project.totalPrice.toStringAsFixed(2)} TL",
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16),
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      ],
                    ),
                    onTap: () async {
                      // Detay Ekranına (Galeriye) Git
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProjectDetailScreen(
                            projectId: project.id,
                          ),
                        ),
                      );
                      _refreshProjects();
                    },
                  ),
                );
              },
            );
         }
      ),
    );
  }
}

//SON GÜNCEL BAZLI FİYAT DEĞİŞİKLİĞİ YAPMAK İSTER MİSİNİSİNİZ SORUSU ?
//PROJEYE GÖRE FİYAT DEĞİŞİKLİĞİ YAPILABİLİR.
