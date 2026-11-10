import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

const series = SeriesGeometry(id: 'test');

BomLine? _bar(
  List<BomLine> bom, {
  BomGroup? group,
  ProfileRole? role,
  bool? bent,
  String? cut,
}) {
  for (final b in bom) {
    if (group != null && b.group != group) continue;
    if (role != null && b.role != role) continue;
    if (bent != null && b.bent != bent) continue;
    if (cut != null && b.cut != cut) continue;
    if (b.length == null) continue;
    return b;
  }
  return null;
}

bool _near(double a, double b, [double eps = 0.2]) => (a - b).abs() <= eps;

void main() {
  final engine = LayoutEngine(series);

  test('kemer 1000×1500 tek cam — kasa ve çıta BOM', () {
    final d = WindowDesign(
      width: 1000,
      height: 1500,
      shape: const ArchShape(),
      root: FillNode(id: 'g1', glassCode: '4+16+4'),
    );
    final lines = engine.run(d).bom;

    expect(_bar(lines, role: ProfileRole.frame, bent: false, cut: '45/45')!.length, closeTo(1006, 0.1));
    expect(_bar(lines, role: ProfileRole.frame, bent: false, cut: '45/90')!.length, closeTo(1003, 0.1));
    expect(_bar(lines, role: ProfileRole.frame, bent: true)!.length, closeTo(1576.8, 0.2));
    expect(_bar(lines, role: ProfileRole.frame, bent: true)!.radius, closeTo(500, 0.1));

    final beadBent = _bar(lines, group: BomGroup.bead, bent: true);
    expect(beadBent, isNotNull);
    expect(beadBent!.group, BomGroup.bead);
    expect(beadBent.length, closeTo(1376.0, 0.2));
    expect(beadBent.radius, closeTo(438, 0.1));

    final glass = lines.firstWhere((l) => l.group == BomGroup.glass);
    expect(glass.w, closeTo(904, 0.1));
    expect(glass.h, closeTo(1404, 0.1));
    expect(glass.shape, 'arch');
  });

  test('eğik üst 1000 sol 1500 sağ 1000 — gönyeler', () {
    final d = WindowDesign(
      width: 1000,
      height: 1500,
      shape: const TrapezoidShape(leftHeight: 1500, rightHeight: 1000),
      root: FillNode(id: 'g1', glassCode: ''),
    );
    final lines = engine.run(d).bom;
    final frames = lines.where((l) => l.role == ProfileRole.frame && l.isBar).toList();
    expect(frames.any((l) => _near(l.length!, 1006) && l.cut == '45/45'), isTrue);
    expect(frames.any((l) => _near(l.length!, 1506) && l.cut == '45/31.7'), isTrue);
    expect(frames.any((l) => _near(l.length!, 1006) && l.cut == '45/58.3'), isTrue);
    expect(frames.any((l) => _near(l.length!, 1124.0) && l.cut == '31.7/58.3'), isTrue);
  });

  test('üçgen 1200×600 orta tepe — kasa gönyeleri', () {
    final d = WindowDesign(
      width: 1200,
      height: 600,
      shape: const TriangleShape(apex: TriangleApex.center),
      root: FillNode(id: 'g1', glassCode: ''),
    );
    final lines = engine.run(d).bom;
    final frames = lines.where((l) => l.role == ProfileRole.frame && l.isBar).toList();
    expect(frames.any((l) => _near(l.length!, 1206) && l.cut == '22.5/22.5'), isTrue);
    final slants = frames.where((l) => l.cut == '22.5/45').toList();
    expect(slants.length, 1);
    expect(slants.first.length, closeTo(854.5, 0.2));
    expect(slants.first.qty, 2);
  });

  test('kemerli şablon: donanım + şekilli cam, kural hatası yok', () {
    final t = builtInTemplates().firstWhere((x) => x.id == 'builtin-17');
    final d = t.build(1200, 1900, '1');
    final layout = engine.run(d);
    final issues = checkDesign(layout, series, d);
    expect(issues.where((i) => i.isError), isEmpty);
    expect(layout.bom.any((l) => l.kind == 'TILT_TURN'), isTrue);
    expect(layout.bom.any((l) => l.kind == 'PASSIVE'), isTrue);
    expect(layout.bom.any((l) => l.shape == 'arch'), isTrue);
  });

  test('şekilli bölgede kanat → HATA', () {
    final d = WindowDesign(
      width: 1000,
      height: 1500,
      shape: const ArchShape(),
      root: SashNode(id: 's', opening: OpeningType.turnLeft, child: FillNode(id: 'g', glassCode: '')),
    );
    final issues = checkDesign(engine.run(d), series, d);
    expect(issues.any((i) => i.isError && i.message.contains('kanat')), isTrue);
  });

  test('dikdörtgen tasarım schemaVersion 1', () {
    final d = WindowDesign(width: 1000, height: 1200, root: FillNode(id: 'g', glassCode: ''));
    expect(d.schemaVersion, 1);
    expect(d.toJson().containsKey('shape'), isFalse);
  });

  test('şekilli tasarım schemaVersion 2', () {
    final d = WindowDesign(
      width: 1000,
      height: 1500,
      shape: const ArchShape(),
      root: FillNode(id: 'g', glassCode: ''),
    );
    expect(d.schemaVersion, 2);
    expect(d.toJson()['shape'], {'type': 'arch'});
  });

  test('dikdörtgen BOM değişmez', () {
    final d = WindowDesign(width: 1000, height: 1200, root: FillNode(id: 'g', glassCode: '4+16+4'));
    final lines = engine.run(d).bom;
    final frameLens = lines.where((l) => l.role == ProfileRole.frame).map((l) => l.length).toSet();
    expect(frameLens, {1006.0, 1206.0});
  });

  test('hit test çokgen', () {
    final d = WindowDesign(
      width: 1200,
      height: 600,
      shape: const TriangleShape(apex: TriangleApex.center),
      root: FillNode(id: 'g', glassCode: ''),
    );
    final r = engine.run(d);
    expect(r.hitTest(600, 450), 'g');
    expect(r.hitTest(50, 50), isNull);
  });

  test('kemer H split [600,1300]: üst çıta kiriş+yay, cam arch', () {
    final d = WindowDesign(
      width: 1200,
      height: 1900,
      shape: const ArchShape(),
      root: SplitNode(
        id: 'sp',
        dir: SplitDir.h,
        sizes: const [600, 1300],
        children: [
          FillNode(id: 'top', glassCode: 'TOP'),
          FillNode(id: 'bot', glassCode: 'BOT'),
        ],
      ),
    );
    final layout = engine.run(d);
    final topBeads = layout.bom.where((l) => l.group == BomGroup.bead && l.glassCode == 'TOP').toList();
    final topGlass = layout.bom.where((l) => l.group == BomGroup.glass && l.shape == 'arch').toList();
    expect(topGlass, isNotEmpty);
    expect(topGlass.first.w, closeTo(1104, 0.2));
    expect(topGlass.first.h, closeTo(526, 0.2));

    final chord = topBeads.where((l) => !l.bent && l.length != null && _near(l.length!, 1073.0, 0.5));
    final arc = topBeads.where((l) => l.bent && l.radius != null && _near(l.radius!, 538, 0.2));
    expect(chord.length, 1);
    expect(chord.first.cut, '42.9/42.9');
    expect(arc.length, 1);
    expect(arc.first.length, closeTo(1610.1, 0.3));
    expect(arc.first.cut, '42.9/42.9');
    expect(topBeads.where((l) => !l.bent && l != chord.first), isEmpty);
    expect(topBeads.length, 2);
  });

  test('kemer H split [800,1100]: yan çıtalar + kemer kırpık clip', () {
    final d = WindowDesign(
      width: 1200,
      height: 1900,
      shape: const ArchShape(),
      root: SplitNode(
        id: 'sp',
        dir: SplitDir.h,
        sizes: const [800, 1100],
        children: [
          FillNode(id: 'top', glassCode: 'A'),
          FillNode(id: 'bot', glassCode: 'B'),
        ],
      ),
    );
    final layout = engine.run(d);
    final topBeads = layout.bom.where((l) => l.group == BomGroup.bead && l.glassCode == 'A').toList();
    expect(topBeads.any((l) => !l.bent && _near(l.length!, 1076) && l.cut == '45/45'), isTrue);
    final sides = topBeads.where((l) => !l.bent && _near(l.length!, 160) && (l.cut == '45/90' || l.cut == '90/45'));
    expect(sides.length, 2);
    final arc = topBeads.where((l) => l.bent && _near(l.radius!, 538, 0.2));
    expect(arc.length, 1);
    expect(arc.first.length, closeTo(1690.2, 0.3));
    expect(arc.first.cut, '90/90');

    final glass = layout.bom.firstWhere((l) => l.group == BomGroup.glass && l.shape == 'arch');
    expect(glass.w, closeTo(1104, 0.2));
    expect(glass.h, closeTo(726, 0.2));

    final gPrim = layout.prims.whereType<GlassPrim>().firstWhere((g) => g.nodeId == 'top');
    expect(gPrim.clip, isNotNull);
    expect(gPrim.clip!.length, greaterThan(4));
  });

  test('eğik üst H split: üst çıta 4 kenar, tam boy çıta yok', () {
    final d = WindowDesign(
      width: 1000,
      height: 1500,
      shape: const TrapezoidShape(leftHeight: 1500, rightHeight: 1000),
      root: SplitNode(
        id: 'sp',
        dir: SplitDir.h,
        sizes: const [1100, 400],
        children: [
          FillNode(id: 'top', glassCode: 'T'),
          FillNode(id: 'bot', glassCode: 'B'),
        ],
      ),
    );
    final layout = engine.run(d);
    final topBeads = layout.bom.where((l) => l.group == BomGroup.bead && l.glassCode == 'T').toList();
    expect(topBeads.length, 4);
    expect(topBeads.any((l) => !l.bent && _near(l.length!, 876)), isTrue);
    expect(topBeads.any((l) => l.length != null && l.length! >= 1400), isFalse);
    expect(layout.bom.any((l) => l.group == BomGroup.glass && l.shape == 'trapezoid'), isTrue);
  });
}
