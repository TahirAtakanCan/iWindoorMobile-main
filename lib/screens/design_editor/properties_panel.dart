import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:windoor_core/windoor_core.dart';

import '../../drawing/glass_look.dart';
import 'design_controller.dart';

/// Sağ panel (masaüstü) / alt sayfa (telefon): pencere ve seçili alan özellikleri.
class PropertiesPanel extends StatelessWidget {
  final DesignController c;
  const PropertiesPanel({super.key, required this.c});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final fill = c.selectedFill;
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _Section(title: 'Pencere', children: [
              _TextField(label: 'Poz adı', value: c.name, onSubmitted: c.setName),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _NumField(
                    label: 'Genişlik (mm)',
                    value: c.design.width,
                    onSubmitted: (v) => c.setSize(width: v),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _NumField(
                    label: 'Yükseklik (mm)',
                    value: c.design.height,
                    onSubmitted: (v) => c.setSize(height: v),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: _NumField(
                    label: 'Adet',
                    value: c.quantity.toDouble(),
                    onSubmitted: (v) => c.setQuantity(v.round()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _SeriesDropdown(c: c)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final col in ProfileColor.all)
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: col.fill, radius: 8),
                    label: Text(col.label),
                    selected: c.design.colorCode == col.code,
                    onSelected: (_) => c.setColor(col.code),
                  ),
              ]),
            ]),
            if (fill == null)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text('Düzenlemek için çizimde bir cam alanına dokunun.'),
              )
            else ...[
              _PartSizes(c: c),
              _Section(title: 'Cam / dolgu', children: [
                _GlassPicker(c: c, fill: fill),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    icon: const Icon(Icons.select_all, size: 18),
                    label: const Text('Bu camı tüm camlara uygula'),
                    onPressed: fill.fill == FillType.glass && fill.glassCode.isNotEmpty
                        ? () => c.setGlassEverywhere(fill.glassCode)
                        : null,
                  ),
                ),
              ]),
              if (fill.fill == FillType.glass)
                _Section(title: 'Dubleks (cam içi çıta)', children: [
                  Row(children: [
                    Expanded(
                      child: _Stepper(
                        label: 'Sütun',
                        value: fill.duplexCols,
                        onChanged: (v) => c.setDuplex(cols: v),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _Stepper(
                        label: 'Satır',
                        value: fill.duplexRows,
                        onChanged: (v) => c.setDuplex(rows: v),
                      ),
                    ),
                  ]),
                ]),
            ],
          ],
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...children,
      ]),
    );
  }
}

class _SeriesDropdown extends StatelessWidget {
  final DesignController c;
  const _SeriesDropdown({required this.c});

  @override
  Widget build(BuildContext context) {
    final items = c.catalog.series;
    final current = items.any((s) => s.id == c.seriesId) ? c.seriesId : null;
    return DropdownButtonFormField<int>(
      key: ValueKey(current),
      initialValue: current,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Seri', border: OutlineInputBorder(), isDense: true),
      items: [for (final s in items) DropdownMenuItem(value: s.id, child: Text(s.name, overflow: TextOverflow.ellipsis))],
      onChanged: (v) {
        if (v != null) c.setSeries(v);
      },
    );
  }
}

/// Seçili alanın bulunduğu bölmenin parça ölçüleri (iWindoor'daki zincir ölçü düzenleme).
class _PartSizes extends StatelessWidget {
  final DesignController c;
  const _PartSizes({required this.c});

  @override
  Widget build(BuildContext context) {
    final info = c.partInfo;
    if (info == null) return const SizedBox.shrink();
    final (split, sizes, index) = info;
    final vertical = split.dir == SplitDir.v;
    return _Section(title: vertical ? 'Bölme genişlikleri' : 'Bölme yükseklikleri', children: [
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var i = 0; i < sizes.length; i++)
          SizedBox(
            width: 104,
            child: _NumField(
              key: ValueKey('${split.id}-$i'),
              label: '${i + 1}${i == index ? ' (seçili)' : ''}',
              value: sizes[i],
              onSubmitted: (v) => c.setPartSize(split.id, i, v),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text('Ölçüler kasa dışı / kayıt ekseninden. Fark komşu parçaya aktarılır.',
          style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _GlassPicker extends StatelessWidget {
  final DesignController c;
  final FillNode fill;
  const _GlassPicker({required this.c, required this.fill});

  @override
  Widget build(BuildContext context) {
    final selected = c.catalog.glassByCode(fill.glassCode);
    final glasses = [
      for (final g in c.catalog.glasses)
        if (g.isActive || g.code == fill.glassCode) g,
    ];
    if (glasses.isEmpty) {
      return const Text('Katalogda cam yok. Sunucu bağlantısını kontrol edin.');
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(children: [
      for (final g in glasses)
        Material(
          color: g.code == fill.glassCode ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: () => c.setGlass(g.code),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(children: [
                Opacity(
                  opacity: g.isActive ? 1 : .55,
                  child: GlassLook.forStyle(g.visualStyle).swatch(),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      g.isActive ? g.name : '${g.name} (pasif)',
                      overflow: TextOverflow.ellipsis,
                      style: g.isActive ? null : TextStyle(color: scheme.onSurface.withValues(alpha: .7)),
                    ),
                    Text(
                      '${g.code}${g.thicknessMm != null ? ' · ${g.thicknessMm} mm' : ''} · '
                      '${GlassLook.styles[g.visualStyle] ?? g.visualStyle}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ]),
                ),
                Text('${g.pricePerSquareMeter.toStringAsFixed(0)} TL/m²', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
          ),
        ),
      if (selected != null && !selected.isActive && !glasses.any((g) => g.code == selected.code))
        Text('Seçili cam pasif: ${selected.name}', style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  const _Stepper({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true),
      child: Row(children: [
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove),
          onPressed: value > 1 ? () => onChanged(value - 1) : null,
        ),
        Expanded(child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed: value < 12 ? () => onChanged(value + 1) : null,
        ),
      ]),
    );
  }
}

/// Enter'a basınca ya da odaktan çıkınca değeri bildirir. Dışarıdan değer değişirse metni günceller.
class _NumField extends StatefulWidget {
  final String label;
  final double value;
  final ValueChanged<double> onSubmitted;
  const _NumField({super.key, required this.label, required this.value, required this.onSubmitted});

  @override
  State<_NumField> createState() => _NumFieldState();
}

class _NumFieldState extends State<_NumField> {
  late final TextEditingController _ctl = TextEditingController(text: _fmt(widget.value));
  final FocusNode _focus = FocusNode();

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) _submit();
    });
  }

  @override
  void didUpdateWidget(covariant _NumField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _ctl.text = _fmt(widget.value);
  }

  void _submit() {
    final v = double.tryParse(_ctl.text.replaceAll(',', '.'));
    if (v == null) {
      _ctl.text = _fmt(widget.value);
      return;
    }
    if ((v - widget.value).abs() > 0.05) widget.onSubmitted(v);
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctl,
      focusNode: _focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder(), isDense: true),
      onSubmitted: (_) => _submit(),
    );
  }
}

class _TextField extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onSubmitted;
  const _TextField({required this.label, required this.value, required this.onSubmitted});

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctl = TextEditingController(text: widget.value);
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onSubmitted(_ctl.text);
    });
  }

  @override
  void didUpdateWidget(covariant _TextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && old.value != widget.value) _ctl.text = widget.value;
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctl,
        focusNode: _focus,
        decoration: InputDecoration(labelText: widget.label, border: const OutlineInputBorder(), isDense: true),
        onSubmitted: widget.onSubmitted,
      );
}
