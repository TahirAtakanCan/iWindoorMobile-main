import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer.dart';
import '../models/payment.dart';
import '../services/api_service.dart';
import '../models/project.dart';
import '../models/catalog.dart';
import '../models/window_unit.dart';
import '../pdf/receipt_pdf.dart';
import '../services/auth_service.dart';
import '../services/company_api.dart';
import '../services/customer_api.dart';
import '../services/design_api.dart';
import '../services/pdf_service.dart';
import '../services/project_file_api.dart';
import '../theme/app_theme.dart';
import '../utils/status.dart';
import '../widgets/design_thumbnail.dart';
import '../widgets/status_badge.dart';
import 'customers/customer_picker.dart';
import 'design_editor/design_editor_screen.dart';
import 'production/production_screen.dart';
import 'project_history_screen.dart';
import 'project_quote_screen.dart';
import 'project_specs_screen.dart';
import '../services/offline/offline_project_store.dart';
import 'survey/survey_screen.dart';
import 'templates/template_picker_screen.dart';
import 'versions/version_list_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final ApiService _apiService = ApiService();
  final DesignApi _designApi = DesignApi();
  final CustomerApi _customerApi = CustomerApi();
  late Future<Project?> _projectFuture;
  CatalogSnapshot? _catalog;
  PaymentsSummary? _payments;
  bool _isAdmin = false;
  bool _paymentsExpanded = false;

  @override
  void initState() {
    super.initState();
    _refreshProject();
    _loadCatalog();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await AuthService().getRole();
    if (mounted) setState(() => _isAdmin = role == 'COMPANY_ADMIN');
  }

  Future<void> _loadCatalog() async {
    final cat = await _designApi.catalog();
    if (mounted) setState(() => _catalog = cat);
  }

  Future<void> _loadPayments() async {
    try {
      final p = await _customerApi.listPayments(widget.projectId);
      if (mounted) setState(() => _payments = p);
    } catch (_) {
      if (mounted) setState(() => _payments = null);
    }
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
              _refreshProject();
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
    _loadPayments();
  }

  void _showEditProjectDialog(Project project) {
    final nameController = TextEditingController(text: project.name);
    final descController = TextEditingController(text: project.description);
    final customerName = TextEditingController(text: project.customerName ?? '');
    final customerPhone = TextEditingController(text: project.customerPhone ?? '');
    final customerEmail = TextEditingController(text: project.customerEmail ?? '');
    final customerAddress = TextEditingController(text: project.customerAddress ?? '');
    int? customerId = project.customerId;
    Customer? selected;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
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
                  OutlinedButton.icon(
                    onPressed: () async {
                      final c = await pickCustomer(context, current: selected);
                      if (c == null) return;
                      setLocal(() {
                        selected = c;
                        customerId = c.id;
                        customerName.text = c.name;
                        customerPhone.text = c.phone ?? '';
                        customerEmail.text = c.email ?? '';
                        customerAddress.text = c.address ?? '';
                      });
                    },
                    icon: const Icon(Icons.person_search),
                    label: Text(selected?.name ?? (customerName.text.isEmpty ? 'Müşteri seç' : customerName.text)),
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
                Navigator.pop(context);
                final success = await _apiService.updateProject(
                  project.id,
                  nameController.text.trim(),
                  descController.text.trim(),
                  customerId: customerId,
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
              Navigator.pop(context);
              bool success = await _apiService.deleteProject(widget.projectId);
              if (success && mounted) {
                Navigator.pop(this.context);
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

  Future<void> _makeOfflineAvailable(int projectId) async {
    final progress = ValueNotifier<(String, double)>(('Başlıyor…', 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ValueListenableBuilder<(String, double)>(
        valueListenable: progress,
        builder: (_, v, __) => AlertDialog(
          title: const Text('Çevrimdışı indiriliyor'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LinearProgressIndicator(value: v.$2 <= 0 ? null : v.$2),
              const SizedBox(height: 12),
              Text(v.$1),
            ],
          ),
        ),
      ),
    );
    try {
      await OfflineProjectStore.downloadAll(
        projectId,
        onProgress: (s, p) => progress.value = (s, p),
      );
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Proje çevrimdışı kullanılabilir.')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      progress.dispose();
    }
  }

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

  Future<void> _handleStatusError(Object e) async {
    final err = ApiError.from(e);
    String msg = err.message;
    if (err.status == 403) {
      msg = 'Bu işlem için yetkiniz yok.';
    } else if (err.code == 'INVALID_TRANSITION') {
      msg = 'Geçersiz durum geçişi.';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _changeStatus(Project project, ProjectStatus to, {String? note, DateTime? deliveryDate, Payment? deposit}) async {
    try {
      await _customerApi.changeStatus(project.id, status: to, note: note, deliveryDate: deliveryDate);
      if (deposit != null) {
        await _customerApi.createPayment(project.id, deposit);
      }
      _refreshProject();
    } catch (e) {
      await _handleStatusError(e);
    }
  }

  Future<void> _onNextStep(Project project) async {
    final next = project.status.nextForward;
    if (next == null) return;

    if (next == ProjectStatus.approved) {
      double lockTotal = project.displaySaleTotal;
      try {
        final q = await CompanyApi().getProjectQuote(project.id);
        lockTotal = q.grandTotal > 0 ? q.grandTotal : project.displaySaleTotal;
      } catch (_) {}
      final amountCtrl = TextEditingController();
      PaymentMethod method = PaymentMethod.cash;
      var takeDeposit = false;
      if (!mounted) return;
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setLocal) => AlertDialog(
            title: const Text('Onayla'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kilitlenecek genel toplam (KDV dahil): ${formatMoney(lockTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kapora al'),
                  value: takeDeposit,
                  onChanged: (v) => setLocal(() => takeDeposit = v ?? false),
                ),
                if (takeDeposit) ...[
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tutar', border: OutlineInputBorder(), suffixText: 'TL'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PaymentMethod>(
                    key: ValueKey(method),
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Yöntem', border: OutlineInputBorder()),
                    items: [
                      for (final m in PaymentMethod.values)
                        DropdownMenuItem(value: m, child: Text(paymentMethodTr(m))),
                    ],
                    onChanged: (v) => setLocal(() => method = v ?? PaymentMethod.cash),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Onayla')),
            ],
          ),
        ),
      );
      if (ok != true) return;
      Payment? deposit;
      if (takeDeposit) {
        final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
        if (amt == null || amt <= 0) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli kapora tutarı girin.')));
          return;
        }
        deposit = Payment(id: 0, kind: PaymentKind.payment, amount: amt, paidAt: DateTime.now(), method: method);
      }
      await _changeStatus(project, next, deposit: deposit);
      return;
    }

    final label = project.status.nextForwardActionLabel ?? 'Devam';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(label),
        content: Text('Durum "${next.labelTr}" olacak. Onaylıyor musunuz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(label)),
        ],
      ),
    );
    if (ok == true) await _changeStatus(project, next);
  }

  Future<void> _revert(Project project) async {
    final prev = project.status.previous;
    if (prev == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Geri al'),
        content: Text('Durum "${prev.labelTr}" olacak.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Geri al')),
        ],
      ),
    );
    if (ok == true) await _changeStatus(project, prev);
  }

  Future<void> _cancel(Project project) async {
    final noteCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İptal et'),
        content: TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Not', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('İptal et'),
          ),
        ],
      ),
    );
    if (ok == true) await _changeStatus(project, ProjectStatus.cancelled, note: noteCtrl.text.trim());
  }

  Future<void> _setDeliveryDate(Project project) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: project.deliveryDate ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    try {
      await _customerApi.setDeliveryDate(project.id, picked);
      _refreshProject();
    } catch (e) {
      await _handleStatusError(e);
    }
  }

  Future<void> _paymentDialog(Project project, {required bool refund}) async {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var paidAt = DateTime.now();
    var method = PaymentMethod.cash;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(refund ? 'İade' : 'Ödeme al'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar *', border: OutlineInputBorder(), suffixText: 'TL'),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('Tarih: ${formatDate(paidAt)}'),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: paidAt,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );
                    if (d != null) setLocal(() => paidAt = d);
                  },
                ),
                DropdownButtonFormField<PaymentMethod>(
                  key: ValueKey(method),
                  initialValue: method,
                  decoration: const InputDecoration(labelText: 'Yöntem', border: OutlineInputBorder()),
                  items: [
                    for (final m in PaymentMethod.values) DropdownMenuItem(value: m, child: Text(paymentMethodTr(m))),
                  ],
                  onChanged: (v) => setLocal(() => method = v ?? PaymentMethod.cash),
                ),
                const SizedBox(height: 8),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'Not', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(refund ? 'İade kaydet' : 'Kaydet')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final amt = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
    if (amt == null || amt <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Geçerli tutar girin.')));
      return;
    }
    try {
      await _customerApi.createPayment(
        project.id,
        Payment(
          id: 0,
          kind: refund ? PaymentKind.refund : PaymentKind.payment,
          amount: amt,
          paidAt: paidAt,
          method: method,
          note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
        ),
      );
      _refreshProject();
    } catch (e) {
      await _handleStatusError(e);
    }
  }

  Future<void> _deletePayment(Project project, Payment payment) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ödemeyi sil'),
        content: Text('${formatMoney(payment.amount)} silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _customerApi.deletePayment(project.id, payment.id);
      _refreshProject();
    } catch (e) {
      await _handleStatusError(e);
    }
  }

  Future<void> _shareReceipt(Project project, Payment payment) async {
    try {
      final company = await CompanyApi().getCompany();
      final balance = _payments?.balance ?? project.balance;
      await ReceiptPdf().share(
        company: company,
        project: project,
        payment: payment,
        balanceAfter: balance,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Widget _statusStrip(Project project) {
    final nextLabel = project.status.nextForwardActionLabel;
    return Material(
      color: project.status.color.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            StatusBadge(status: project.status),
            const Spacer(),
            if (nextLabel != null)
              FilledButton(
                onPressed: () => _onNextStep(project),
                child: Text(nextLabel),
              ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'history') {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectHistoryScreen(projectId: project.id)));
                } else if (v == 'delivery') {
                  _setDeliveryDate(project);
                } else if (v == 'revert') {
                  _revert(project);
                } else if (v == 'cancel') {
                  _cancel(project);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'history', child: Text('Geçmiş')),
                const PopupMenuItem(value: 'delivery', child: Text('Teslim tarihi')),
                if (_isAdmin && project.status.previous != null)
                  const PopupMenuItem(value: 'revert', child: Text('Geri al')),
                if (_isAdmin && project.status != ProjectStatus.cancelled)
                  const PopupMenuItem(value: 'cancel', child: Text('İptal et')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _projectSummary(Project project) {
    final customer = (project.customerName ?? '').trim();
    final desc = project.description.trim();
    return Card(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Brand.petrol.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (desc.isNotEmpty)
              Text(
                desc,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade800, fontSize: 14),
              ),
            if (desc.isNotEmpty) const SizedBox(height: 8),
            Row(
              children: [
                if (customer.isNotEmpty) ...[
                  Icon(Icons.person_outline, size: 16, color: Brand.petrolLight),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      customer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: Brand.ink),
                    ),
                  ),
                ],
                if (customer.isNotEmpty && project.deliveryDate != null) const SizedBox(width: 12),
                if (project.deliveryDate != null) ...[
                  Icon(Icons.event_outlined, size: 16, color: Brand.petrolLight),
                  const SizedBox(width: 4),
                  Text(
                    formatDate(project.deliveryDate),
                    style: const TextStyle(fontSize: 13, color: Brand.ink),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              formatMoney(project.displaySaleTotal),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Brand.petrol),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paymentsSection(Project project) {
    final sum = _payments;
    final paid = sum?.paidTotal ?? project.paidTotal;
    final balance = sum?.balance ?? project.balance;
    final items = sum?.items ?? const <Payment>[];
    final paidOff = balance.abs() < 0.005;

    return Card(
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Brand.petrol.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _paymentsExpanded = !_paymentsExpanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Tahsilat · Ödenen ${formatMoney(paid)} / Kalan ${formatMoney(balance)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Brand.ink),
                    ),
                  ),
                  if (paidOff)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade400),
                      ),
                      child: Text('Ödendi', style: TextStyle(fontSize: 11, color: Colors.green.shade800, fontWeight: FontWeight.w600)),
                    ),
                  Icon(_paymentsExpanded ? Icons.expand_less : Icons.expand_more, color: Brand.petrol),
                ],
              ),
            ),
          ),
          if (_paymentsExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      TextButton(onPressed: () => _paymentDialog(project, refund: false), child: const Text('Ödeme al')),
                      TextButton(onPressed: () => _paymentDialog(project, refund: true), child: const Text('İade')),
                    ],
                  ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 4, 8, 8),
                      child: Text('Ödeme yok.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...items.map((p) {
                      final red = p.isRefund;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        title: Text(
                          '${formatDate(p.paidAt)} · ${paymentMethodTr(p.method)}',
                          style: TextStyle(color: red ? Colors.red : null),
                        ),
                        subtitle: (p.note ?? '').isEmpty ? null : Text(p.note!),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formatMoney(p.signedAmount),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: red ? Colors.red : Brand.petrol,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.receipt_long, size: 20),
                              tooltip: 'Makbuz',
                              onPressed: () => _shareReceipt(project, p),
                            ),
                            if (_isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                onPressed: () => _deletePayment(project, p),
                              ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Project?>(
      future: _projectFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(appBar: AppBar(title: const Text("Yükleniyor...")), body: const Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return Scaffold(appBar: AppBar(title: const Text("Hata")), body: const Center(child: Text("Proje bulunamadı.")));
        }

        final project = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(project.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                tooltip: 'Teklif / PDF',
                onPressed: _openQuote,
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  switch (value) {
                    case 'edit':
                      _showEditProjectDialog(project);
                    case 'delete':
                      _confirmDelete();
                    case 'cost':
                      _openQuote();
                    case 'export':
                      _exportProject(project);
                    case 'sync_prices':
                      _confirmPriceSync();
                    case 'specs':
                      Navigator.push(context, MaterialPageRoute(builder: (c) => ProjectSpecsScreen(projectId: project.id)));
                    case 'production':
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
                    case 'cost_report':
                      _openCostReport();
                    case 'history':
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectHistoryScreen(projectId: project.id)));
                    case 'versions':
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VersionListScreen(
                            projectId: project.id,
                            projectName: project.name,
                            projectApproved: project.status != ProjectStatus.quote && project.status != ProjectStatus.cancelled,
                          ),
                        ),
                      );
                      if (mounted) _refreshProject();
                    case 'survey':
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SurveyScreen(
                            projectId: project.id,
                            projectName: project.name,
                            catalog: _catalog,
                          ),
                        ),
                      );
                      if (mounted) _refreshProject();
                    case 'offline':
                      await _makeOfflineAvailable(project.id);
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: ListTile(leading: Icon(Icons.edit), title: Text('Proje Bilgileri'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'offline',
                    child: ListTile(leading: Icon(Icons.offline_pin), title: Text('Çevrimdışı kullanılabilir yap'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'versions',
                    child: ListTile(leading: Icon(Icons.history_edu), title: Text('Sürümler'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'survey',
                    child: ListTile(leading: Icon(Icons.straighten), title: Text('Keşif'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'history',
                    child: ListTile(leading: Icon(Icons.history), title: Text('Geçmiş'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'specs',
                    child: ListTile(leading: Icon(Icons.assignment), title: Text('Teknik Özellikler'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'production',
                    child: ListTile(leading: Icon(Icons.precision_manufacturing), title: Text('Üretim'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'cost',
                    child: ListTile(leading: Icon(Icons.price_check), title: Text('Maliyet / Özet'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'cost_report',
                    child: ListTile(leading: Icon(Icons.analytics_outlined), title: Text('İç maliyet raporu'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'export',
                    child: ListTile(leading: Icon(Icons.download), title: Text('Dışa aktar (.iwd)'), contentPadding: EdgeInsets.zero),
                  ),
                  const PopupMenuItem<String>(
                    value: 'sync_prices',
                    child: ListTile(leading: Icon(Icons.sync, color: Colors.orange), title: Text('Fiyatları Güncelle'), contentPadding: EdgeInsets.zero),
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
          backgroundColor: Brand.background,
          body: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _statusStrip(project)),
              if (project.priceChangedAfterApproval)
                SliverToBoxAdapter(
                  child: Material(
                    color: Colors.amber.shade100,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(Icons.warning_amber, color: Colors.orange),
                      title: Text(
                        'Onaydan sonra fiyat değişti: onaylanan ${formatMoney(project.approvedTotal ?? 0)}, güncel ${formatMoney(project.displaySaleTotal)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: _projectSummary(project)),
              SliverToBoxAdapter(child: _paymentsSection(project)),
              if (project.windowUnits.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: Text('Henüz pencere yok.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 260,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 0.72,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final unit = project.windowUnits[index];
                        return InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _openEditor(unit.id, unit.name),
                          onLongPress: () => _showWindowActions(unit),
                          onSecondaryTap: () => _showWindowActions(unit),
                          child: DesignThumbnail.unit(unit, catalog: _catalog),
                        );
                      },
                      childCount: project.windowUnits.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 88)),
            ],
          ),
        );
      },
    );
  }
}
