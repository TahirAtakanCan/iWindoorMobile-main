// Seri limitlerine göre tasarım uyarı / hata kontrolü.

import 'dart:math' as math;

import 'catalog.dart';
import 'edit_ops.dart';
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

  // Sürme grupları (slideNodeId)
  final slideGroups = <String, List<SashInfo>>{};
  for (final sash in layout.sashes) {
    sashFillIds.addAll(sash.fillIds);
    final w = sash.outer.w;
    final h = sash.outer.h;
    final ids = List<String>.from(sash.fillIds);

    if (sash.sliding) {
      final sid = sash.slideNodeId ?? '_';
      (slideGroups[sid] ??= []).add(sash);
      final system = sash.slideSystem ?? SlideSystem.standard;
      if (system == SlideSystem.liftSlide) {
        if (w > s.maxLiftSlideSashWidth) {
          issues.add(RuleIssue(
            ids,
            'Kaldır-sür kanat genişliği ${w.round()} mm; bu seride en fazla ${s.maxLiftSlideSashWidth.round()} mm.',
            false,
          ));
        }
      } else if (w > s.maxSlideSashWidth) {
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

  for (final entry in slideGroups.entries) {
    final group = entry.value;
    final ids = [for (final g in group) ...g.fillIds];
    if (group.every((g) => g.slideMove == SlideMove.fixed)) {
      issues.add(RuleIssue(ids, 'Sürmede en az bir hareketli panel olmalıdır.', true));
    }
    final system = group.first.slideSystem ?? SlideSystem.standard;
    if (system == SlideSystem.liftSlide) {
      final n = group.length;
      if (n < 2 || n > 4) {
        issues.add(RuleIssue(ids, 'Kaldır-sür sistemde panel sayısı 2–4 olmalıdır (şu an $n).', true));
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

  if (design != null) {
    _checkAdapterSplits(design.root, issues);
    _checkFrames(design, layout, s, issues);
    _checkShapeDesign(design, s, issues, layout);
    _checkShutterAndExtras(design, s, issues);
  }

  return issues;
}

void _checkShutterAndExtras(WindowDesign design, SeriesGeometry s, List<RuleIssue> issues) {
  final sh = design.shutter;
  if (sh == null) return;
  final w = design.width;
  final h = design.height;
  final boxH = s.shutterBoxHeight;
  if (w > 3500) {
    issues.add(const RuleIssue([], 'Panjur genişliği 3500 mm üzerinde; kontrol edin.', false));
  }
  final area = w * (h + boxH) / 1e6;
  if (area > 4 && sh.drive == ShutterDrive.manual) {
    issues.add(const RuleIssue([], 'Motorlu panjur önerilir', false));
  }
  if (_designHasNonRectFrame(design)) {
    issues.add(const RuleIssue([], 'Şekilli pencereye panjur eklenemez', true));
  }
}

bool _designHasNonRectFrame(WindowDesign d) {
  if (d.root is CoupleNode) {
    for (final f in (d.root as CoupleNode).children) {
      if (!f.shape.isRect) return true;
    }
    return false;
  }
  return !d.shape.isRect;
}

void _checkShapeDesign(WindowDesign design, SeriesGeometry s, List<RuleIssue> issues, LayoutResult layout) {
  if (design.root is CoupleNode) {
    final c = design.root as CoupleNode;
    for (final f in c.children) {
      _checkShapeOnFrame(design.width, design.height, f.shape, f.id, f.child, s, issues);
    }
  } else if (!design.shape.isRect) {
    _checkShapeOnFrame(design.width, design.height, design.shape, 'root', design.root, s, issues);
  }

  for (final g in layout.prims.whereType<GlassPrim>()) {
    if (g.shapeType != null) {
      final fill = _findFill(design.root, g.nodeId);
      if (fill != null && (fill.duplexCols > 1 || fill.duplexRows > 1)) {
        issues.add(RuleIssue(
          [g.nodeId],
          'Şekilli camda dubleks çıta kullanılamaz.',
          false,
        ));
      }
    }
  }
}

FillNode? _findFill(DesignNode root, String id) {
  for (final n in DesignOps.walk(root)) {
    if (n is FillNode && n.id == id) return n;
  }
  return null;
}

void _checkShapeOnFrame(
  double w,
  double h,
  FrameShape shape,
  String frameId,
  DesignNode content,
  SeriesGeometry s,
  List<RuleIssue> issues,
) {
  if (shape.isRect) return;
  final ids = [frameId];

  switch (shape) {
    case ArchShape _:
      if (h < w / 2 + 200) {
        issues.add(RuleIssue(ids, 'Kemerli pencerede yükseklik en az W/2 + 200 mm olmalıdır.', true));
      }
    case SegmentArchShape seg:
      if (seg.rise < 50 || seg.rise > w / 2) {
        issues.add(RuleIssue(ids, 'Basık kemer yüksekliği 50 mm ile W/2 arasında olmalıdır.', true));
      }
    case TrapezoidShape t:
      final minH = math.min(t.leftHeight, t.rightHeight);
      if (minH < 2 * s.frameFace + 200) {
        issues.add(RuleIssue(ids, 'Eğik üstte kısa yan en az ${(2 * s.frameFace + 200).round()} mm olmalıdır.', true));
      }
    case TriangleShape _:
      if (h < 300 || w < 400) {
        issues.add(RuleIssue(ids, 'Üçgen alınlık için min 400×300 mm gerekir.', true));
      }
    case RectShape _:
      break;
  }

  _checkShapedContent(shape, content, ids, issues);
}

void _checkShapedContent(FrameShape shape, DesignNode node, List<String> frameIds, List<RuleIssue> issues) {
  if (shape is TriangleShape) {
    if (node is! FillNode) {
      issues.add(RuleIssue(frameIds, 'Üçgen pencerede yalnızca sabit cam olabilir.', true));
    }
    return;
  }

  final allowed = switch (node) {
    FillNode _ => true,
    SplitNode s when s.dir == SplitDir.h && s.children.length >= 2 && s.children.first is FillNode => true,
    _ => false,
  };
  if (!allowed) {
    if (node is SashNode || node is SlideNode) {
      issues.add(RuleIssue([node.id], 'Şekilli bölgede kanat kullanılamaz.', true));
    } else {
      issues.add(RuleIssue(
        frameIds,
        'Şekilli kasada içerik tek cam veya üstte cam + altta dikdörtgen bölge olmalıdır.',
        true,
      ));
    }
    return;
  }

  if (node is SplitNode) {
    final top = node.children.first;
    if (top is! FillNode) {
      issues.add(RuleIssue([...frameIds, top.id], 'Şekilli bölge üstte sabit cam olmalıdır.', true));
    }
    _checkNoSashInShapedSubtree(top, issues);
    for (var i = 1; i < node.children.length; i++) {
      _checkShapedSubtreeClean(node.children[i], issues);
    }
  } else if (node is FillNode) {
    _checkNoSashInShapedSubtree(node, issues);
  }
}

void _checkNoSashInShapedSubtree(DesignNode node, List<RuleIssue> issues) {
  switch (node) {
    case SashNode s:
      issues.add(RuleIssue([s.id], 'Şekilli bölgede kanat kullanılamaz.', true));
    case SplitNode s when s.dir == SplitDir.v:
      issues.add(RuleIssue([s.id], 'Şekilli bölgede dikey bölme kullanılamaz.', true));
    case SplitNode s:
      for (final c in s.children) {
        _checkNoSashInShapedSubtree(c, issues);
      }
    case FillNode _:
      break;
    case SlideNode s:
      issues.add(RuleIssue([s.id], 'Şekilli bölgede kanat kullanılamaz.', true));
    case FrameNode _:
    case CoupleNode _:
      break;
  }
}

void _checkShapedSubtreeClean(DesignNode node, List<RuleIssue> issues) {}

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
      for (final p in s.panels) {
        _checkAdapterSplits(p.child, issues);
      }
    case FillNode _:
      break;
  }
}
