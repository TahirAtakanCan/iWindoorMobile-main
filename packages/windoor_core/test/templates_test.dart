import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

void main() {
  const series = SeriesGeometry(id: '1');
  final engine = LayoutEngine(series);
  final templates = builtInTemplates();

  test('yerleşik şablon sayısı ve kategoriler', () {
    expect(templates.length, greaterThanOrEqualTo(8));
    expect(templates.map((t) => t.id).toSet().length, templates.length);
    expect(templates.any((t) => t.category == 'DOOR'), isTrue);
    expect(templates.any((t) => t.category == 'SLIDING'), isTrue);
  });

  test('her şablon varsayılan ölçüde LayoutEngine + checkDesign hatasız; id benzersiz; JSON gidiş-dönüş', () {
    for (final t in templates) {
      final d = t.build(t.defaultWidth, t.defaultHeight, '1');
      final layout = engine.run(d);
      final issues = checkDesign(layout, series);
      expect(issues.any((i) => i.isError), isFalse, reason: t.name);
      final ids = DesignOps.walk(d.root).map((n) => n.id).toList();
      expect(ids.toSet().length, ids.length, reason: t.name);
      expect(WindowDesign.fromJson(d.toJson()).toJson(), d.toJson(), reason: t.name);
    }
  });

  test('şablon 7: 2 SLIDE donanımı', () {
    final t = templates.firstWhere((x) => x.id == 'builtin-7');
    final bom = engine.run(t.build(t.defaultWidth, t.defaultHeight, '1')).bom;
    final slides = bom.where((b) => b.group == BomGroup.hardware && b.kind == 'SLIDE').toList();
    expect(slides.length, 2);
  });

  test('şablon 8: PANEL satırı ve TILT_TURN donanımı', () {
    final t = templates.firstWhere((x) => x.id == 'builtin-8');
    final bom = engine.run(t.build(t.defaultWidth, t.defaultHeight, '1')).bom;
    expect(bom.any((b) => b.group == BomGroup.panel), isTrue);
    expect(bom.any((b) => b.group == BomGroup.hardware && b.kind == 'TILT_TURN'), isTrue);
  });

  test('applyTemplateDesign ölçü ve seriyi değiştirir, yapıyı korur', () {
    final t = templates.first;
    final base = t.build(t.defaultWidth, t.defaultHeight, '1');
    final applied = applyTemplateDesign(base, 1111, 2222, '9');
    expect(applied.width, 1111);
    expect(applied.height, 2222);
    expect(applied.seriesId, '9');
    expect(applied.root.toJson(), base.root.toJson());
  });

  test('yerleşik şablonlarda glassCode boş; fillMissingCodes doldurur', () {
    for (final t in templates) {
      final d = t.build(t.defaultWidth, t.defaultHeight, '1');
      for (final f in DesignOps.fills(d.root)) {
        expect(f.glassCode, isEmpty, reason: '${t.name} ${f.id}');
      }
      final filled = DesignOps.fillMissingCodes(d, glass: '4+16+4', panel: 'PANEL-W');
      for (final f in DesignOps.fills(filled.root)) {
        expect(f.glassCode, isNotEmpty, reason: '${t.name} ${f.id}');
        if (f.fill == FillType.panel) {
          expect(f.glassCode, 'PANEL-W', reason: '${t.name} ${f.id}');
        } else {
          expect(f.glassCode, '4+16+4', reason: '${t.name} ${f.id}');
        }
      }
    }
    final t8 = templates.firstWhere((x) => x.id == 'builtin-8');
    final panels = DesignOps.fills(DesignOps.fillMissingCodes(
      t8.build(t8.defaultWidth, t8.defaultHeight, '1'),
      glass: '4+16+4',
      panel: 'PANEL-W',
    ).root)
        .where((f) => f.fill == FillType.panel);
    expect(panels, isNotEmpty);
    expect(panels.every((f) => f.glassCode == 'PANEL-W'), isTrue);
  });

  test('replaceUnknownCodes bilineni korur, bilinmeyeni değiştirir', () {
    final d = WindowDesign(
      width: 1000,
      height: 1000,
      root: SplitNode(id: 'n1', dir: SplitDir.v, sizes: const [1, 1], children: [
        const FillNode(id: 'n2', glassCode: '4+16+4'),
        const FillNode(id: 'n3', fill: FillType.panel, glassCode: 'ESKI-PANEL'),
      ]),
    );
    final out = DesignOps.replaceUnknownCodes(
      d,
      {'4+16+4'},
      {'PANEL-W'},
      glass: '4+16+4',
      panel: 'PANEL-W',
    );
    final fills = DesignOps.fills(out.root);
    expect(fills.firstWhere((f) => f.id == 'n2').glassCode, '4+16+4');
    expect(fills.firstWhere((f) => f.id == 'n3').glassCode, 'PANEL-W');
  });
}
