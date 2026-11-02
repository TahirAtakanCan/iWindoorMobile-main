import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/project.dart';
import 'window_editor_screen.dart';
import '../widgets/window_thumbnail.dart';
import 'cost_summary_screen.dart';
import 'project_specs_screen.dart';
import '../services/pdf_service.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ApiService _apiService = ApiService();
  late Future<Project?> _projectFuture;

  @override
  void initState() {
    super.initState();
    _refreshProject();
  }

  void _confirmPriceSync() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Fiyatlar Güncellensin mi?"),
        content: const Text("Projedeki tüm pencerelerin maliyeti, Ayarlar menüsündeki EN GÜNCEL birim fiyatlara göre yeniden hesaplanacak.\n\nBu işlem geri alınamaz."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Vazgeç")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _apiService.syncProjectPrices(widget.projectId);
              _refreshProject(); // Yeni fiyatı göster
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proje güncel kurlara çekildi.")));
            },
            child: const Text("Güncelle"),
          ),
        ],
      ),
    );
  }

  void _refreshProject() {
    setState(() {
      _projectFuture = _apiService.getProject(widget.projectId);
    });
  }

  // --- İŞLEM FONKSİYONLARI ---

  // 1. Proje Düzenle (Edit Specs)
  void _showEditProjectDialog(Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Proje Bilgilerini Düzenle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Proje Adı")),
            TextField(controller: descController, decoration: const InputDecoration(labelText: "Açıklama")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              bool success = await _apiService.updateProject(project.id, nameController.text, descController.text);
              if (success) {
                _refreshProject();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Güncellendi")));
              }
            },
            child: const Text("Kaydet"),
          ),
        ],
      ),
    );
  }

  // 2. Proje Sil (Delete Item)
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Projeyi Sil?"),
        content: const Text("Bu proje ve içindeki tüm pencereler kalıcı olarak silinecektir."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context); // Dialogu kapat
              bool success = await _apiService.deleteProject(widget.projectId);
              if (success && mounted) {
                Navigator.pop(context); // Ekranı kapat (Ana sayfaya dön)
              }
            },
            child: const Text("Sil"),
          ),
        ],
      ),
    );
  }

  // 3. PDF Paylaş (Share PDF)
  // 3. PDF Paylaş (Share PDF)
  Future<void> _shareAsPdf(Project project) async {
    // Bekleme göstergesi (SnackBar)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("PDF Hazırlanıyor..."), duration: Duration(seconds: 1)),
    );

    try {
      final PdfService pdfService = PdfService();
      await pdfService.generateAndPrintProjectReport(project);
    } catch (e) {
      print("PDF Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("PDF oluşturulurken hata oluştu."), backgroundColor: Colors.red),
      );
    }
  }

  // 4. Yeni Pencere Ekle
  void _showAddWindowDialog() {
    final nameController = TextEditingController();
    final widthController = TextEditingController();
    final heightController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Yeni Poz Ekle"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: "Poz Adı (Örn: P-01)")),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: widthController, decoration: const InputDecoration(labelText: "En (mm)"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: heightController, decoration: const InputDecoration(labelText: "Boy (mm)"), keyboardType: TextInputType.number)),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("İptal")),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              Navigator.pop(context);
              await _apiService.addWindow(
                widget.projectId, nameController.text, 
                double.parse(widthController.text), double.parse(heightController.text)
              );
              _refreshProject();
            },
            child: const Text("Oluştur"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Project?>(
      future: _projectFuture,
      builder: (context, snapshot) {
        // Veri Yükleniyor...
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(appBar: AppBar(title: const Text("Yükleniyor...")), body: const Center(child: CircularProgressIndicator()));
        }
        
        // Hata veya Veri Yok
        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(appBar: AppBar(title: const Text("Hata")), body: const Center(child: Text("Proje bulunamadı.")));
        }

        final project = snapshot.data!;
        
        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              // 1. PDF PAYLAŞ BUTONU (Resimdeki Paylaş butonu yerine)
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: "PDF Paylaş",
                // Değişiklik burada:
                onPressed: () => _shareAsPdf(project), 
              ),
              
              // 2. ÜÇ NOKTA MENÜSÜ (Edit Item Specs, Delete Item...)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showEditProjectDialog(project);
                  if (value == 'delete') _confirmDelete();
                  if (value == 'cost') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CostSummaryScreen(projectId: project.id),
                      ),
                    );
                  }
                  if (value == 'sync_prices') _confirmPriceSync();
                  if (value == 'specs') {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => ProjectSpecsScreen(projectId: project.id)));
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit),
                      title: Text('Proje Bilgileri'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'specs',
                    child: ListTile(
                      leading: Icon(Icons.assignment),
                      title: Text('Teknik Özellikler'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'cost',
                    child: ListTile(
                      leading: Icon(Icons.price_check),
                      title: Text('Maliyet / Özet'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'sync_prices',
                    child: ListTile(
                      leading: Icon(Icons.sync, color: Colors.orange),
                      title: Text('Fiyatları Güncelle'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(Icons.delete, color: Colors.red),
                      title: Text('Projeyi Sil', style: TextStyle(color: Colors.red)),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: _showAddWindowDialog,
            child: const Icon(Icons.add),
          ),
          body: Column(
            children: [
              // ÜST BİLGİ KARTI (Özet)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                color: Colors.blue.shade50,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Açıklama: ${project.description}", style: TextStyle(color: Colors.grey[800])),
                    const SizedBox(height: 5),
                    Text(
                      "Toplam Tutar: ${project.totalPrice.toStringAsFixed(2)} TL", 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)
                    ),
                    // İleride buraya Toplam m2, Ağırlık vb. eklenecek
                  ],
                ),
              ),

              // PENCERE LİSTESİ (GRID)
              Expanded(
                child: project.windowUnits.isEmpty 
                  ? const Center(child: Text("Henüz pencere yok.")) 
                  : GridView.builder(
                      padding: const EdgeInsets.all(10),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, 
                        crossAxisSpacing: 10, 
                        mainAxisSpacing: 10, 
                        childAspectRatio: 0.9,
                      ),
                      itemCount: project.windowUnits.length,
                      itemBuilder: (context, index) {
                        final unit = project.windowUnits[index];
                        return GestureDetector(
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (context) => WindowEditorScreen(projectId: project.id, windowUnit: unit),
                            ));
                            _refreshProject();
                          },
                          child: WindowThumbnail(
                            rootNode: unit.rootNode!, name: unit.name, 
                            widthMm: unit.width, heightMm: unit.height
                          ),
                        );
                      },
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}