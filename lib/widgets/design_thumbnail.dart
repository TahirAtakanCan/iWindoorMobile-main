import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import '../drawing/design_canvas.dart';
import '../drawing/glass_look.dart';
import '../models/catalog.dart';
import '../models/window_unit.dart';

/// Tasarım küçük resmi: proje kartı veya şablon seçici.
class DesignThumbnail extends StatelessWidget {
  final WindowDesign design;
  final String title;
  final String subtitle;
  final CatalogSnapshot? catalog;
  final Object? seriesId;
  final bool showCaption;

  const DesignThumbnail({
    super.key,
    required this.design,
    required this.title,
    required this.subtitle,
    this.catalog,
    this.seriesId,
    this.showCaption = true,
  });

  factory DesignThumbnail.unit(WindowUnit unit, {Key? key, CatalogSnapshot? catalog}) {
    return DesignThumbnail(
      key: key,
      design: unit.previewDesign,
      title: unit.name,
      subtitle: '${unit.width.toInt()} × ${unit.height.toInt()} mm'
          '${unit.quantity > 1 ? '  ·  ${unit.quantity} adet' : ''}'
          '${unit.unitPrice != null ? '  ·  ${unit.unitPrice!.toStringAsFixed(0)} TL' : ''}',
      catalog: catalog,
      seriesId: unit.seriesId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cat = catalog ?? CatalogSnapshot.fallback;
    final layout = LayoutEngine(cat.seriesFor(seriesId ?? design.seriesId).geometry).run(design);
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
          if (showCaption)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
                Text(
                  subtitle,
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
