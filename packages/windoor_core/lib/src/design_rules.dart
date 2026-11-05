// Seri limitlerine göre tasarım uyarı / hata kontrolü.

import 'catalog.dart';
import 'layout_engine.dart';
import 'model.dart';

class RuleIssue {
  final List<String> nodeIds;
  final String message;
  final bool isError;

  const RuleIssue(this.nodeIds, this.message, this.isError);
}

/// [layout] üzerindeki kanat ve sabit camları [s] limitleriyle karşılaştırır.
List<RuleIssue> checkDesign(LayoutResult layout, SeriesGeometry s) {
  final issues = <RuleIssue>[];
  final sashFillIds = <String>{};

  for (final sash in layout.sashes) {
    sashFillIds.addAll(sash.fillIds);
    final w = sash.outer.w;
    final h = sash.outer.h;
    final ids = List<String>.from(sash.fillIds);

    if (sash.sliding) {
      if (w > s.maxSlideSashWidth) {
        issues.add(RuleIssue(
          ids,
          'Sürme kanat genişliği ${w.round()} mm; bu seride en fazla ${s.maxSlideSashWidth.round()} mm.',
          false,
        ));
      }
    } else {
      if (w < s.minSashWidth) {
        issues.add(RuleIssue(
          ids,
          'Kanat genişliği ${w.round()} mm; bu seride en az ${s.minSashWidth.round()} mm.',
          false,
        ));
      } else if (w > s.maxSashWidth) {
        issues.add(RuleIssue(
          ids,
          'Kanat genişliği ${w.round()} mm; bu seride en fazla ${s.maxSashWidth.round()} mm.',
          false,
        ));
      }
      if (h < s.minSashHeight) {
        issues.add(RuleIssue(
          ids,
          'Kanat yüksekliği ${h.round()} mm; bu seride en az ${s.minSashHeight.round()} mm.',
          false,
        ));
      } else if (h > s.maxSashHeight) {
        issues.add(RuleIssue(
          ids,
          'Kanat yüksekliği ${h.round()} mm; bu seride en fazla ${s.maxSashHeight.round()} mm.',
          false,
        ));
      }
    }
  }

  for (final g in layout.prims.whereType<GlassPrim>()) {
    if (g.visible.w <= 0 || g.visible.h <= 0) {
      issues.add(RuleIssue(
        [g.nodeId],
        'Alan çok küçük; profil genişlikleri sığmıyor.',
        true,
      ));
      continue;
    }
    if (sashFillIds.contains(g.nodeId)) continue;
    final area = g.cutW * g.cutH / 1e6;
    if (area > s.maxFixedGlassArea) {
      final kind = g.fill == FillType.panel ? 'panel' : 'cam';
      issues.add(RuleIssue(
        [g.nodeId],
        'Sabit $kind alanı ${area.toStringAsFixed(2)} m²; bu seride en fazla ${s.maxFixedGlassArea.toStringAsFixed(2)} m².',
        false,
      ));
    }
  }

  return issues;
}
