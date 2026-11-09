import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

FillNode _g(String id) => FillNode(id: id, glassCode: '4+16+4');

void main() {
  const series = SeriesGeometry(id: '1');
  final engine = LayoutEngine(series);

  test('birleşik 2100×2200 BOM ölçüleri', () {
    final d = WindowDesign(
      width: 2100,
      height: 2200,
      root: CoupleNode(
        id: 'c1',
        dir: SplitDir.v,
        sizes: const [900, 1200],
        children: [
          FrameNode(id: 'f1', bottom: BottomKind.threshold, child: _g('g1')),
          FrameNode(id: 'f2', height: 1400, child: _g('g2')),
        ],
      ),
    );
    final lines = BomLine.aggregate(engine.run(d).bom);

    expect(lines.any((l) => l.role == ProfileRole.frame && l.length == 906 && l.cut == '45/45' && l.qty == 1), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.frame && l.length == 2203 && l.cut == '45/90' && l.qty == 2), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.threshold && l.length == 776 && l.qty == 1), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.frame && l.length == 1206 && l.qty == 2), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.frame && l.length == 1406 && l.qty == 2), isTrue);
    expect(lines.any((l) => l.role == ProfileRole.coupling && l.length == 1400 && l.cut == '90/90' && l.qty == 1), isTrue);

    final glasses = lines.where((l) => l.group == BomGroup.glass).toList();
    expect(glasses.any((g) => g.w == 804 && g.h == 2146 && g.qty == 1), isTrue);
    expect(glasses.any((g) => g.w == 1104 && g.h == 1304 && g.qty == 1), isTrue);
  });

  test('colorCode ANT-1 → COLOR satırı; white → yok', () {
    final colored = WindowDesign.single(1000, 1200).copyWith(colorCode: 'ANT-1');
    final bomC = BomLine.aggregate(engine.run(colored).bom);
    expect(bomC.where((l) => l.group == BomGroup.color).length, 1);
    expect(bomC.singleWhere((l) => l.group == BomGroup.color).colorCode, 'ANT-1');
    expect(bomC.singleWhere((l) => l.group == BomGroup.color).toJson()['group'], 'COLOR');

    final white = WindowDesign.single(1000, 1200);
    expect(engine.run(white).bom.any((l) => l.group == BomGroup.color), isFalse);
  });

  test('couple JSON gidiş-dönüş', () {
    final d = WindowDesign(
      width: 2100,
      height: 2200,
      root: CoupleNode(
        id: 'c1',
        dir: SplitDir.v,
        sizes: const [900, 1200],
        children: [
          FrameNode(id: 'f1', bottom: BottomKind.threshold, child: _g('g1')),
          FrameNode(id: 'f2', height: 1400, child: _g('g2')),
        ],
      ),
    );
    expect(d.schemaVersion, 2);
    expect(WindowDesign.fromJson(d.toJson()).toJson(), d.toJson());
  });

  test('addFrame / removeFrame: tek → couple → tek', () {
    final base = WindowDesign.single(900, 2200, glassCode: '4+16+4');
    final added = DesignOps.addFrame(base, DesignOps.sideRight, 1200, height: 1400);
    expect(added.error, isNull);
    final couple = added.design.root;
    expect(couple, isA<CoupleNode>());
    expect(added.design.width, 2100);
    expect(added.design.height, 2200);
    final c = couple as CoupleNode;
    expect(c.sizes, [900.0, 1200.0]);
    expect(c.children.length, 2);
    expect(c.children[1].height, 1400);

    final back = DesignOps.removeFrame(added.design, c.children[1].id);
    expect(back.design.root, isA<FillNode>());
    expect(back.design.width, 900);
    expect(back.design.height, 2200);
  });
}
