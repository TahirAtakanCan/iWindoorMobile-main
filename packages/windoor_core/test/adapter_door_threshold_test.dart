import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

FillNode _g(String id) => FillNode(id: id, glassCode: '4+16+4');

void main() {
  const series = SeriesGeometry(id: '1');
  final engine = LayoutEngine(series);

  test('orta kayıtsız 1400×1400 BOM ölçüleri', () {
    final d = WindowDesign(
      width: 1400,
      height: 1400,
      root: SplitNode(
        id: 'n1',
        dir: SplitDir.v,
        sizes: const [1, 1],
        joint: JointKind.adapter,
        children: [
          SashNode(id: 'n2', opening: OpeningType.turnLeft, passive: true, child: _g('n3')),
          SashNode(id: 'n4', opening: OpeningType.tiltTurnRight, child: _g('n5')),
        ],
      ),
    );
    final lines = BomLine.aggregate(engine.run(d).bom);

    BomLine? bar(ProfileRole role, double len) {
      for (final l in lines) {
        if (l.role == role && l.length == len) return l;
      }
      return null;
    }

    expect(bar(ProfileRole.frame, 1406)?.qty, 4);
    expect(bar(ProfileRole.sash, 652)?.qty, 4);
    expect(bar(ProfileRole.sash, 1298)?.qty, 4);
    expect(lines.where((l) => l.role == ProfileRole.mullion), isEmpty);
    expect(bar(ProfileRole.adapter, 1292)?.qty, 1);

    final glass = lines.where((l) => l.group == BomGroup.glass).toList();
    expect(glass.length, 1);
    expect(glass.single.w, 518);
    expect(glass.single.h, 1164);
    expect(glass.single.qty, 2);

    expect(lines.where((l) => l.group == BomGroup.bead && l.length == 490).single.qty, 4);
    expect(lines.where((l) => l.group == BomGroup.bead && l.length == 1136).single.qty, 4);

    final hw = lines.where((l) => l.group == BomGroup.hardware).toList();
    expect(hw.any((l) => l.kind == 'PASSIVE' && l.w == 646 && l.h == 1292 && l.qty == 1), isTrue);
    expect(hw.any((l) => l.kind == 'TILT_TURN' && l.w == 646 && l.h == 1292 && l.qty == 1), isTrue);
  });

  test('eşikli kapı 900×2100 BOM ölçüleri', () {
    final d = WindowDesign(
      width: 900,
      height: 2100,
      bottom: BottomKind.threshold,
      root: SashNode(id: 'n1', kind: SashKind.door, opening: OpeningType.turnRight, child: _g('n2')),
    );
    final lines = BomLine.aggregate(engine.run(d).bom);

    expect(
      lines.any((l) => l.role == ProfileRole.frame && l.length == 906 && l.cut == '45/45' && l.qty == 1),
      isTrue,
    );
    expect(
      lines.any((l) => l.role == ProfileRole.frame && l.length == 2103 && l.cut == '45/90' && l.qty == 2),
      isTrue,
    );
    expect(
      lines.any((l) => l.role == ProfileRole.threshold && l.length == 776 && l.cut == '90/90' && l.qty == 1),
      isTrue,
    );
    expect(lines.any((l) => l.role == ProfileRole.doorSash && l.length == 798 && l.qty == 2), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.doorSash && l.length == 2040 && l.qty == 2), isTrue);

    final glass = lines.where((l) => l.group == BomGroup.glass).single;
    expect(glass.w, 600);
    expect(glass.h, 1842);
    expect(glass.qty, 1);

    expect(lines.where((l) => l.group == BomGroup.bead && l.length == 572).single.qty, 2);
    expect(lines.where((l) => l.group == BomGroup.bead && l.length == 1814).single.qty, 2);

    final hw = lines.where((l) => l.group == BomGroup.hardware).single;
    expect(hw.kind, 'DOOR');
    expect(hw.w, 792);
    expect(hw.h, 2034);
  });

  test('JSON: yeni özellik yoksa schemaVersion 1; varsa 2 ve gidiş-dönüş', () {
    final plain = WindowDesign.single(1000, 1200);
    final j1 = plain.toJson();
    expect(j1['schemaVersion'], 1);
    expect(j1.containsKey('bottom'), isFalse);
    expect(j1['root'].containsKey('joint'), isFalse);
    expect(WindowDesign.fromJson(j1).toJson(), j1);

    final rich = WindowDesign(
      width: 900,
      height: 2100,
      bottom: BottomKind.threshold,
      root: SashNode(
        id: 'n1',
        kind: SashKind.door,
        opening: OpeningType.turnRight,
        outward: true,
        child: _g('n2'),
      ),
    );
    final j2 = rich.toJson();
    expect(j2['schemaVersion'], 2);
    expect(j2['bottom'], 'threshold');
    expect(j2['root']['kind'], 'door');
    expect(j2['root']['outward'], true);
    expect(WindowDesign.fromJson(j2).toJson(), j2);
  });

  test('kurallar: kapı kanadı + tilt → hata; adaptörde iki pasif → hata', () {
    final doorTilt = WindowDesign(
      width: 900,
      height: 2100,
      bottom: BottomKind.threshold,
      root: SashNode(id: 'n1', kind: SashKind.door, opening: OpeningType.tilt, child: _g('n2')),
    );
    final doorIssues = checkDesign(engine.run(doorTilt), series, doorTilt);
    expect(doorIssues.any((i) => i.isError && i.message.contains('vasistas')), isTrue);

    final twoPassive = WindowDesign(
      width: 1400,
      height: 1400,
      root: SplitNode(
        id: 'n1',
        dir: SplitDir.v,
        sizes: const [1, 1],
        joint: JointKind.adapter,
        children: [
          SashNode(id: 'n2', opening: OpeningType.turnLeft, passive: true, child: _g('n3')),
          SashNode(id: 'n4', opening: OpeningType.turnRight, passive: true, child: _g('n5')),
        ],
      ),
    );
    final adapterIssues = checkDesign(engine.run(twoPassive), series, twoPassive);
    expect(adapterIssues.any((i) => i.isError && i.message.contains('pasif')), isTrue);
  });
}
