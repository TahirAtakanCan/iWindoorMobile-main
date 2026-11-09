// Yerleşik tasarım şablonları. Ölçü/seri applyTemplateDesign ile uygulanır; yapı ve ağırlıklar korunur.

import 'model.dart';

/// Katalog / firma şablonunun istemci tarafı özeti.
class DesignTemplate {
  final String id;
  final String name;
  final String category; // WINDOW | DOOR | SLIDING
  final double defaultWidth;
  final double defaultHeight;
  final WindowDesign Function(double width, double height, String seriesId) _build;

  const DesignTemplate({
    required this.id,
    required this.name,
    required this.category,
    required this.defaultWidth,
    required this.defaultHeight,
    required WindowDesign Function(double width, double height, String seriesId) build,
  }) : _build = build;

  WindowDesign build(double width, double height, String seriesId) => _build(width, height, seriesId);
}

/// Firma şablonunu (veya yerleşik kökü) yeni ölçü ve seriye uygular; düğüm yapısı aynı kalır.
WindowDesign applyTemplateDesign(WindowDesign t, double w, double h, String seriesId) =>
    t.copyWith(width: w, height: h, seriesId: seriesId);

FillNode _g(String id, {FillType fill = FillType.glass}) =>
    FillNode(id: id, fill: fill, glassCode: '');

List<DesignTemplate> builtInTemplates() => [
      DesignTemplate(
        id: 'builtin-1',
        name: 'Sabit cam',
        category: 'WINDOW',
        defaultWidth: 1000,
        defaultHeight: 1200,
        build: (w, h, s) => WindowDesign(width: w, height: h, seriesId: s, root: _g('n1')),
      ),
      DesignTemplate(
        id: 'builtin-2',
        name: 'Tek kanat çift açılım',
        category: 'WINDOW',
        defaultWidth: 700,
        defaultHeight: 1300,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SashNode(id: 'n1', opening: OpeningType.tiltTurnRight, child: _g('n2')),
        ),
      ),
      DesignTemplate(
        id: 'builtin-3',
        name: 'Çift kanat',
        category: 'WINDOW',
        defaultWidth: 1400,
        defaultHeight: 1400,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SplitNode(id: 'n1', dir: SplitDir.v, sizes: const [1, 1], children: [
            SashNode(id: 'n2', opening: OpeningType.turnLeft, child: _g('n3')),
            SashNode(id: 'n4', opening: OpeningType.tiltTurnRight, child: _g('n5')),
          ]),
        ),
      ),
      DesignTemplate(
        id: 'builtin-4',
        name: 'Ortası sabit, iki yanı kanat',
        category: 'WINDOW',
        defaultWidth: 2100,
        defaultHeight: 1400,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SplitNode(id: 'n1', dir: SplitDir.v, sizes: const [1, 1, 1], children: [
            SashNode(id: 'n2', opening: OpeningType.turnLeft, child: _g('n3')),
            _g('n4'),
            SashNode(id: 'n5', opening: OpeningType.tiltTurnRight, child: _g('n6')),
          ]),
        ),
      ),
      DesignTemplate(
        id: 'builtin-5',
        name: 'Üstü vasistas, altı çift açılım',
        category: 'WINDOW',
        defaultWidth: 900,
        defaultHeight: 1700,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SplitNode(id: 'n1', dir: SplitDir.h, sizes: const [500, 1200], children: [
            SashNode(id: 'n2', opening: OpeningType.tilt, child: _g('n3')),
            SashNode(id: 'n4', opening: OpeningType.tiltTurnRight, child: _g('n5')),
          ]),
        ),
      ),
      DesignTemplate(
        id: 'builtin-6',
        name: 'Üstü sabit, altı çift kanat',
        category: 'WINDOW',
        defaultWidth: 1600,
        defaultHeight: 1800,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          // Üst sabit ~450 mm kalır; [1,3] oranı korunur (uyarı yok).
          root: SplitNode(id: 'n1', dir: SplitDir.h, sizes: const [500, 1300], children: [
            _g('n2'),
            SplitNode(id: 'n3', dir: SplitDir.v, sizes: const [1, 1], children: [
              SashNode(id: 'n4', opening: OpeningType.turnLeft, child: _g('n5')),
              SashNode(id: 'n6', opening: OpeningType.tiltTurnRight, child: _g('n7')),
            ]),
          ]),
        ),
      ),
      DesignTemplate(
        id: 'builtin-7',
        name: 'Sürme iki kanat',
        category: 'SLIDING',
        defaultWidth: 2400,
        defaultHeight: 2200,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SlideNode(id: 'n1', left: _g('n2'), right: _g('n3')),
        ),
      ),
      DesignTemplate(
        id: 'builtin-8',
        name: 'Balkon kapısı + pencere',
        category: 'DOOR',
        defaultWidth: 1800,
        defaultHeight: 2300,
        build: (w, h, s) => WindowDesign(
          width: w,
          height: h,
          seriesId: s,
          root: SplitNode(id: 'n1', dir: SplitDir.v, sizes: const [2, 3], children: [
            SashNode(
              id: 'n2',
              opening: OpeningType.tiltTurnLeft,
              child: SplitNode(id: 'n3', dir: SplitDir.h, sizes: const [3, 1], children: [
                _g('n4'),
                _g('n5', fill: FillType.panel),
              ]),
            ),
            _g('n6'),
          ]),
        ),
      ),
    ];
