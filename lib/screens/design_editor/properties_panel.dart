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
              _ColorPicker(c: c),
              if (!c.isCoupled) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<BottomKind>(
                  key: ValueKey(c.design.bottom),
                  initialValue: c.design.bottom,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Alt profil', border: OutlineInputBorder(), isDense: true),
                  items: const [
                    DropdownMenuItem(value: BottomKind.frame, child: Text('Kasa')),
                    DropdownMenuItem(value: BottomKind.threshold, child: Text('Eşik')),
                  ],
                  onChanged: (v) {
                    if (v != null) c.setBottom(v);
                  },
                ),
              ],
              const SizedBox(height: 10),
              _ShapeProps(c: c),
            ]),
            _FramesSection(c: c),
            if (c.selectedSlide != null) _SlideProps(c: c),
            if (c.selectedSash != null) _SashProps(c: c),
            if (c.selectedSplitIsAdapterCandidate) _JointProps(c: c),
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

class _ColorPicker extends StatelessWidget {
  final DesignController c;
  const _ColorPicker({required this.c});

  @override
  Widget build(BuildContext context) {
    final catalogColors = c.catalog.colors.where((x) => x.isActive).toList();
    final items = <(String code, String label, Color fill)>[
      if (catalogColors.isEmpty)
        for (final p in ProfileColor.all) (p.code, p.label, p.fill)
      else
        for (final col in catalogColors)
          (col.code, '${col.name} · %${col.surchargePct == col.surchargePct.roundToDouble() ? col.surchargePct.toStringAsFixed(0) : col.surchargePct.toStringAsFixed(1)}', ProfileColor.fromHex(col.code, col.name, col.hexOutside).fill),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final (code, label, fill) in items)
        ChoiceChip(
          avatar: CircleAvatar(backgroundColor: fill, radius: 8),
          label: Text(label, overflow: TextOverflow.ellipsis),
          selected: c.design.colorCode == code,
          onSelected: (_) => c.setColor(code),
        ),
    ]);
  }
}

class _FramesSection extends StatelessWidget {
  final DesignController c;
  const _FramesSection({required this.c});

  @override
  Widget build(BuildContext context) {
    final couple = c.design.root is CoupleNode ? c.design.root as CoupleNode : null;
    return _Section(title: 'Kasalar', children: [
      if (couple == null)
        Text(
          'Tek kasa: ${c.design.width.round()} × ${c.design.height.round()} · '
          '${c.design.bottom == BottomKind.threshold ? 'Eşik' : 'Kasa'}',
          style: Theme.of(context).textTheme.bodyMedium,
        )
      else
        for (var i = 0; i < couple.children.length; i++)
          _FrameTile(c: c, index: i, frame: couple.children[i], sizeMm: couple.sizes[i], dir: couple.dir),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: () => _promptAdd(context, DesignOps.sideLeft), child: const Text('Sola kasa ekle')),
        OutlinedButton(onPressed: () => _promptAdd(context, DesignOps.sideRight), child: const Text('Sağa kasa ekle')),
        OutlinedButton(onPressed: () => _promptAdd(context, DesignOps.sideTop), child: const Text('Üste kasa ekle')),
      ]),
    ]);
  }

  Future<void> _promptAdd(BuildContext context, String side) async {
    final sizeCtrl = TextEditingController(text: '900');
    final heightCtrl = TextEditingController(text: c.design.height.round().toString());
    var bottom = BottomKind.frame;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Kasa ekle'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: sizeCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: side == DesignOps.sideTop || side == DesignOps.sideBottom ? 'Yükseklik (mm)' : 'Genişlik (mm)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (side == DesignOps.sideLeft || side == DesignOps.sideRight) ...[
              const SizedBox(height: 10),
              TextField(
                controller: heightCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Kasa yüksekliği (mm, boş=tam)', border: OutlineInputBorder()),
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<BottomKind>(
              initialValue: bottom,
              decoration: const InputDecoration(labelText: 'Alt', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: BottomKind.frame, child: Text('Kasa')),
                DropdownMenuItem(value: BottomKind.threshold, child: Text('Eşik')),
              ],
              onChanged: (v) => setLocal(() => bottom = v ?? bottom),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final size = double.tryParse(sizeCtrl.text.replaceAll(',', '.'));
    if (size == null || size < 300) return;
    final h = double.tryParse(heightCtrl.text.replaceAll(',', '.'));
    c.addFrame(side, size, height: h, bottom: bottom);
  }
}

class _FrameTile extends StatelessWidget {
  final DesignController c;
  final int index;
  final FrameNode frame;
  final double sizeMm;
  final SplitDir dir;
  const _FrameTile({required this.c, required this.index, required this.frame, required this.sizeMm, required this.dir});

  @override
  Widget build(BuildContext context) {
    final w = dir == SplitDir.v ? sizeMm : (frame.width ?? c.design.width);
    final h = dir == SplitDir.h ? sizeMm : (frame.height ?? c.design.height);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Kasa ${index + 1}: ${w.round()} × ${h.round()} · ${frame.bottom == BottomKind.threshold ? 'Eşik' : 'Kasa'}',
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _NumField(
                label: 'Genişlik',
                value: w,
                onSubmitted: (v) => c.setFrameSize(frame.id, widthMm: v),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _NumField(
                label: 'Yükseklik',
                value: h,
                onSubmitted: (v) => c.setFrameSize(frame.id, heightMm: v),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: DropdownButtonFormField<BottomKind>(
                key: ValueKey('${frame.id}-${frame.bottom}'),
                initialValue: frame.bottom,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Alt', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: BottomKind.frame, child: Text('Kasa')),
                  DropdownMenuItem(value: BottomKind.threshold, child: Text('Eşik')),
                ],
                onChanged: (v) {
                  if (v != null) c.setFrameBottom(frame.id, v);
                },
              ),
            ),
            IconButton(
              tooltip: 'Sil',
              onPressed: () => c.removeFrame(frame.id),
              icon: const Icon(Icons.delete_outline),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _ShapeProps extends StatefulWidget {
  final DesignController c;
  const _ShapeProps({required this.c});

  @override
  State<_ShapeProps> createState() => _ShapePropsState();
}

class _ShapePropsState extends State<_ShapeProps> {
  final _rise = TextEditingController();
  final _hl = TextEditingController();
  final _hr = TextEditingController();

  @override
  void dispose() {
    _rise.dispose();
    _hl.dispose();
    _hr.dispose();
    super.dispose();
  }

  String _kindOf(FrameShape s) => switch (s) {
        RectShape _ => 'rect',
        ArchShape _ => 'arch',
        SegmentArchShape _ => 'segment',
        TrapezoidShape _ => 'trap',
        TriangleShape _ => 'tri',
      };

  void _apply(FrameShape shape) {
    final err = widget.c.setShape(shape);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final shape = c.activeShape;
    final kind = _kindOf(shape);
    if (shape is SegmentArchShape && _rise.text.isEmpty) {
      _rise.text = shape.rise.round().toString();
    }
    if (shape is TrapezoidShape) {
      if (_hl.text.isEmpty) _hl.text = shape.leftHeight.round().toString();
      if (_hr.text.isEmpty) _hr.text = shape.rightHeight.round().toString();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Şekil', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ChoiceChip(
              label: const Text('Dikdörtgen'),
              selected: kind == 'rect',
              onSelected: (_) => _apply(const RectShape()),
            ),
            ChoiceChip(
              label: const Text('Kemer'),
              selected: kind == 'arch',
              onSelected: (_) => _apply(const ArchShape()),
            ),
            ChoiceChip(
              label: const Text('Basık kemer'),
              selected: kind == 'segment',
              onSelected: (_) {
                final rise = double.tryParse(_rise.text) ?? 200;
                _apply(SegmentArchShape(rise: rise));
              },
            ),
            ChoiceChip(
              label: const Text('Eğik üst'),
              selected: kind == 'trap',
              onSelected: (_) {
                final hl = double.tryParse(_hl.text) ?? c.design.height;
                final hr = double.tryParse(_hr.text) ?? c.design.height * 0.7;
                _apply(TrapezoidShape(leftHeight: hl, rightHeight: hr));
              },
            ),
            ChoiceChip(
              label: const Text('Üçgen'),
              selected: kind == 'tri',
              onSelected: (_) => _apply(const TriangleShape()),
            ),
          ],
        ),
        if (kind == 'segment') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _rise,
            decoration: const InputDecoration(labelText: 'Yay yüksekliği (mm)', border: OutlineInputBorder(), isDense: true),
            keyboardType: TextInputType.number,
            onSubmitted: (v) {
              final rise = double.tryParse(v);
              if (rise != null) _apply(SegmentArchShape(rise: rise));
            },
          ),
        ],
        if (kind == 'trap') ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _hl,
                decoration: const InputDecoration(labelText: 'Sol yükseklik', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                onSubmitted: (_) {
                  final hl = double.tryParse(_hl.text) ?? c.design.height;
                  final hr = double.tryParse(_hr.text) ?? c.design.height * 0.7;
                  _apply(TrapezoidShape(leftHeight: hl, rightHeight: hr));
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _hr,
                decoration: const InputDecoration(labelText: 'Sağ yükseklik', border: OutlineInputBorder(), isDense: true),
                keyboardType: TextInputType.number,
                onSubmitted: (_) {
                  final hl = double.tryParse(_hl.text) ?? c.design.height;
                  final hr = double.tryParse(_hr.text) ?? c.design.height * 0.7;
                  _apply(TrapezoidShape(leftHeight: hl, rightHeight: hr));
                },
              ),
            ),
          ]),
        ],
        if (kind == 'tri') ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<TriangleApex>(
            key: ValueKey('apex-${shape is TriangleShape ? shape.apex : TriangleApex.center}'),
            initialValue: shape is TriangleShape ? shape.apex : TriangleApex.center,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Tepe', border: OutlineInputBorder(), isDense: true),
            items: const [
              DropdownMenuItem(value: TriangleApex.left, child: Text('Sol')),
              DropdownMenuItem(value: TriangleApex.center, child: Text('Orta')),
              DropdownMenuItem(value: TriangleApex.right, child: Text('Sağ')),
            ],
            onChanged: (v) {
              if (v != null) _apply(TriangleShape(apex: v));
            },
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.architecture, size: 18),
          label: const Text('Kemerli üst ekle'),
          onPressed: () {
            final err = c.addArchTop();
            if (err != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            }
          },
        ),
      ],
    );
  }
}

class _SashProps extends StatelessWidget {
  final DesignController c;
  const _SashProps({required this.c});

  @override
  Widget build(BuildContext context) {
    final sash = c.selectedSash!;
    final inAdapter = c.selectedSplit?.joint == JointKind.adapter;
    return _Section(title: 'Kanat', children: [
      DropdownButtonFormField<SashKind>(
        key: ValueKey('kind-${sash.id}-${sash.kind}'),
        initialValue: sash.kind,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Kanat tipi', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: SashKind.window, child: Text('Pencere')),
          DropdownMenuItem(value: SashKind.door, child: Text('Kapı')),
        ],
        onChanged: (v) {
          if (v != null) c.setSashKind(v);
        },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<bool>(
        key: ValueKey('out-${sash.id}-${sash.outward}'),
        initialValue: sash.outward,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Açılım', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: false, child: Text('İçe')),
          DropdownMenuItem(value: true, child: Text('Dışa')),
        ],
        onChanged: (v) {
          if (v != null) c.setOutward(v);
        },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<ScreenKind?>(
        key: ValueKey('screen-${sash.id}-${sash.screen}'),
        initialValue: sash.screen,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sineklik', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: null, child: Text('Yok')),
          DropdownMenuItem(value: ScreenKind.plise, child: Text('Pileli')),
          DropdownMenuItem(value: ScreenKind.hinged, child: Text('Menteşeli')),
          DropdownMenuItem(value: ScreenKind.sliding, child: Text('Sürme')),
        ],
        onChanged: c.setScreen,
      ),
      if (inAdapter) ...[
        const SizedBox(height: 6),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Pasif kanat'),
          value: sash.passive,
          onChanged: (v) {
            if (v && !sash.passive) c.setPassive();
          },
        ),
      ],
    ]);
  }
}

class _SlideProps extends StatelessWidget {
  final DesignController c;
  const _SlideProps({required this.c});

  @override
  Widget build(BuildContext context) {
    final slide = c.selectedSlide!;
    return _Section(title: 'Sürme', children: [
      DropdownButtonFormField<int>(
        key: ValueKey('pc-${slide.id}-${slide.panels.length}'),
        initialValue: slide.panels.length.clamp(2, 6),
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Kanat sayısı', border: OutlineInputBorder(), isDense: true),
        items: [for (var n = 2; n <= 6; n++) DropdownMenuItem(value: n, child: Text('$n'))],
        onChanged: (v) {
          if (v != null) c.setSlidePanelCount(v);
        },
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<SlideSystem>(
        key: ValueKey('sys-${slide.id}-${slide.system}'),
        initialValue: slide.system,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Sistem', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: SlideSystem.standard, child: Text('Standart')),
          DropdownMenuItem(value: SlideSystem.liftSlide, child: Text('Kaldır-sür')),
        ],
        onChanged: (v) {
          if (v != null) c.setSlideSystem(v);
        },
      ),
      const SizedBox(height: 12),
      for (var i = 0; i < slide.panels.length; i++) ...[
        Text('Panel ${i + 1}', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: [
            for (final m in SlideMove.values)
              ChoiceChip(
                label: Text(switch (m) {
                  SlideMove.left => 'Sola',
                  SlideMove.right => 'Sağa',
                  SlideMove.fixed => 'Sabit',
                }),
                selected: slide.panels[i].move == m,
                onSelected: (_) => c.setSlidePanelMove(i, m),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<ScreenKind?>(
          key: ValueKey('ps-${slide.id}-$i-${slide.panels[i].screen}'),
          initialValue: slide.panels[i].screen,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Sineklik (panel ${i + 1})',
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Yok')),
            DropdownMenuItem(value: ScreenKind.plise, child: Text('Pileli')),
            DropdownMenuItem(value: ScreenKind.hinged, child: Text('Menteşeli')),
            DropdownMenuItem(value: ScreenKind.sliding, child: Text('Sürme')),
          ],
          onChanged: (v) => c.setSlidePanelScreen(i, v),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _JointProps extends StatelessWidget {
  final DesignController c;
  const _JointProps({required this.c});

  @override
  Widget build(BuildContext context) {
    final sp = c.selectedSplit!;
    return _Section(title: 'Birleşim', children: [
      DropdownButtonFormField<JointKind>(
        key: ValueKey('joint-${sp.id}-${sp.joint}'),
        initialValue: sp.joint,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Birleşim', border: OutlineInputBorder(), isDense: true),
        items: const [
          DropdownMenuItem(value: JointKind.mullion, child: Text('Orta kayıt')),
          DropdownMenuItem(value: JointKind.adapter, child: Text('Orta kayıtsız (adaptör)')),
        ],
        onChanged: (v) {
          if (v == null) return;
          final err = c.setJoint(v);
          if (err != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
          }
        },
      ),
    ]);
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
