import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/project.dart';
import 'package:windoor_core/windoor_core.dart';
import '../models/catalog.dart';
import '../services/design_api.dart';
import '../widgets/design_thumbnail.dart';
import 'design_editor/design_editor_screen.dart';
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
  final DesignApi _designApi = DesignApi();
  late Future<Project?> _projectFuture;
  CatalogSnapshot? _catalog;

  @override
  void initState() {
    super.initState();
    _refreshProject();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final cat = await _designApi.catalog();
    if (mounted) setState(() => _catalog = cat);
  }

  Future<void> _openEditor(int windowId, String name) async {
    await Navigator.push(context, MaterialPageRoute(
      builder: (context) => DesignEditorScreen(windowId: windowId, title: name, api: _designApi),
    ));
    _refreshProject();
  }

  void _showWindowActions(int windowId, String name) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text('"$name" düzenle'),
            onTap: () {
              Navigator.pop(ctx);
              _openEditor(windowId, name);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Pencereyi sil', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await _designApi.deleteWindow(windowId);
                _refreshProject();
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
              }
            },
          ),
        ]),
      ),
    );
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
              if (!mounted) return;
              ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Proje güncel kurlara çekildi.")));
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
              if (success && mounted) {
                _refreshProject();
                ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text("Güncellendi")));
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
                Navigator.pop(this.context); // Ekranı kapat (Ana sayfaya dön)
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
      debugPrint("PDF Hatası: $e");
      if (!mounted) return;
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
              final name = nameController.text.trim();
              final w = double.tryParse(widthController.text.replaceAll(',', '.'));
              final h = double.tryParse(heightController.text.replaceAll(',', '.'));
              if (name.isEmpty || w == null || h == null || w < 300 || h < 300 || w > 12000 || h > 6000) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Ad girin; en 300-12000, boy 300-6000 mm olmalı.")));
                return;
              }
              Navigator.pop(context);
              final cat = _catalog ?? await _designApi.catalog();
              final series = cat.series.isNotEmpty && cat.series.first.id != 0 ? cat.series.first.id : null;
              try {
                final doc = await _designApi.createWindow(
                  projectId: widget.projectId,
                  name: name,
                  seriesId: series,
                  design: WindowDesign.single(w, h, seriesId: series?.toString(), glassCode: cat.defaultGlassCode),
                );
                if (!mounted) return;
                await _openEditor(doc.id, doc.name);
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(ApiError.from(e).toString()), backgroundColor: Colors.red));
                _refreshProject();
              }
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
                      // Telefonda 2, masaüstünde ekran genişliğine göre daha fazla sütun
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 240,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: project.windowUnits.length,
                      itemBuilder: (context, index) {
                        final unit = project.windowUnits[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openEditor(unit.id, unit.name),
                          onLongPress: () => _showWindowActions(unit.id, unit.name),
                          onSecondaryTap: () => _showWindowActions(unit.id, unit.name),
                          child: DesignThumbnail(unit: unit, catalog: _catalog),
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