import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../drawing/glass_look.dart';
import '../../models/catalog.dart';
import '../../services/auth_service.dart';
import '../../services/catalog_admin_api.dart';
import '../../services/design_api.dart';
import '../../services/pdf_service.dart' hide hardwareKindTr;

/// Katalog ve fiyat yönetimi: profil, cam, aksesuar, donanım kuralları.
class CatalogScreen extends StatefulWidget {
  final CatalogAdminApi? api;
  const CatalogScreen({super.key, this.api});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> with SingleTickerProviderStateMixin {
  late final CatalogAdminApi _api = widget.api ?? CatalogAdminApi();
  late final TabController _tabs = TabController(length: 4, vsync: this);

  CatalogSnapshot? _snap;
  List<HardwareRule> _rules = [];
  bool _loading = true;
  String? _error;
  bool _showInactive = false;
  String _query = '';
  bool _isAdmin = false;

  static const _wide = 900.0;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final role = await AuthService().getRole();
    if (mounted) setState(() => _isAdmin = role == 'COMPANY_ADMIN');
    await _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final snap = await _api.snapshot();
      final rules = await _api.listHardwareRules();
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _rules = rules;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = ApiError.from(e).toString();
        _loading = false;
      });
    }
  }

  String _tl(num v) => '${formatMoney(v)} ₺';

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  Future<T?> _runWrite<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e) {
      if (mounted) _snack(ApiError.from(e).toString(), error: true);
      return null;
    }
  }

  bool _match(String q, Iterable<String?> fields) {
    if (q.isEmpty) return true;
    final n = q.toLowerCase();
    return fields.any((f) => (f ?? '').toLowerCase().contains(n));
  }

  Future<void> _bulkAdjust() async {
    if (!_isAdmin) {
      _snack('Bu işlem için yönetici yetkisi gerekiyor.', error: true);
      return;
    }
    String target = 'ALL';
    final pctCtrl = TextEditingController(text: '10');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Toplu zam'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              key: ValueKey('target-$target'),
              initialValue: target,
              decoration: const InputDecoration(labelText: 'Hedef', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'PROFILE', child: Text('Profiller')),
                DropdownMenuItem(value: 'GLASS', child: Text('Camlar')),
                DropdownMenuItem(value: 'ACCESSORY', child: Text('Aksesuarlar')),
                DropdownMenuItem(value: 'ALL', child: Text('Tümü')),
              ],
              onChanged: (v) => setLocal(() => target = v ?? 'ALL'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pctCtrl,
              keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
              decoration: const InputDecoration(
                labelText: 'Yüzde (−50 … 100)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^-?\d*[.,]?\d*'))],
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Devam')),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final pct = double.tryParse(pctCtrl.text.replaceAll(',', '.'));
    if (pct == null || pct < -50 || pct > 100) {
      _snack('Yüzde −50 ile 100 arasında olmalı.', error: true);
      return;
    }

    final dry = await _runWrite(() => _api.adjustPrices(target: target, percent: pct, dryRun: true));
    if (dry == null || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Onay'),
        content: Text('${dry.updated} kaydın fiyatı %${pct.toStringAsFixed(pct == pct.roundToDouble() ? 0 : 1)} değişecek. Uygulansın mı?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Uygula')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    final applied = await _runWrite(() => _api.adjustPrices(target: target, percent: pct, dryRun: false));
    if (applied == null || !mounted) return;
    _snack('${applied.updated} kayıt güncellendi.');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Katalog ve Fiyatlar'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Profiller'),
            Tab(text: 'Camlar'),
            Tab(text: 'Aksesuarlar'),
            Tab(text: 'Donanım'),
          ],
        ),
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Toplu zam',
              icon: const Icon(Icons.trending_up),
              onPressed: _loading ? null : _bulkAdjust,
            ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _reload,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton(onPressed: _reload, child: const Text('Tekrar dene')),
                    ]),
                  ),
                )
              : Column(children: [
                  _filterBar(),
                  Expanded(
                    child: TabBarView(controller: _tabs, children: [
                      _profilesTab(),
                      _glassesTab(),
                      _accessoriesTab(),
                      _hardwareTab(),
                    ]),
                  ),
                ]),
      floatingActionButton: _fab(),
    );
  }

  Widget? _fab() {
    if (!_isAdmin || _loading || _error != null) return null;
    return AnimatedBuilder(
      animation: _tabs,
      builder: (_, __) {
        if (_tabs.index == 1) {
          return FloatingActionButton.extended(
            onPressed: _newGlass,
            icon: const Icon(Icons.add),
            label: const Text('Yeni cam'),
          );
        }
        if (_tabs.index == 2) {
          return FloatingActionButton.extended(
            onPressed: _newAccessory,
            icon: const Icon(Icons.add),
            label: const Text('Yeni aksesuar'),
          );
        }
        if (_tabs.index == 3) {
          return FloatingActionButton.extended(
            onPressed: () => _editRule(null),
            icon: const Icon(Icons.add),
            label: const Text('Kural ekle'),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _filterBar() {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Ara (kod / ad)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v.trim()),
            ),
          ),
          const SizedBox(width: 12),
          FilterChip(
            label: const Text('Pasifleri göster'),
            selected: _showInactive,
            onSelected: (v) => setState(() => _showInactive = v),
          ),
        ]),
      ),
    );
  }

  // ---------- PROFİLLER ----------

  Widget _profilesTab() {
    final snap = _snap!;
    final items = snap.profiles
        .where((p) => _showInactive || p.isActive)
        .where((p) => _match(_query, [p.code, p.name, p.type]))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wide;
      if (wide) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Kod')),
              DataColumn(label: Text('Ad')),
              DataColumn(label: Text('Tür')),
              DataColumn(label: Text('Fiyat'), numeric: true),
              DataColumn(label: Text('Boy'), numeric: true),
              DataColumn(label: Text('Durum')),
            ],
            rows: [
              for (final p in items)
                DataRow(
                  onSelectChanged: _isAdmin ? (_) => _editProfile(p) : null,
                  color: p.isActive ? null : WidgetStatePropertyAll(Colors.grey.withValues(alpha: .12)),
                  cells: [
                    DataCell(Text(p.code, style: _dim(p.isActive))),
                    DataCell(Text(p.name, style: _dim(p.isActive))),
                    DataCell(Text(p.type, style: _dim(p.isActive))),
                    DataCell(Text(_tl(p.pricePerMeter), style: _dim(p.isActive))),
                    DataCell(Text(p.barLengthMm?.toString() ?? '—', style: _dim(p.isActive))),
                    DataCell(Text(p.isActive ? (p.isDefault ? 'Aktif · varsayılan' : 'Aktif') : 'Pasif',
                        style: _dim(p.isActive))),
                  ],
                ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final p = items[i];
          return Opacity(
            opacity: p.isActive ? 1 : .55,
            child: Card(
              child: ListTile(
                title: Text(p.name),
                subtitle: Text('${p.code} · ${p.type}'
                    '${p.barLengthMm != null ? ' · boy ${p.barLengthMm} mm' : ''}'
                    '${p.isDefault ? ' · varsayılan' : ''}'
                    '${p.isActive ? '' : ' · pasif'}'),
                trailing: Text(_tl(p.pricePerMeter), style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: _isAdmin ? () => _editProfile(p) : null,
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _editProfile(ProfileInfo p) async {
    final nameCtrl = TextEditingController(text: p.name);
    final priceCtrl = TextEditingController(text: p.pricePerMeter.toStringAsFixed(2));
    final barCtrl = TextEditingController(text: p.barLengthMm?.toString() ?? '6500');
    var active = p.isActive;
    var isDefault = p.isDefault;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('Profil: ${p.code}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fiyat (₺/m)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: barCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Boy (mm)', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Varsayılan'),
                value: isDefault,
                onChanged: (v) => setLocal(() => isDefault = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
    final bar = int.tryParse(barCtrl.text.trim());
    if (price == null || nameCtrl.text.trim().isEmpty) {
      _snack('Ad ve fiyat gerekli.', error: true);
      return;
    }
    final ok = await _runWrite(() => _api.updateProfile(
          p.id,
          name: nameCtrl.text.trim(),
          pricePerMeter: price,
          barLength: bar,
          isActive: active,
          isDefault: isDefault,
        ));
    if (ok != null) {
      _snack('Profil güncellendi.');
      await _reload();
    }
  }

  // ---------- CAMLAR ----------

  Widget _glassesTab() {
    final items = _snap!.glasses
        .where((g) => _showInactive || g.isActive)
        .where((g) => _match(_query, [g.code, g.name, g.visualStyle]))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wide;
      if (wide) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('')),
              DataColumn(label: Text('Kod')),
              DataColumn(label: Text('Ad')),
              DataColumn(label: Text('Kalınlık'), numeric: true),
              DataColumn(label: Text('Fiyat'), numeric: true),
              DataColumn(label: Text('Durum')),
            ],
            rows: [
              for (final g in items)
                DataRow(
                  onSelectChanged: _isAdmin ? (_) => _editGlass(g) : null,
                  color: g.isActive ? null : WidgetStatePropertyAll(Colors.grey.withValues(alpha: .12)),
                  cells: [
                    DataCell(GlassLook.forStyle(g.visualStyle).swatch(size: 18)),
                    DataCell(Text(g.code, style: _dim(g.isActive))),
                    DataCell(Text(g.name, style: _dim(g.isActive))),
                    DataCell(Text(g.thicknessMm?.toString() ?? '—', style: _dim(g.isActive))),
                    DataCell(Text('${_tl(g.pricePerSquareMeter)}/m²', style: _dim(g.isActive))),
                    DataCell(Text(g.isActive ? 'Aktif' : 'Pasif', style: _dim(g.isActive))),
                  ],
                ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final g = items[i];
          return Opacity(
            opacity: g.isActive ? 1 : .55,
            child: Card(
              child: ListTile(
                leading: GlassLook.forStyle(g.visualStyle).swatch(),
                title: Text(g.name),
                subtitle: Text('${g.code}'
                    '${g.thicknessMm != null ? ' · ${g.thicknessMm} mm' : ''}'
                    ' · ${GlassLook.styles[g.visualStyle] ?? g.visualStyle}'
                    '${g.isActive ? '' : ' · pasif'}'),
                trailing: Text('${_tl(g.pricePerSquareMeter)}/m²'),
                onTap: _isAdmin ? () => _editGlass(g) : null,
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _newGlass() => _editGlass(null);

  Future<void> _editGlass(GlassInfo? existing) async {
    final isNew = existing == null;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final thickCtrl = TextEditingController(text: existing?.thicknessMm?.toString() ?? '24');
    final priceCtrl = TextEditingController(text: (existing?.pricePerSquareMeter ?? 0).toStringAsFixed(2));
    var style = existing?.visualStyle ?? 'clear';
    var active = existing?.isActive ?? true;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isNew ? 'Yeni cam' : 'Cam: ${existing.code}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (isNew)
                TextField(
                  controller: codeCtrl,
                  decoration: const InputDecoration(labelText: 'Kod', border: OutlineInputBorder()),
                ),
              if (isNew) const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(
                controller: thickCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kalınlık (mm)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fiyat (₺/m²)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('style-$style'),
                initialValue: style,
                decoration: const InputDecoration(labelText: 'Görünüm', border: OutlineInputBorder()),
                items: [
                  for (final e in GlassLook.styles.entries)
                    DropdownMenuItem(
                      value: e.key,
                      child: Row(children: [
                        GlassLook.forStyle(e.key).swatch(size: 16),
                        const SizedBox(width: 8),
                        Text(e.value),
                      ]),
                    ),
                ],
                onChanged: (v) => setLocal(() => style = v ?? style),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: GlassLook.forStyle(style).swatch(size: 36),
              ),
              if (!isNew)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aktif'),
                  value: active,
                  onChanged: (v) => setLocal(() => active = v),
                ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
    final thick = int.tryParse(thickCtrl.text.trim());
    if (nameCtrl.text.trim().isEmpty || price == null) {
      _snack('Ad ve fiyat gerekli.', error: true);
      return;
    }
    if (isNew) {
      if (codeCtrl.text.trim().isEmpty) {
        _snack('Kod gerekli.', error: true);
        return;
      }
      final ok = await _runWrite(() => _api.createGlass(
            code: codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            thicknessMm: thick,
            visualStyle: style,
            pricePerSquareMeter: price,
          ));
      if (ok != null) {
        _snack('Cam eklendi.');
        await _reload();
      }
    } else {
      final ok = await _runWrite(() => _api.updateGlass(
            existing.id,
            name: nameCtrl.text.trim(),
            thicknessMm: thick,
            visualStyle: style,
            pricePerSquareMeter: price,
            isActive: active,
          ));
      if (ok != null) {
        _snack('Cam güncellendi.');
        await _reload();
      }
    }
  }

  // ---------- AKSESUARLAR ----------

  Widget _accessoriesTab() {
    final items = _snap!.accessories
        .where((a) => _showInactive || a.isActive)
        .where((a) => _match(_query, [a.code, a.name, a.unit]))
        .toList()
      ..sort((a, b) => a.code.compareTo(b.code));

    return LayoutBuilder(builder: (context, box) {
      final wide = box.maxWidth >= _wide;
      if (wide) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: DataTable(
            showCheckboxColumn: false,
            columns: const [
              DataColumn(label: Text('Kod')),
              DataColumn(label: Text('Ad')),
              DataColumn(label: Text('Birim')),
              DataColumn(label: Text('Fiyat'), numeric: true),
              DataColumn(label: Text('Durum')),
            ],
            rows: [
              for (final a in items)
                DataRow(
                  onSelectChanged: _isAdmin ? (_) => _editAccessory(a) : null,
                  color: a.isActive ? null : WidgetStatePropertyAll(Colors.grey.withValues(alpha: .12)),
                  cells: [
                    DataCell(Text(a.code, style: _dim(a.isActive))),
                    DataCell(Text(a.name, style: _dim(a.isActive))),
                    DataCell(Text(accessoryUnitTr(a.unit), style: _dim(a.isActive))),
                    DataCell(Text(_tl(a.price), style: _dim(a.isActive))),
                    DataCell(Text(a.isActive ? 'Aktif' : 'Pasif', style: _dim(a.isActive))),
                  ],
                ),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) {
          final a = items[i];
          return Opacity(
            opacity: a.isActive ? 1 : .55,
            child: Card(
              child: ListTile(
                title: Text(a.name),
                subtitle: Text('${a.code} · ${accessoryUnitTr(a.unit)}${a.isActive ? '' : ' · pasif'}'),
                trailing: Text(_tl(a.price)),
                onTap: _isAdmin ? () => _editAccessory(a) : null,
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _newAccessory() => _editAccessory(null);

  Future<void> _editAccessory(Accessory? existing) async {
    final isNew = existing == null;
    final codeCtrl = TextEditingController(text: existing?.code ?? '');
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(text: (existing?.price ?? 0).toStringAsFixed(2));
    var unit = existing?.unit ?? 'PIECE';
    var active = existing?.isActive ?? true;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(isNew ? 'Yeni aksesuar' : 'Aksesuar: ${existing.code}'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Kod', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Ad', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('unit-$unit'),
                initialValue: unit,
                decoration: const InputDecoration(labelText: 'Birim', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'PIECE', child: Text('Adet')),
                  DropdownMenuItem(value: 'METER', child: Text('Metre')),
                  DropdownMenuItem(value: 'SET', child: Text('Takım')),
                ],
                onChanged: (v) => setLocal(() => unit = v ?? unit),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: priceCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Fiyat (₺)', border: OutlineInputBorder()),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Aktif'),
                value: active,
                onChanged: (v) => setLocal(() => active = v),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    final price = double.tryParse(priceCtrl.text.replaceAll(',', '.'));
    if (codeCtrl.text.trim().isEmpty || nameCtrl.text.trim().isEmpty || price == null) {
      _snack('Kod, ad ve fiyat gerekli.', error: true);
      return;
    }
    if (isNew) {
      final ok = await _runWrite(() => _api.createAccessory(
            code: codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            unit: unit,
            price: price,
            isActive: active,
          ));
      if (ok != null) {
        _snack('Aksesuar eklendi.');
        await _reload();
      }
    } else {
      final ok = await _runWrite(() => _api.updateAccessory(
            existing.id,
            code: codeCtrl.text.trim(),
            name: nameCtrl.text.trim(),
            unit: unit,
            price: price,
            isActive: active,
          ));
      if (ok != null) {
        _snack('Aksesuar güncellendi.');
        await _reload();
      }
    }
  }

  // ---------- DONANIM ----------

  Widget _hardwareTab() {
    const kinds = ['TURN', 'TILT', 'TILT_TURN', 'SLIDE'];
    final filtered = _rules.where((r) => _match(_query, [r.accessoryCode, r.accessoryName, r.kind, hardwareKindTr(r.kind)])).toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final kind in kinds) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(hardwareKindTr(kind), style: Theme.of(context).textTheme.titleMedium),
          ),
          ...filtered.where((r) => r.kind == kind).map((r) {
            return Card(
              child: ListTile(
                title: Text(r.accessoryName?.isNotEmpty == true ? r.accessoryName! : r.accessoryCode),
                subtitle: Text('${r.accessoryCode} · ${hardwareQtyTypeTr(r.qtyType, r.qty)}'),
                trailing: _isAdmin
                    ? Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editRule(r)),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteRule(r),
                        ),
                      ])
                    : null,
                onTap: _isAdmin ? () => _editRule(r) : null,
              ),
            );
          }),
          if (filtered.where((r) => r.kind == kind).isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Kural yok.', style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ],
    );
  }

  Future<void> _deleteRule(HardwareRule r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kuralı sil'),
        content: Text('${hardwareKindTr(r.kind)} · ${r.accessoryName ?? r.accessoryCode} silinsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final done = await _runWrite(() async {
      await _api.deleteHardwareRule(r.id);
      return true;
    });
    if (done == true) {
      _snack('Kural silindi.');
      await _reload();
    }
  }

  Future<void> _editRule(HardwareRule? existing) async {
    final activeAcc = _snap!.accessories.where((a) => a.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (activeAcc.isEmpty) {
      _snack('Aktif aksesuar yok. Önce aksesuar ekleyin.', error: true);
      return;
    }
    var kind = existing?.kind ?? 'TURN';
    var qtyType = existing?.qtyType ?? 'PER_SASH';
    var code = existing?.accessoryCode ?? activeAcc.first.code;
    if (!activeAcc.any((a) => a.code == code)) code = activeAcc.first.code;
    final qtyCtrl = TextEditingController(text: (existing?.qty ?? 1).toString());

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null ? 'Donanım kuralı ekle' : 'Kuralı düzenle'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                key: ValueKey('kind-$kind'),
                initialValue: kind,
                decoration: const InputDecoration(labelText: 'Tür', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'TURN', child: Text('Açılır')),
                  DropdownMenuItem(value: 'TILT', child: Text('Vasistas')),
                  DropdownMenuItem(value: 'TILT_TURN', child: Text('Çift açılım')),
                  DropdownMenuItem(value: 'SLIDE', child: Text('Sürme')),
                ],
                onChanged: (v) => setLocal(() => kind = v ?? kind),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('acc-$code'),
                initialValue: code,
                decoration: const InputDecoration(labelText: 'Aksesuar', border: OutlineInputBorder()),
                items: [
                  for (final a in activeAcc) DropdownMenuItem(value: a.code, child: Text('${a.name} (${a.code})')),
                ],
                onChanged: (v) => setLocal(() => code = v ?? code),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                key: ValueKey('qty-$qtyType'),
                initialValue: qtyType,
                decoration: const InputDecoration(labelText: 'Miktar tipi', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'PER_SASH', child: Text('Kanat başına')),
                  DropdownMenuItem(value: 'PER_PERIMETER_METER', child: Text('Çevre metresi başına')),
                ],
                onChanged: (v) => setLocal(() => qtyType = v ?? qtyType),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: qtyCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Miktar', border: OutlineInputBorder()),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
          ],
        ),
      ),
    );
    if (save != true || !mounted) return;
    final qty = double.tryParse(qtyCtrl.text.replaceAll(',', '.'));
    if (qty == null || qty <= 0) {
      _snack('Miktar 0\'dan büyük olmalı.', error: true);
      return;
    }
    if (existing == null) {
      final ok = await _runWrite(() => _api.createHardwareRule(
            kind: kind,
            accessoryCode: code,
            qtyType: qtyType,
            qty: qty,
          ));
      if (ok != null) {
        _snack('Kural eklendi.');
        await _reload();
      }
    } else {
      final ok = await _runWrite(() => _api.updateHardwareRule(
            existing.id,
            kind: kind,
            seriesId: existing.seriesId,
            accessoryCode: code,
            qtyType: qtyType,
            qty: qty,
          ));
      if (ok != null) {
        _snack('Kural güncellendi.');
        await _reload();
      }
    }
  }

  TextStyle? _dim(bool active) => active ? null : TextStyle(color: Colors.grey.shade600);
}
