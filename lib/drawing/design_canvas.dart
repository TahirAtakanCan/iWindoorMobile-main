import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import 'design_painter.dart';
import 'glass_look.dart';

/// Tasarımı çizen ve dokunulan cam alanını bildiren widget. Sunucuya hiç gitmez.
class DesignCanvas extends StatelessWidget {
  final WindowDesign design;
  final LayoutResult layout;
  final GlassLook Function(String glassCode) lookOf;
  final String? selectedId;
  final Set<String> issueIds;
  final ValueChanged<String?>? onSelect;
  final bool showDimensions;
  final bool showLabels;
  final ProfileColor? color;

  const DesignCanvas({
    super.key,
    required this.design,
    required this.layout,
    required this.lookOf,
    this.selectedId,
    this.issueIds = const {},
    this.onSelect,
    this.showDimensions = true,
    this.showLabels = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, c) {
      final size = Size(c.maxWidth, c.maxHeight);
      final painter = DesignPainter(
        layout: layout,
        designW: design.width,
        designH: design.height,
        lookOf: lookOf,
        color: color ?? ProfileColor.of(design.colorCode),
        selectedId: selectedId,
        issueIds: issueIds,
        showDimensions: showDimensions,
        showLabels: showLabels,
        dimColor: scheme.onSurface.withValues(alpha: .8),
      );
      final paint = CustomPaint(size: size, painter: painter);
      if (onSelect == null) return paint;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => onSelect!(painter.fillIdAt(size, d.localPosition)),
        child: paint,
      );
    });
  }
}
