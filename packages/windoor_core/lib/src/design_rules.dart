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
/// [design] verilirse adaptör bölme ve kasa kuralları da kontrol edilir.
List<RuleIssue> checkDesign(LayoutResult layout, SeriesGeometry s, [WindowDesign? design]) {
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
      continue;
    }

    if (sash.kind == SashKind.door) {
      if (w < s.minDoorSashWidth) {
        issues.add(RuleIssue(
          ids,
          'Kapı kanadı genişliği ${w.round()} mm; bu seride en az ${s.minDoorSashWidth.round()} mm.',
          false,
        ));
      } else if (w > s.maxDoorSashWidth) {
        issues.add(RuleIssue(
          ids,
          'Kapı kanadı genişliği ${w.round()} mm; bu seride en fazla ${s.maxDoorSashWidth.round()} mm.',
          false,
        ));
      }
      if (h < s.minDoorSashHeight) {
        issues.add(RuleIssue(
          ids,
          'Kapı kanadı yüksekliği ${h.round()} mm; bu seride en az ${s.minDoorSashHeight.round()} mm.',
          false,
        ));
      } else if (h > s.maxDoorSashHeight) {
        issues.add(RuleIssue(
          ids,
          'Kapı kanadı yüksekliği ${h.round()} mm; bu seride en fazla ${s.maxDoorSashHeight.round()} mm.',
          false,
        ));
      }
      final o = sash.opening;
      if (o == OpeningType.tilt || o == OpeningType.tiltTurnLeft || o == OpeningType.tiltTurnRight) {
        issues.add(RuleIssue(ids, 'Kapı kanadı vasistas açılamaz.', true));
      }
      continue;
    }

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

  if (design != null) {
    _checkAdapterSplits(design.root, issues);
    _checkFrames(design, layout, s, issues);
  }

  return issues;
}

void _checkFrames(WindowDesign design, LayoutResult layout, SeriesGeometry s, List<RuleIssue> issues) {
  final minSize = 2 * s.frameFace + 100;
  for (final fb in layout.frames) {
    if (fb.box.w < minSize || fb.box.h < minSize) {
      issues.add(RuleIssue([fb.id], 'Kasa çok küçük.', true));
    }
  }
  final root = design.root;
  if (root is CoupleNode) {
    for (final f in root.children) {
      if (f.height != null && f.height! > design.height) {
        issues.add(RuleIssue([f.id], 'Kasa yüksekliği tasarım yüksekliğini aşıyor.', true));
      }
      if (f.width != null && f.width! > design.width) {
        issues.add(RuleIssue([f.id], 'Kasa genişliği tasarım genişliğini aşıyor.', true));
      }
    }
  }
}

void _checkAdapterSplits(DesignNode node, List<RuleIssue> issues) {
  switch (node) {
    case CoupleNode c:
      for (final f in c.children) {
        _checkAdapterSplits(f, issues);
      }
    case FrameNode f:
      _checkAdapterSplits(f.child, issues);
    case SplitNode s:
      if (s.joint == JointKind.adapter) {
        final ids = [s.id, for (final c in s.children) c.id];
        final sashes = s.children.whereType<SashNode>().toList();
        if (s.children.length != 2 || sashes.length != 2) {
          issues.add(RuleIssue(ids, 'Orta kayıtsız birleşimde her iki yan da kanat olmalıdır.', true));
        } else {
          final passive = sashes.where((x) => x.passive).length;
          if (passive != 1) {
            issues.add(RuleIssue(ids, 'Orta kayıtsız birleşimde tam bir pasif kanat olmalıdır.', true));
          }
        }
      }
      for (final c in s.children) {
        _checkAdapterSplits(c, issues);
      }
    case SashNode s:
      _checkAdapterSplits(s.child, issues);
    case SlideNode s:
      _checkAdapterSplits(s.left, issues);
      _checkAdapterSplits(s.right, issues);
    case FillNode _:
      break;
  }
}
