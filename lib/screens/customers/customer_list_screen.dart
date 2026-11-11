import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/customer.dart';
import '../../services/customer_api.dart';
import '../../services/design_api.dart';
import '../../utils/format.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final _api = CustomerApi();
  final _q = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.listCustomers(q: _q.text);
      if (!mounted) return;
      setState(() {
        _items = list;
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

  Future<void> _edit([Customer? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final email = TextEditingController(text: existing?.email ?? '');
    final address = TextEditingController(text: existing?.address ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? 'Yeni müşteri' : 'Müşteriyi düzenle'),
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
    if (name.text.trim().isEmpty) return;
    final c = Customer(
      id: existing?.id ?? 0,
      name: name.text.trim(),
      phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
      email: email.text.trim().isEmpty ? null : email.text.trim(),
      address: address.text.trim().isEmpty ? null : address.text.trim(),
    );
    try {
      if (existing == null) {
        await _api.createCustomer(c);
      } else {
        await _api.updateCustomer(existing.id, c);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Müşteriler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Yeni'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _q,
                decoration: InputDecoration(
                  hintText: 'Ad veya telefon ara…',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(hasScrollBody: false, child: Center(child: Text(_error!)))
          else if (_items.isEmpty)
            const SliverFillRemaining(hasScrollBody: false, child: Center(child: Text('Müşteri yok.')))
          else
            SliverList.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final c = _items[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: Text([
                    if ((c.phone ?? '').isNotEmpty) c.phone!,
                    '${c.projectCount} proje',
                    if (c.balanceTotal > 0) 'Bakiye ${formatMoney(c.balanceTotal)}',
                  ].join(' · ')),
                  trailing: (c.phone ?? '').isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.copy),
                          tooltip: 'Telefonu kopyala',
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
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => CustomerDetailScreen(customerId: c.id)),
                    );
                    _load();
                  },
                );
              },
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 88)),
        ],
      ),
    );
  }
}
