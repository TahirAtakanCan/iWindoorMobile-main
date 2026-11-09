import 'package:flutter/material.dart';

import '../../models/customer.dart';
import '../../services/customer_api.dart';
import '../../services/design_api.dart';

/// Müşteri seç / yeni oluştur. Seçilen müşteriyi döner.
Future<Customer?> pickCustomer(BuildContext context, {Customer? current}) async {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CustomerPickerSheet(current: current),
  );
}

class _CustomerPickerSheet extends StatefulWidget {
  final Customer? current;
  const _CustomerPickerSheet({this.current});

  @override
  State<_CustomerPickerSheet> createState() => _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends State<_CustomerPickerSheet> {
  final _api = CustomerApi();
  final _q = TextEditingController();
  List<Customer> _items = [];
  bool _loading = true;

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
    setState(() => _loading = true);
    try {
      final list = await _api.listCustomers(q: _q.text);
      if (!mounted) return;
      setState(() {
        _items = list;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni müşteri'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad *', border: OutlineInputBorder())),
          const SizedBox(height: 8),
          TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefon', border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
        ],
      ),
    );
    if (ok != true || name.text.trim().isEmpty) return;
    try {
      final c = await _api.createCustomer(Customer(id: 0, name: name.text.trim(), phone: phone.text.trim().isEmpty ? null : phone.text.trim()));
      if (!mounted) return;
      Navigator.pop(context, c);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiError.from(e).toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height * 0.7;
    return SizedBox(
      height: h,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _q,
                  decoration: const InputDecoration(hintText: 'Ara…', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(onPressed: _create, child: const Text('Yeni')),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (_, i) {
                      final c = _items[i];
                      return ListTile(
                        title: Text(c.name),
                        subtitle: Text(c.phone ?? ''),
                        selected: widget.current?.id == c.id,
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
