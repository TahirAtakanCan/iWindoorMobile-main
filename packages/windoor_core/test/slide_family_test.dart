import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

void main() {
  const series = SeriesGeometry(
    id: '70',
    frameFace: 62,
    sashLap: 8,
    slideInterlock: 40,
    sashFace: 78,
    weldAllowance: 3,
  );
  final engine = LayoutEngine(series);

  FillNode g(String id) => FillNode(id: id, glassCode: '4+16+4');

  test('3 panel 2800×2200 ölçüleri, BOM ve donanım', () {
    final d = WindowDesign(
      width: 2800,
      height: 2200,
      root: SlideNode(
        id: 's',
        panels: [
          SlidePanel(move: SlideMove.right, child: g('a')),
          SlidePanel(move: SlideMove.fixed, child: g('b')),
          SlidePanel(move: SlideMove.left, child: g('c')),
        ],
      ),
    );
    final r = engine.run(d);
    final outers = r.sashes.map((s) => s.outer).toList();
    expect(outers.length, 3);
    expect(outers[0].w, closeTo(924, 0.01));
    expect(outers[0].l, closeTo(54, 0.01));
    expect(outers[0].r, closeTo(978, 0.01));
    expect(outers[1].l, closeTo(938, 0.01));
    expect(outers[1].r, closeTo(1862, 0.01));
    expect(outers[2].l, closeTo(1822, 0.01));
    expect(outers[2].r, closeTo(2746, 0.01));
    expect(outers[0].h, closeTo(2092, 0.01));

    final bars = BomLine.aggregate(r.bom.where((b) => b.role == ProfileRole.slideSash));
    expect(bars.where((b) => b.length == 930).fold<int>(0, (a, b) => a + b.qty), 6);
    expect(bars.where((b) => b.length == 2098).fold<int>(0, (a, b) => a + b.qty), 6);

    final glass = BomLine.aggregate(r.bom.where((b) => b.group == BomGroup.glass));
    expect(glass.length, 1);
    expect(glass.first.w, closeTo(796, 0.01));
    expect(glass.first.h, closeTo(1964, 0.01));
    expect(glass.first.qty, 3);

    final bead = BomLine.aggregate(r.bom.where((b) => b.group == BomGroup.bead));
    expect(bead.where((b) => b.length == 768).fold<int>(0, (a, b) => a + b.qty), 6);
    expect(bead.where((b) => b.length == 1936).fold<int>(0, (a, b) => a + b.qty), 6);

    final hw = BomLine.aggregate(r.bom.where((b) => b.group == BomGroup.hardware));
    final slides = hw.where((b) => b.kind == 'SLIDE').toList();
    final fixed = hw.where((b) => b.kind == 'SLIDE_FIXED').toList();
    expect(slides.fold<int>(0, (a, b) => a + b.qty), 2);
    expect(slides.every((b) => b.w == 924 && b.h == 2092), isTrue);
    expect(fixed.fold<int>(0, (a, b) => a + b.qty), 1);
    expect(fixed.first.w, 924);
    expect(fixed.first.h, 2092);
  });

  test('2 panel eski JSON → toJson eski biçim, schemaVersion 1, BOM aynı', () {
    final oldJson = {
      'schemaVersion': 1,
      'width': 2000,
      'height': 1500,
      'series': null,
      'color': 'white',
      'root': {
        'id': 's',
        'type': 'slide',
        'children': [
          {'id': 'a', 'type': 'glass', 'glass': 'x', 'duplex': [1, 1]},
          {'id': 'b', 'type': 'glass', 'glass': 'x', 'duplex': [1, 1]},
        ],
      },
    };
    final d = WindowDesign.fromJson(oldJson);
    expect(d.schemaVersion, 1);
    final round = d.toJson();
    expect(round['schemaVersion'], 1);
    expect(round['root']['children'], isA<List>());
    expect(round['root']['panels'], isNull);

    final r = engine.run(d);
    expect(r.bom.where((b) => b.role == ProfileRole.slideSash).length, 4);
    expect(r.bom.where((b) => b.group == BomGroup.hardware && b.kind == 'SLIDE').length, 2);
    expect(r.hits.map((h) => h.nodeId), ['a', 'b']);
  });

  test('liftSlide 2 panel → LIFT_SLIDE + SLIDE_FIXED; tüm sabit → hata', () {
    final d = WindowDesign(
      width: 3200,
      height: 2400,
      root: SlideNode(
        id: 's',
        system: SlideSystem.liftSlide,
        panels: [
          SlidePanel(move: SlideMove.fixed, child: g('a')),
          SlidePanel(move: SlideMove.left, child: g('b')),
        ],
      ),
    );
    final r = engine.run(d);
    final kinds = r.bom.where((b) => b.group == BomGroup.hardware).map((b) => b.kind).toSet();
    expect(kinds, containsAll(['LIFT_SLIDE', 'SLIDE_FIXED']));

    final allFixed = WindowDesign(
      width: 2000,
      height: 1500,
      root: SlideNode(
        id: 's',
        panels: [
          SlidePanel(move: SlideMove.fixed, child: g('a')),
          SlidePanel(move: SlideMove.fixed, child: g('b')),
        ],
      ),
    );
    final issues = checkDesign(engine.run(allFixed), series);
    expect(issues.any((i) => i.isError && i.message.contains('hareketli')), isTrue);
  });

  test('Sineklik: 700×1300 tiltTurnRight + plise → SCREEN PLISE 576×1176', () {
    final d = WindowDesign(
      width: 700,
      height: 1300,
      root: SashNode(
        id: 's',
        opening: OpeningType.tiltTurnRight,
        screen: ScreenKind.plise,
        child: g('g1'),
      ),
    );
    final r = engine.run(d);
    final screens = r.bom.where((b) => b.group == BomGroup.screen).toList();
    expect(screens.length, 1);
    expect(screens.first.kind, 'PLISE');
    expect(screens.first.w, closeTo(576, 0.01));
    expect(screens.first.h, closeTo(1176, 0.01));
    expect(screens.first.toJson()['group'], 'SCREEN');
  });
}
