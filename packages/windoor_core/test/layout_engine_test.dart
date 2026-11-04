import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

// Tarayıcı prototipi ve backend testlerindeki 1800x1700 örnek pencere.
FillNode g(String id) => FillNode(id: id, glassCode: '4+16+4');

WindowDesign sample() => WindowDesign(
      width: 1800,
      height: 1700,
      seriesId: '1',
      root: SplitNode(id: 'n1', dir: SplitDir.h, sizes: [400, 1300], children: [
        SplitNode(id: 'n2', dir: SplitDir.v, sizes: [600, 600, 600], children: [g('n3'), g('n4'), g('n5')]),
        SplitNode(id: 'n6', dir: SplitDir.v, sizes: [600, 600, 600], children: [
          g('n7'),
          SashNode(id: 'n8', opening: OpeningType.tiltTurnLeft, child: g('n9')),
          g('n10'),
        ]),
      ]),
    );

void main() {
  final engine = LayoutEngine(const SeriesGeometry(id: '1'));

  test('kasa kesimi = dış ölçü + 2 x kaynak payı', () {
    final r = engine.run(sample());
    final frame = r.bom.where((b) => b.role == ProfileRole.frame).map((b) => b.length).toSet();
    expect(frame, {1806.0, 1706.0});
  });

  test('kayıt eksenleri dış ölçüye göre 600/600/600 böler', () {
    final r = engine.run(sample());
    expect(r.mullionX.toSet(), {600.0, 1200.0});
    expect(r.mullionY, [400.0]);
    expect(r.splitSpans['n1'], 1700);
  });

  test('kanat ve kanat camı ölçüleri', () {
    final r = engine.run(sample());
    final sash = r.bom.where((b) => b.role == ProfileRole.sash).map((b) => b.length).toSet();
    expect(sash, {542.0, 1220.0});
    final glass = r.bom.where((b) => b.group == BomGroup.glass).toList();
    // kanat içi cam: (542-6-2*78)+28 = 408 , (1220-6-2*78)+28 = 1086
    expect(glass.any((x) => x.w == 408 && x.h == 1086), isTrue);
  });

  test('kesim listesi metrajları backend fiyat testindekiyle aynı', () {
    final lines = BomLine.aggregate(engine.run(sample()).bom);
    double meters(BomGroup grp, [ProfileRole? role]) => lines
        .where((l) => l.group == grp && (role == null || l.role == role))
        .fold(0.0, (a, l) => a + l.length! * l.qty / 1000);
    expect(meters(BomGroup.profile, ProfileRole.frame), closeTo(7.024, 1e-9));
    expect(meters(BomGroup.profile, ProfileRole.mullion), closeTo(4.698, 1e-9));
    expect(meters(BomGroup.profile, ProfileRole.sash), closeTo(3.524, 1e-9));
    expect(meters(BomGroup.bead), closeTo(14.48, 1e-9));
    final m2 = lines.where((l) => l.group == BomGroup.glass).fold(0.0, (a, l) => a + l.w! * l.h! * l.qty / 1e6);
    expect(m2, closeTo(2.25444, 1e-9));
  });

  test('kesim listesi JSON biçimi backend ile uyumlu', () {
    final json = engine.run(sample()).bomJson();
    final frame = json.firstWhere((l) => l['role'] == 'FRAME');
    expect(frame['group'], 'PROFILE');
    expect(frame['qty'], 2);
    final glass = json.firstWhere((l) => l['group'] == 'GLASS');
    expect(glass.keys, containsAll(['w', 'h', 'qty', 'glassCode']));
    final bead = json.firstWhere((l) => l['group'] == 'BEAD');
    expect(bead['glassCode'], '4+16+4');
    expect(json.every((l) => (l['qty'] as int) >= 1), isTrue);
  });

  test('sürme: iki kanat, bindirme ve SLIDE_SASH rolü', () {
    final d = WindowDesign(width: 2000, height: 1500, root: SlideNode(id: 's', left: g('a'), right: g('b')));
    final r = engine.run(d);
    expect(r.bom.where((b) => b.role == ProfileRole.slideSash).length, 4);
    expect(r.hits.map((h) => h.nodeId), ['a', 'b']);
  });

  test('dubleks sadece camda, panelde yok', () {
    final d = WindowDesign(width: 1000, height: 1000, root: SplitNode(id: 's', dir: SplitDir.v, sizes: [1, 1], children: [
      const FillNode(id: 'a', glassCode: 'x', duplexCols: 3, duplexRows: 2),
      const FillNode(id: 'b', fill: FillType.panel, glassCode: 'p', duplexCols: 3),
    ]));
    final r = engine.run(d);
    expect(r.prims.whereType<BarRect>().where((b) => b.layer == DrawLayer.duplex).length, 3);
    expect(r.bom.where((b) => b.group == BomGroup.panel).length, 1);
  });

  test('JSON gidiş-dönüş modeli bozmaz', () {
    final d = sample();
    expect(WindowDesign.fromJson(d.toJson()).toJson(), d.toJson());
  });
}
