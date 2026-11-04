import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:windoor_core/windoor_core.dart';

import 'package:iwindoor_mobil/drawing/design_canvas.dart';
import 'package:iwindoor_mobil/drawing/glass_look.dart';
import 'package:iwindoor_mobil/models/catalog.dart';

/// Sunucuya gitmeden: tuval örnek pencereyi çizer ve dokunulan cam alanını doğru bildirir.
void main() {
  final design = WindowDesign(
    width: 1800,
    height: 1700,
    root: SplitNode(id: 'n1', dir: SplitDir.v, sizes: const [900, 900], children: const [
      FillNode(id: 'left', glassCode: '4+16+4'),
      FillNode(id: 'right', glassCode: '4F+16+4'),
    ]),
  );
  final layout = LayoutEngine(CatalogSnapshot.fallback.series.first.geometry).run(design);

  testWidgets('tuval çizer ve dokunulan alanı seçer', (tester) async {
    String? selected;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: DesignCanvas(
            design: design,
            layout: layout,
            lookOf: (_) => GlassLook.clear,
            onSelect: (id) => selected = id,
          ),
        ),
      ),
    ));
    expect(find.byType(DesignCanvas), findsOneWidget);

    final box = tester.getRect(find.byType(DesignCanvas));
    // sağ yarının ortasına dokun (ölçü boşlukları solda/altta olduğundan biraz sağa kaydırılmış)
    await tester.tapAt(Offset(box.left + box.width * .78, box.top + box.height * .4));
    expect(selected, 'right');
    await tester.tapAt(Offset(box.left + box.width * .35, box.top + box.height * .4));
    expect(selected, 'left');
  });
}
