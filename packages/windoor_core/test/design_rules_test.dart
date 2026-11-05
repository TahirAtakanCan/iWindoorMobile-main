import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

FillNode _g(String id) => FillNode(id: id, glassCode: '4+16+4');

WindowDesign _sample() => WindowDesign(
      width: 1800,
      height: 1700,
      seriesId: '1',
      root: SplitNode(id: 'n1', dir: SplitDir.h, sizes: [400, 1300], children: [
        SplitNode(id: 'n2', dir: SplitDir.v, sizes: [600, 600, 600], children: [_g('n3'), _g('n4'), _g('n5')]),
        SplitNode(id: 'n6', dir: SplitDir.v, sizes: [600, 600, 600], children: [
          _g('n7'),
          SashNode(id: 'n8', opening: OpeningType.tiltTurnLeft, child: _g('n9')),
          _g('n10'),
        ]),
      ]),
    );

void main() {
  const series = SeriesGeometry(id: '1');
  final engine = LayoutEngine(series);

  test('örnek 1800×1700 pencerede uyarı yok', () {
    final r = engine.run(_sample());
    expect(checkDesign(r, series), isEmpty);
  });

  test('büyük tek kanatlı pencere → genişlik ve yükseklik uyarıları', () {
    // so.h > maxSashHeight için dış yükseklik 2600 (2500'de so.h=2392 kalır).
    final d = WindowDesign(
      width: 3000,
      height: 2600,
      root: SashNode(id: 's', opening: OpeningType.turnLeft, child: _g('g1')),
    );
    final issues = checkDesign(engine.run(d), series);
    expect(issues.where((i) => !i.isError).length, greaterThanOrEqualTo(2));
    expect(issues.any((i) => i.message.contains('Kanat genişliği') && i.message.contains('1400')), isTrue);
    expect(issues.any((i) => i.message.contains('Kanat yüksekliği') && i.message.contains('2400')), isTrue);
  });

  test('4000×2500 tek sabit cam → alan uyarısı', () {
    final d = WindowDesign.single(4000, 2500);
    final issues = checkDesign(engine.run(d), series);
    expect(issues.any((i) => !i.isError && i.message.contains('m²') && i.message.contains('6.00')), isTrue);
  });

  test('400×400 dikey 3\'e bölünmüş pencere → hata', () {
    final d = WindowDesign(
      width: 400,
      height: 400,
      root: SplitNode(id: 's', dir: SplitDir.v, sizes: [1, 1, 1], children: [_g('a'), _g('b'), _g('c')]),
    );
    final issues = checkDesign(engine.run(d), series);
    expect(issues.any((i) => i.isError && i.message.contains('Alan çok küçük')), isTrue);
  });

  test('HARDWARE: örnek pencerede tek TILT_TURN; JSON biçimi; sürmede 2 SLIDE', () {
    final r = engine.run(_sample());
    final hw = BomLine.aggregate(r.bom).where((b) => b.group == BomGroup.hardware).toList();
    expect(hw.length, 1);
    expect(hw.single.kind, 'TILT_TURN');
    expect(hw.single.w, 536);
    expect(hw.single.h, 1214);
    expect(hw.single.qty, 1);
    expect(hw.single.toJson(), {
      'group': 'HARDWARE',
      'kind': 'TILT_TURN',
      'w': 536.0,
      'h': 1214.0,
      'qty': 1,
    });

    final slide = WindowDesign(width: 2000, height: 1500, root: SlideNode(id: 's', left: _g('a'), right: _g('b')));
    final slideHw = engine.run(slide).bom.where((b) => b.group == BomGroup.hardware).toList();
    expect(slideHw.length, 2);
    expect(slideHw.every((b) => b.kind == 'SLIDE'), isTrue);
    final slideAgg = BomLine.aggregate(slideHw);
    expect(slideAgg.single.qty, 2);
  });
}
