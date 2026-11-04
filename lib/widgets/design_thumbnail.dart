import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/design_canvas.dart';
import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/window_unit.dart';

/// Proje ekranındaki pencere kartı. Yeni çizim motoruyla çizer (eski pencereler dönüştürülür).
class DesignThumbnail extends StatelessWidget {
  final WindowUnit unit;
  final CatalogSnapshot? catalog;

  const DesignThumbnail({super.key, required this.unit, this.catalog});

  @override
  Widget build(BuildContext context) {
    final design = unit.previewDesign;
    final cat = catalog ?? CatalogSnapshot.fallback;
    final layout = LayoutEngine(cat.seriesFor(unit.seriesId).geometry).run(design);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: DesignCanvas(
                design: design,
                layout: layout,
                lookOf: (code) => GlassLook.forStyle(cat.glassByCode(code)?.visualStyle),
                showDimensions: false,
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: .5),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(unit.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              Text(
                '${unit.width.toInt()} × ${unit.height.toInt()} mm'
                '${unit.quantity > 1 ? '  ·  ${unit.quantity} adet' : ''}'
                '${unit.unitPrice != null ? '  ·  ${unit.unitPrice!.toStringAsFixed(0)} TL' : ''}',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
