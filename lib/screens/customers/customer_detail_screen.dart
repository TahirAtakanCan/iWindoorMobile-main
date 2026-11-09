import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/customer.dart';
import '../../models/project.dart';
import '../../services/api_service.dart';
import '../../services/customer_api.dart';
import '../../services/design_api.dart';
import '../../utils/format.dart';
import '../../widgets/status_badge.dart';
import '../project_detail_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final _api = CustomerApi();
  final _projectsApi = ApiService();
  Customer? _customer;
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await _api.getCustomer(widget.customerId);
      final projects = await _projectsApi.getAllProjects(customerId: widget.customerId);
      if (!mounted) return;
      setState(() {
        _customer = c;
        _projects = projects;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ApiError.from(e).toString();
      });
    }
  }

  Future<void> _edit() async {
    final c = _customer;
    if (c == null) return;
    final name = TextEditingController(text: c.name);
    final phone = TextEditingController(text: c.phone ?? '');
    final email = TextEditingController(text: c.email ?? '');
    final address = TextEditingController(text: c.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi düzenle'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad *', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'E-posta', border: OutlineInputBorder())),
            const SizedBox(height: 8),
            TextField(controller: address, maxLines: 2, decoration: const InputDecoration(labelText: 'Adres', border: OutlineInputBorder())),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _api.updateCustomer(
        c.id,
        c.copyWith(
          name: name.text.trim(),
          phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
          email: email.text.trim().isEmpty ? null : email.text.trim(),
          address: address.text.trim().isEmpty ? null : address.text.trim(),
        ),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _delete() async {
    final c = _customer;
    if (c == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi sil'),
        content: Text('"${c.name}" silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteCustomer(c.id);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      final err = ApiError.from(e);
      if (!mounted) return;
      final msg = err.code == 'CUSTOMER_IN_USE' || err.message.contains('projeleri')
          ? 'Bu müşterinin projeleri var.'
          : err.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
    }
  }

  Future<void> _newProject() async {
    final c = _customer;
    if (c == null) return;
    final nameCtrl = TextEditingController(text: '${c.name} projesi');
    final descCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni proje'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Müşteri: ${c.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Proje adı *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Açıklama', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Oluştur')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final p = await _projectsApi.createProject(
      nameCtrl.text.trim(),
      descCtrl.text.trim(),
      customerId: c.id,
      customerName: c.name,
      customerPhone: c.phone,
      customerEmail: c.email,
      customerAddress: c.address,
    );
    if (!mounted) return;
    if (p != null) {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(c?.name ?? 'Müşteri'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: c == null ? null : _edit),
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: c == null ? null : _delete),
        ],
      ),
      floatingActionButton: c == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _newProject,
              icon: const Icon(Icons.add),
              label: const Text('Yeni proje'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : c == null
                  ? const SizedBox.shrink()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text([
                              if ((c.phone ?? '').isNotEmpty) c.phone!,
                              if ((c.email ?? '').isNotEmpty) c.email!,
                              if ((c.address ?? '').isNotEmpty) c.address!,
                            ].join('\n')),
                            trailing: (c.phone ?? '').isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.copy),
                                    onPressed: () async {
                                      await Clipboard.setData(ClipboardData(text: c.phone!));
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Telefon kopyalandı.')),
                                        );
                                      }
                                    },
                                  )
                                : null,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text('Projeler', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (_projects.isEmpty)
                          const Text('Proje yok.', style: TextStyle(color: Colors.grey))
                        else
                          ..._projects.map((p) => Card(
                                child: ListTile(
                                  title: Text(p.name),
                                  subtitle: Text('${formatMoney(p.displaySaleTotal)}${p.balance > 0 ? ' · Kalan ${formatMoney(p.balance)}' : ''}'),
                                  trailing: StatusBadge(status: p.status, compact: true),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ProjectDetailScreen(projectId: p.id)),
                                    );
                                    _load();
                                  },
                                ),
                              )),
                      ],
                    ),
    );
  }
}
