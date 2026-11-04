import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/company.dart';
import '../services/company_api.dart';
import '../services/design_api.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _api = CompanyApi();

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _taxOffice = TextEditingController();
  final _taxNumber = TextEditingController();
  final _vat = TextEditingController();
  final _discount = TextEditingController();
  final _currency = TextEditingController();
  final _validity = TextEditingController();
  final _note = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _readOnly = false;
  String? _error;
  int? _id;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _taxOffice.dispose();
    _taxNumber.dispose();
    _vat.dispose();
    _discount.dispose();
    _currency.dispose();
    _validity.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final c = await _api.getCompany();
      if (!mounted) return;
      _apply(c);
      setState(() {
        _loading = false;
        _readOnly = false;
      });
    } catch (e) {
      if (!mounted) return;
      final err = ApiError.from(e);
      setState(() {
        _loading = false;
        _error = err.message;
        if (err.status == 403) _readOnly = true;
      });
    }
  }

  void _apply(CompanyProfile c) {
    _id = c.id;
    _name.text = c.name;
    _address.text = c.address ?? '';
    _phone.text = c.phone ?? '';
    _email.text = c.email ?? '';
    _taxOffice.text = c.taxOffice ?? '';
    _taxNumber.text = c.taxNumber ?? '';
    _vat.text = _num(c.vatRate);
    _discount.text = _num(c.defaultDiscountPct);
    _currency.text = c.currency;
    _validity.text = '${c.quoteValidityDays}';
    _note.text = c.quoteNote ?? '';
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _save() async {
    if (_readOnly || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final profile = CompanyProfile(
      id: _id,
      name: _name.text.trim(),
      address: _opt(_address.text),
      phone: _opt(_phone.text),
      email: _opt(_email.text),
      taxOffice: _opt(_taxOffice.text),
      taxNumber: _opt(_taxNumber.text),
      vatRate: double.parse(_vat.text.replaceAll(',', '.')),
      defaultDiscountPct: double.parse(_discount.text.replaceAll(',', '.')),
      currency: _currency.text.trim().toUpperCase(),
      quoteValidityDays: int.parse(_validity.text.trim()),
      quoteNote: _opt(_note.text),
    );
    try {
      final saved = await _api.updateCompany(profile);
      if (!mounted) return;
      _apply(saved);
      setState(() {
        _saving = false;
        _readOnly = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firma bilgileri kaydedildi.')));
    } catch (e) {
      if (!mounted) return;
      final err = ApiError.from(e);
      setState(() {
        _saving = false;
        if (err.status == 403) _readOnly = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.status == 403 ? 'Sadece firma yöneticisi değiştirebilir.' : err.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static String? _opt(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firma Bilgileri'),
        actions: [
          if (!_readOnly)
            TextButton(
              onPressed: _saving || _loading ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Kaydet'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_readOnly)
                          Card(
                            color: Colors.orange.shade50,
                            child: const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text('Sadece firma yöneticisi değiştirebilir.'),
                            ),
                          ),
                        if (_error != null && !_readOnly)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Text(_error!, style: const TextStyle(color: Colors.red)),
                          ),
                        _field(_name, 'Firma adı *', enabled: !_readOnly, validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Firma adı gerekli.';
                          if (v.trim().length > 200) return 'En fazla 200 karakter.';
                          return null;
                        }),
                        _field(_address, 'Adres', enabled: !_readOnly, maxLines: 3, maxLen: 500),
                        _field(_phone, 'Telefon', enabled: !_readOnly, maxLen: 40),
                        _field(_email, 'E-posta', enabled: !_readOnly, keyboard: TextInputType.emailAddress,
                            validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return null;
                          if (t.length > 200) return 'En fazla 200 karakter.';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t)) return 'Geçerli bir e-posta girin.';
                          return null;
                        }),
                        _field(_taxOffice, 'Vergi dairesi', enabled: !_readOnly, maxLen: 120),
                        _field(_taxNumber, 'Vergi no', enabled: !_readOnly, maxLen: 50),
                        Row(children: [
                          Expanded(
                            child: _field(_vat, 'KDV %', enabled: !_readOnly, keyboard: TextInputType.number,
                                validator: _pctValidator),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(_discount, 'Varsayılan iskonto %', enabled: !_readOnly,
                                keyboard: TextInputType.number, validator: _pctValidator),
                          ),
                        ]),
                        Row(children: [
                          Expanded(
                            child: _field(_currency, 'Para birimi *', enabled: !_readOnly, validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Para birimi gerekli.';
                              if (v.trim().length > 8) return 'En fazla 8 karakter.';
                              return null;
                            }),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _field(_validity, 'Teklif geçerlilik (gün) *', enabled: !_readOnly,
                                keyboard: TextInputType.number, validator: (v) {
                              final n = int.tryParse(v?.trim() ?? '');
                              if (n == null) return 'Geçerli bir gün girin.';
                              if (n < 1 || n > 365) return '1–365 arası olmalı.';
                              return null;
                            }),
                          ),
                        ]),
                        _field(_note, 'Teklif notu', enabled: !_readOnly, maxLines: 4, maxLen: 2000),
                        if (!_readOnly) ...[
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _saving ? null : _save,
                            child: const Text('Kaydet'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  String? _pctValidator(String? v) {
    final n = double.tryParse((v ?? '').replaceAll(',', '.'));
    if (n == null) return 'Sayı girin.';
    if (n < 0 || n > 100) return '0–100 arası olmalı.';
    return null;
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool enabled = true,
    int maxLines = 1,
    int? maxLen,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        enabled: enabled,
        maxLines: maxLines,
        maxLength: maxLen,
        keyboardType: keyboard,
        inputFormatters: keyboard == TextInputType.number
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))]
            : null,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          counterText: maxLen != null ? null : '',
        ),
        validator: validator ??
            (maxLen == null
                ? null
                : (v) {
                    if ((v ?? '').length > maxLen) return 'En fazla $maxLen karakter.';
                    return null;
                  }),
      ),
    );
  }
}
