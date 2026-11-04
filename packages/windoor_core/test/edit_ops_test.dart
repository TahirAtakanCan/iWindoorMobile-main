import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

void main() {
  final base = WindowDesign.single(1800, 1700, glassCode: '4+16+4');
  final engine = LayoutEngine(const SeriesGeometry(id: '1'));

  test('bölme: seçili alan üçe ayrılır, cam kodu korunur, ilk parça seçilir', () {
    final r = DesignOps.split(base, 'n1', SplitDir.v, 3);
    final root = r.design.root as SplitNode;
    expect(root.children.length, 3);
    expect(root.children.every((c) => (c as FillNode).glassCode == '4+16+4'), isTrue);
    expect(r.selectedId, root.children.first.id);
    final ids = DesignOps.walk(root).map((n) => n.id).toList();
    expect(ids.toSet().length, ids.length, reason: 'id tekrarı olmamalı');
  });

  test('kanat ekle, tipini değiştir, sabite döndür', () {
    var r = DesignOps.split(base, 'n1', SplitDir.v, 2);
    final leaf = r.selectedId!;
    r = DesignOps.setOpening(r.design, leaf, OpeningChoice.tiltTurnLeft);
    expect(DesignOps.openingOf(r.design.root, leaf), OpeningChoice.tiltTurnLeft);
    r = DesignOps.setOpening(r.design, leaf, OpeningChoice.turnRight);
    expect(DesignOps.openingOf(r.design.root, leaf), OpeningChoice.turnRight);
    expect(DesignOps.walk(r.design.root).whereType<SashNode>().length, 1, reason: 'kanat iç içe girmemeli');
    r = DesignOps.setOpening(r.design, leaf, OpeningChoice.fixed);
    expect(DesignOps.walk(r.design.root).whereType<SashNode>(), isEmpty);
  });

  test('kanatlı alanı bölmek kanadı kaldırır ve yerine bölme koyar', () {
    var r = DesignOps.setOpening(base, 'n1', OpeningChoice.turnLeft);
    r = DesignOps.split(r.design, 'n1', SplitDir.h, 2);
    expect(r.design.root, isA<SplitNode>());
    expect(DesignOps.walk(r.design.root).whereType<SashNode>(), isEmpty);
  });

  test('sürme iki kanat oluşturur; bölmeyi kaldır tek cama döner', () {
    var r = DesignOps.split(base, 'n1', SplitDir.v, 2);
    r = DesignOps.setOpening(r.design, r.selectedId!, OpeningChoice.slide);
    expect(DesignOps.walk(r.design.root).whereType<SlideNode>().length, 1);
    r = DesignOps.unsplit(r.design, r.selectedId!);
    expect(r.design.root, isA<FillNode>());
  });

  test('bölme ölçüsü: 600 yerine 800 girilince komşu 400 olur', () {
    var r = DesignOps.split(base, 'n1', SplitDir.v, 3);
    final splitId = r.design.root.id;
    final span = engine.run(r.design).splitSpans[splitId]!;
    final d = DesignOps.setPartSize(r.design, splitId, 0, 800, span);
    final parts = DesignOps.partSizesMm(d.root as SplitNode, span);
    expect(parts[0], closeTo(800, 0.1));
    expect(parts[1], closeTo(400, 0.1));
    expect(parts[2], closeTo(600, 0.1));
    // en küçük parça sınırı
    final same = DesignOps.setPartSize(d, splitId, 0, 1790, span);
    expect(DesignOps.partSizesMm(same.root as SplitNode, span)[1], greaterThanOrEqualTo(DesignOps.minPartMm - 0.1));
  });

  test('cam/panel/dubleks güncelleme ve boş kod doldurma', () {
    var d = WindowDesign.single(1000, 1000);
    d = DesignOps.fillMissingCodes(d, glass: '4+16+4', panel: 'PANEL-24');
    expect((d.root as FillNode).glassCode, '4+16+4');
    final r = DesignOps.updateFill(d, 'n1', fill: FillType.panel, glassCode: 'PANEL-24', duplexCols: 40);
    final f = r.design.root as FillNode;
    expect(f.fill, FillType.panel);
    expect(f.duplexCols, 12);
  });

  test('eski düğüm ağacı dönüşümü', () {
    final unit = {
      'width': 1200,
      'height': 1400,
      'rootNode': {
        'id': 1,
        'nodeType': 'MULLION_VERTICAL',
        'children': [
          {'id': 3, 'nodeType': 'SASH', 'width': 700, 'height': 1400, 'itemOrder': 1, 'children': []},
          {'id': 2, 'nodeType': 'GLASS', 'width': 500, 'height': 1400, 'itemOrder': 0, 'children': [], 'glass': {'code': 'G1'}},
        ],
      },
    };
    final d = LegacyConverter.fromUnitJson(unit);
    final root = d.root as SplitNode;
    expect(root.sizes, [500, 700]);
    expect((root.children[0] as FillNode).glassCode, 'G1');
    expect(root.children[1], isA<SashNode>());
  });
}
