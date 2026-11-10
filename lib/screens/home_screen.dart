import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../models/customer.dart';
import '../models/dashboard.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/customer_api.dart';
import '../services/design_api.dart';
import '../services/project_file_api.dart';
import '../models/project.dart';
import '../utils/format.dart';
import '../utils/status.dart';
import '../widgets/status_badge.dart';
import 'customers/customer_list_screen.dart';
import 'customers/customer_picker.dart';
import 'project_detail_screen.dart';
import 'catalog/catalog_screen.dart';
import 'company_settings_screen.dart';
import 'employee_list_screen.dart';
import 'login_screen.dart';
import 'offline/offline_data_screen.dart';
import '../services/offline/offline_project_store.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  final CustomerApi _customerApi = CustomerApi();
  late Future<List<Project>> _projectsFuture;
  DashboardSummary? _dashboard;
  ProjectStatus? _statusFilter;
  Set<int> _offlineIds = {};
  String _userName = "Yükleniyor...";
  String _userEmail = "";

  @override
  void initState() {
    super.initState();
    _refreshAll();
    _loadUserInfo();
  }

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
      _projectsFuture = _apiService.getAllProjects(
        status: _statusFilter?.apiValue,
      );
    });
  }

  Future<void> _refreshAll() async {
    _refreshProjects();
    final offline = await OfflineProjectStore.ids();
    if (mounted) setState(() => _offlineIds = offline);
    try {
      final dash = await _customerApi.dashboard();
      if (mounted) setState(() => _dashboard = dash);
    } catch (_) {
      // Dashboard opsiyonel; proje listesi yeterli.
    }
  }

  void _setStatusFilter(ProjectStatus? status) {
    setState(() => _statusFilter = status);
    _refreshProjects();
  }

  void _showCreateDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final customerName = TextEditingController();
    final customerPhone = TextEditingController();
    final customerEmail = TextEditingController();
    final customerAddress = TextEditingController();
    Customer? selectedCustomer;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
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
                      OutlinedButton.icon(
                        onPressed: () async {
                          final c = await pickCustomer(context, current: selectedCustomer);
                          if (c == null) return;
                          setLocal(() {
                            selectedCustomer = c;
                            customerName.text = c.name;
                            customerPhone.text = c.phone ?? '';
                            customerEmail.text = c.email ?? '';
                            customerAddress.text = c.address ?? '';
                          });
                        },
                        icon: const Icon(Icons.person_search),
                        label: Text(selectedCustomer == null ? 'Müşteri seç' : selectedCustomer!.name),
                      ),
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
                      customerId: selectedCustomer?.id,
                      customerName: customerName.text.trim(),
                      customerPhone: customerPhone.text.trim(),
                      customerEmail: customerEmail.text.trim(),
                      customerAddress: customerAddress.text.trim(),
                    );

                    if (newProject != null) {
                      _refreshAll();
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
      _refreshAll();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: project.id)),
      );
      _refreshAll();
    } catch (e) {
      debugPrint('İçe aktarma hatası: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ApiError.from(e).message), backgroundColor: Colors.red),
      );
    }
  }

  Map<ProjectStatus, int> _countsFrom(List<Project> projects, DashboardSummary? dash) {
    if (dash != null && dash.statusCounts.isNotEmpty) return dash.statusCounts;
    final m = <ProjectStatus, int>{};
    for (final p in projects) {
      m[p.status] = (m[p.status] ?? 0) + 1;
    }
    return m;
  }

  Widget _dashCard(String title, String value, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade800)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _deliveryTile(DeliveryLine p, {required bool overdue}) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.event, color: overdue ? Colors.red : Colors.orange),
      title: Text(p.name),
      subtitle: Text([
        if ((p.customerName ?? '').isNotEmpty) p.customerName!,
        'Teslim: ${p.deliveryLabel}',
      ].join(' · ')),
      trailing: StatusBadge(status: p.status, compact: true),
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)),
        );
        _refreshAll();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          BrandLogo.mark(size: 30),
          SizedBox(width: 10),
          Text('Projelerim'),
        ]),
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
      drawer: Drawer(
        child: Column(
          children: [
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
                  style: const TextStyle(fontSize: 24, color: Brand.petrol, fontWeight: FontWeight.bold),
                ),
              ),
              decoration: const BoxDecoration(gradient: Brand.gradient),
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text("Müşteriler"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CustomerListScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_applications),
              title: const Text("Katalog ve Fiyatlar"),
              subtitle: const Text("Profil, cam, aksesuar, donanım"),
              onTap: () {
                Navigator.pop(context);
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
              leading: const Icon(Icons.offline_pin_outlined),
              title: const Text("Çevrimdışı veriler"),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const OfflineDataScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text("Çalışanlar"),
              onTap: () {
                Navigator.pop(context);
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
                  applicationName: Brand.appName,
                  applicationVersion: "1.0.0",
                  applicationIcon: const BrandLogo.mark(size: 48),
                  children: [const Text("PVC ve alüminyum pencere, kapı tasarımı; teklif, üretim ve iş takibi.")],
                );
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Çıkış Yap", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              onTap: () async {
                Navigator.pop(context);
                await AuthService().logout();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                    (route) => false,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Project>>(
        future: _projectsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }

          final projects = snapshot.data ?? const <Project>[];
          final counts = _countsFrom(projects, _dashboard);
          final dash = _dashboard;

          return RefreshIndicator(
            onRefresh: _refreshAll,
            child: ListView(
              padding: const EdgeInsets.all(10),
              children: [
                if (dash != null) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _dashCard('Teklif bekleyen', '${dash.quoteCount}', Colors.grey.shade700, () => _setStatusFilter(ProjectStatus.quote)),
                        const SizedBox(width: 8),
                        _dashCard('Üretimde', '${dash.productionCount}', Colors.orange, () => _setStatusFilter(ProjectStatus.production)),
                        const SizedBox(width: 8),
                        _dashCard('Montajda', '${dash.installationCount}', Colors.purple, () => _setStatusFilter(ProjectStatus.installation)),
                        const SizedBox(width: 8),
                        _dashCard('Toplam alacak', formatMoney(dash.totalReceivable), Colors.deepOrange, () {}),
                        const SizedBox(width: 8),
                        _dashCard('Bu ay onaylanan', formatMoney(dash.approvedThisMonth), Colors.blue, () => _setStatusFilter(ProjectStatus.approved)),
                      ],
                    ),
                  ),
                  if (dash.overdueDeliveries.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Geciken teslimler', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                    ...dash.overdueDeliveries.map((p) => _deliveryTile(p, overdue: true)),
                  ],
                  if (dash.upcomingDeliveries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('Yaklaşan teslimler', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...dash.upcomingDeliveries.map((p) => _deliveryTile(p, overdue: false)),
                  ],
                  const SizedBox(height: 8),
                ],
                Builder(builder: (_) {
                  final totalCount = counts.values.fold<int>(0, (a, b) => a + b);
                  final allLabel = totalCount > 0 ? totalCount : projects.length;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: Text('Tümü ($allLabel)'),
                          selected: _statusFilter == null,
                          onSelected: (_) => _setStatusFilter(null),
                        ),
                        const SizedBox(width: 6),
                        for (final s in ProjectStatus.allOrdered) ...[
                          FilterChip(
                            label: Text('${s.labelTr} (${counts[s] ?? 0})'),
                            selected: _statusFilter == s,
                            selectedColor: s.color.withValues(alpha: 0.25),
                            onSelected: (_) => _setStatusFilter(s),
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 8),
                if (projects.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.folder_open, size: 80, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("Henüz proje yok.\nArtıya basarak oluşturabilirsin!", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                  )
                else
                  ...projects.map((project) {
                    final approved = project.status == ProjectStatus.approved ||
                        project.status == ProjectStatus.production ||
                        project.status == ProjectStatus.installation ||
                        project.status == ProjectStatus.delivered;
                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(15),
                        leading: CircleAvatar(
                          backgroundColor: project.status.color.withValues(alpha: 0.2),
                          child: Text(project.name.isNotEmpty ? project.name[0].toUpperCase() : "?"),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(project.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                            if (_offlineIds.contains(project.id))
                              const Padding(
                                padding: EdgeInsets.only(right: 6),
                                child: Icon(Icons.offline_pin, size: 18, color: Colors.teal),
                              ),
                            StatusBadge(status: project.status, compact: true),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(project.description),
                            const SizedBox(height: 4),
                            Text(
                              "${project.windowUnits.length} Pencere",
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            if (project.deliveryDate != null)
                              Text('Teslim: ${formatDate(project.deliveryDate)}', style: const TextStyle(fontSize: 12)),
                            if (approved && project.balance > 0)
                              Text(
                                'Kalan: ${formatMoney(project.balance)}',
                                style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                        trailing: Text(
                          formatMoney(project.displaySaleTotal),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 15),
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ProjectDetailScreen(projectId: project.id),
                            ),
                          );
                          _refreshAll();
                        },
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
