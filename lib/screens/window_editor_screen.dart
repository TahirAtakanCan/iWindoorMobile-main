import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/window_unit.dart';
import '../models/window_node.dart';
import '../models/profile.dart';
import '../widgets/window_painter.dart';
import '../utils/utils.dart';

class WindowEditorScreen extends StatefulWidget {
  final int projectId;
  final WindowUnit windowUnit;

  const WindowEditorScreen({super.key, required this.projectId, required this.windowUnit});

  @override
  State<WindowEditorScreen> createState() => _WindowEditorScreenState();
}

class _WindowEditorScreenState extends State<WindowEditorScreen> {
  final ApiService _apiService = ApiService();
  late WindowUnit currentUnit;
  late WindowNode rootNode;
  
  // SEÇİM MEKANİZMASI
  int? selectedNodeId; // Şu an hangi parça seçili?
  WindowNode? selectedNode;

  @override
  void initState() {
    super.initState();
    currentUnit = widget.windowUnit;
    rootNode = currentUnit.rootNode!;
  }

  Future<void> _reloadUnit() async {
    final project = await _apiService.getProject(widget.projectId);
    if (project != null) {
      // Listeden güncel halini bul (Hata yönetimi ile)
      try {
        final updatedUnit = project.windowUnits.firstWhere((u) => u.id == widget.windowUnit.id);
        setState(() {
          currentUnit = updatedUnit;
          rootNode = updatedUnit.rootNode!;
          // İşlem bitince seçimi sıfırla ki kafa karışmasın
          selectedNodeId = null; 
          selectedNode = null;
        });
      } catch (e) {
        print("Pencere yenilenirken hata: $e");
      }
    }
  }

  // --- İŞLEM FONKSİYONLARI ---

  Future<void> _handleSplit(bool isVertical) async {
    if (selectedNodeId == null) return _showMsg("Lütfen önce bir parça seçin.");
    
    // Sadece Boşluk veya Bölünmemiş Kasa bölünebilir
    bool canSplit = selectedNode?.nodeType == 'EMPTY' || 
                    (selectedNode?.nodeType == 'FRAME' && selectedNode!.children.isEmpty);

    if (!canSplit) return _showMsg("Bu parça bölünemez (Dolu veya zaten bölünmüş).");

    bool success = await _apiService.splitNode(selectedNodeId!, isVertical);
    if (success) {
      await _apiService.calculatePrice(widget.projectId);
      _reloadUnit();
    }
  }

  Future<void> _handleSetType(String type) async {
    if (selectedNodeId == null) return _showMsg("Lütfen önce bir parça seçin.");

    if (type == 'SASH') {
      _showProfileDialog(selectedNodeId!, 'SASH'); // Kanat profili seç
    } 
    else if (type == 'GLASS') {
      // --- YENİ: Cam için de seçim ekranı aç ---
      // (Böylece fiyat hesaplanabilecek)
      _showGlassDialog(selectedNodeId!);
    } 
    else {
      bool success = await _apiService.updateNodeType(selectedNodeId!, type);
      if (success) {
        await _apiService.calculatePrice(widget.projectId);
        _reloadUnit();
      }
    }
  }

  // --- YENİ CAM DİALOGU ---
  void _showGlassDialog(int nodeId) async {
    // API'den camları çek (ApiService'e getAllGlasses eklemeyi unutma)
    List<Glass> glasses = await _apiService.getAllGlasses(); 
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Cam Seçimi"),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: glasses.isEmpty 
            ? const Center(child: Text("Tanımlı cam bulunamadı.")) 
            : ListView.builder(
              itemCount: glasses.length,
              itemBuilder: (c, i) => ListTile(
                leading: const Icon(Icons.grid_on, color: Colors.blueAccent),
                title: Text(glasses[i].name),
                subtitle: Text("${glasses[i].pricePerSquareMeter} TL/m2"),
                onTap: () async {
                  Navigator.pop(context);
                  
                  // 1. Tipi GLASS yap
                  await _apiService.updateNodeType(nodeId, 'GLASS');
                  
                  // 2. Camı Ata (Backend'e ID gönder)
                  await _apiService.assignMaterial(nodeId, glasses[i].id, 'GLASS');
                  
                  // 3. Hesapla ve Yenile
                  await _apiService.calculatePrice(widget.projectId);
                  _reloadUnit();
                  _showMsg("${glasses[i].name} atandı.");
                },
              ),
            ),
        ),
      ),
    );
  }

  void _showProfileDialog(int nodeId, String type) async {
    // Profil listesini çek
    List<Profile> profiles = await _apiService.getProfilesByType(type); 
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("$type Modeli Seç"),
        content: SizedBox(
          width: double.maxFinite, height: 300,
          child: profiles.isEmpty 
            ? const Center(child: Text("Tanımlı profil bulunamadı.")) 
            : ListView.builder(
              itemCount: profiles.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(profiles[i].name),
                subtitle: Text("${profiles[i].pricePerMeter} TL/m"),
                onTap: () async {
                  Navigator.pop(context); // Dialogu kapat

                  // --- KRİTİK DÜZELTME BURADA ---
                  
                  // 1. Önce Node Tipini "SASH" yap (Bunu unutmuştuk!)
                  await _apiService.updateNodeType(nodeId, 'SASH');

                  // 2. Sonra Malzemeyi Ata
                  await _apiService.assignMaterial(nodeId, profiles[i].id, 'PROFILE');
                  
                  // 3. Fiyatı Hesapla ve Ekranı Yenile
                  await _apiService.calculatePrice(widget.projectId);
                  _reloadUnit();
                  
                  _showMsg("${profiles[i].name} uygulandı.");
                },
              ),
            ),
        ),
      ),
    );
  }

  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(milliseconds: 700))
    );
  }

  // --- ÜST TOOLBAR ---
  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _toolBtn(Icons.splitscreen, "Dikey", () => _handleSplit(true)),
          _toolBtn(Icons.horizontal_split, "Yatay", () => _handleSplit(false)),
          const VerticalDivider(width: 20, thickness: 1, color: Colors.grey),
          _toolBtn(Icons.crop_square, "Sabit", () => _handleSetType('GLASS')),
          _toolBtn(Icons.window, "Kanat", () => _handleSetType('SASH')),
        ],
      ),
    );
  }

  Widget _toolBtn(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]
            ),
            child: Icon(icon, color: Colors.blue[800], size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(currentUnit.name)),
      body: Column(
        children: [
          // 1. TOOLBAR (Yukarıda)
          _buildToolbar(),

          // 2. ÇİZİM ALANI
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Painter'daki padding (40+40=80) için pay bırakıyoruz
                double availableW = constraints.maxWidth;
                double availableH = constraints.maxHeight;

                double scaleX = availableW / (rootNode.width + 100); 
                double scaleY = availableH / (rootNode.height + 100);
                double scale = (scaleX < scaleY) ? scaleX : scaleY;

                return Center(
                  child: GestureDetector(
                    onTapUp: (details) {
                      // Tıklananı Bul (Offset 40,40 Painter padding'i ile aynı olmalı)
                      WindowNode? clicked = findNodeAt(rootNode, details.localPosition, const Offset(40,40), scale);
                      
                      if (clicked != null) {
                        setState(() {
                          // Eğer zaten seçiliyse seçimi kaldır, değilse seç
                          if (selectedNodeId == clicked.id) {
                            selectedNodeId = null;
                            selectedNode = null;
                          } else {
                            selectedNodeId = clicked.id;
                            selectedNode = clicked;
                          }
                        });
                      } else {
                        setState(() {
                          selectedNodeId = null; // Boşa tıklarsa seçimi kaldır
                        });
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300)
                      ),
                      child: CustomPaint(
                        size: Size(rootNode.width * scale + 80, rootNode.height * scale + 80),
                        painter: WindowPainter(
                          rootNode: rootNode,
                          selectedNodeId: selectedNodeId // Seçili ID'yi gönderiyoruz (Mavi yanacak)
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}