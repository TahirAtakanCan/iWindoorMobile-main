import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/api_service.dart';
import '../models/project.dart';
import '../models/catalog.dart';
import '../models/window_unit.dart';
import '../services/company_api.dart';
import '../services/design_api.dart';
import '../services/pdf_service.dart';
import '../services/project_file_api.dart';
import '../widgets/design_thumbnail.dart';
import 'design_editor/design_editor_screen.dart';
import 'production/production_screen.dart';
import 'project_quote_screen.dart';
import 'project_specs_screen.dart';
import 'templates/template_picker_screen.dart';

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

  void _showWindowActions(WindowUnit unit) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: Text('"${unit.name}" düzenle'),
            onTap: () {
              Navigator.pop(ctx);
              _openEditor(unit.id, unit.name);
            },
          ),
          ListTile(
            leading: const Icon(Icons.sell_outlined),
            title: const Text('Fiyatı elle gir'),
            onTap: () {
              Navigator.pop(ctx);
              _editSalePrice(unit);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Pencereyi sil', style: TextStyle(color: Colors.red)),
            onTap: () async {
              Navigator.pop(ctx);
              try {
                await _designApi.deleteWindow(unit.id);
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

  Future<void> _editSalePrice(WindowUnit unit) async {
    final ctrl = TextEditingController(
      text: unit.displaySaleUnit == null
          ? ''
          : (unit.displaySaleUnit == unit.displaySaleUnit!.roundToDouble()
              ? unit.displaySaleUnit!.toStringAsFixed(0)
              : unit.displaySaleUnit!.toStringAsFixed(2)),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Satış fiyatı · ${unit.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Birim satış (boş = otomatik)',
            border: OutlineInputBorder(),
            suffixText: 'TL',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final t = ctrl.text.trim().replaceAll(',', '.');
    final price = t.isEmpty ? null : double.tryParse(t);
    if (t.isNotEmpty && price == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli bir sayı girin.')));
      return;
    }
    try {
      await _designApi.setSalePrice(unit.id, override: price);
      _refreshProject();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiError.from(e).message), backgroundColor: Colors.red));
    }
  }

  Future<void> _openCostReport() async {
    try {
      final quote = await CompanyApi().getProjectQuote(widget.projectId);
      if (!mounted) return;
      if (quote.costSummary == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maliyet özeti yalnızca yöneticide görünür.')),
        );
        return;
      }
      await PdfService().shareOrPrintCostReport(quote);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
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
    final customerName = TextEditingController(text: project.customerName ?? '');
    final customerPhone = TextEditingController(text: project.customerPhone ?? '');
    final customerEmail = TextEditingController(text: project.customerEmail ?? '');
    final customerAddress = TextEditingController(text: project.customerAddress ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Proje Bilgilerini Düzenle"),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: "Proje Adı")),
                TextField(controller: descController, decoration: const InputDecoration(labelText: "Açıklama")),
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
              Navigator.pop(context);
              final success = await _apiService.updateProject(
                project.id,
                nameController.text.trim(),
                descController.text.trim(),
                customerName: customerName.text.trim(),
                customerPhone: customerPhone.text.trim(),
                customerEmail: customerEmail.text.trim(),
                customerAddress: customerAddress.text.trim(),
              );
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

  Future<void> _exportProject(Project project) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proje dışa aktarılıyor...'), duration: Duration(seconds: 1)),
      );
      final (fileName, json) = await ProjectFileApi().exportProject(project.id);
      if (!mounted) return;

      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final tmp = await getTemporaryDirectory();
        final file = File('${tmp.path}${Platform.pathSeparator}$fileName');
        await file.writeAsString(json, flush: true);
        await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Proje dosyası'));
      } else {
        final docs = await getApplicationDocumentsDirectory();
        final dir = Directory('${docs.path}${Platform.pathSeparator}iWindoor');
        await dir.create(recursive: true);
        final path = '${dir.path}${Platform.pathSeparator}$fileName';
        await File(path).writeAsString(json, flush: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kaydedildi: $path'),
            action: SnackBarAction(
              label: 'Klasörü aç',
              onPressed: () {
                Process.run('explorer', [dir.path]);
              },
            ),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } catch (e) {
      debugPrint('Dışa aktarma hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).message), backgroundColor: Colors.red),
      );
    }
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

  void _openQuote() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectQuoteScreen(projectId: widget.projectId)),
    );
  }

  // 4. Yeni Pencere Ekle — şablon seçici
  Future<void> _showAddWindowDialog() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePickerScreen(
          projectId: widget.projectId,
          catalog: _catalog,
          designApi: _designApi,
        ),
      ),
    );
    if (mounted) _refreshProject();
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
                tooltip: 'Teklif / PDF',
                onPressed: _openQuote,
              ),
              
              // 2. ÜÇ NOKTA MENÜSÜ (Edit Item Specs, Delete Item...)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') _showEditProjectDialog(project);
                  if (value == 'delete') _confirmDelete();
                  if (value == 'cost') _openQuote();
                  if (value == 'export') _exportProject(project);
                  if (value == 'sync_prices') _confirmPriceSync();
                  if (value == 'specs') {
                    Navigator.push(context, MaterialPageRoute(builder: (c) => ProjectSpecsScreen(projectId: project.id)));
                  }
                  if (value == 'production') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => ProductionScreen(
                          projectId: project.id,
                          project: project,
                          catalog: _catalog,
                        ),
                      ),
                    );
                  }
                  if (value == 'cost_report') _openCostReport();
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
                    value: 'production',
                    child: ListTile(
                      leading: Icon(Icons.precision_manufacturing),
                      title: Text('Üretim'),
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
                    value: 'cost_report',
                    child: ListTile(
                      leading: Icon(Icons.analytics_outlined),
                      title: Text('İç maliyet raporu'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: ListTile(
                      leading: Icon(Icons.download),
                      title: Text('Dışa aktar (.iwd)'),
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
                      'Toplam (KDV hariç): ${formatMoney(project.displaySaleTotal)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
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
                          onLongPress: () => _showWindowActions(unit),
                          onSecondaryTap: () => _showWindowActions(unit),
                          child: DesignThumbnail.unit(unit, catalog: _catalog),
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