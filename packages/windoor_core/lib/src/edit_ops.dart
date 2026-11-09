// Tasarım üzerinde düzenleme işlemleri. Hepsi SAF fonksiyon: eski belgeyi değiştirmez, yenisini döner.
// Bu sayede geri al / ileri al = belgeler listesi.

import 'model.dart';

/// Editördeki açılım seçenekleri (sabit + kanat tipleri + sürme).
enum OpeningChoice { fixed, turnLeft, turnRight, tilt, tiltTurnLeft, tiltTurnRight, slide }

/// Düzenleme sonucu: yeni belge + seçilecek düğüm (+ isteğe bağlı hata).
class EditResult {
  final WindowDesign design;
  final String? selectedId;
  final String? error;
  const EditResult(this.design, this.selectedId, {this.error});
}

class DesignOps {
  DesignOps._();

  static const double minPartMm = 150;

  // ---------------- arama ----------------

  static Iterable<DesignNode> walk(DesignNode n) sync* {
    yield n;
    switch (n) {
      case SplitNode s:
        for (final c in s.children) {
          yield* walk(c);
        }
      case SashNode s:
        yield* walk(s.child);
      case SlideNode s:
        yield* walk(s.left);
        yield* walk(s.right);
      case FillNode _:
        break;
    }
  }

  static DesignNode? find(DesignNode root, String id) {
    for (final n in walk(root)) {
      if (n.id == id) return n;
    }
    return null;
  }

  static Iterable<DesignNode> _children(DesignNode n) => switch (n) {
        SplitNode s => s.children,
        SashNode s => [s.child],
        SlideNode s => [s.left, s.right],
        FillNode _ => const <DesignNode>[],
      };

  static DesignNode? parentOf(DesignNode root, String id) {
    for (final n in walk(root)) {
      for (final c in _children(n)) {
        if (c.id == id) return n;
      }
    }
    return null;
  }

  /// Yaprağı saran kanat/sürme zincirinin en üstü: bölme ve açılım işlemleri bu "yuva" üzerinde yapılır.
  static DesignNode slotOf(DesignNode root, String leafId) {
    DesignNode slot = find(root, leafId)!;
    var parent = parentOf(root, slot.id);
    while (parent is SashNode || parent is SlideNode) {
      slot = parent!;
      parent = parentOf(root, slot.id);
    }
    return slot;
  }

  static List<FillNode> fills(DesignNode root) => walk(root).whereType<FillNode>().toList();

  /// Seçili yaprağın açılım durumu.
  static OpeningChoice openingOf(DesignNode root, String leafId) {
    final slot = slotOf(root, leafId);
    return switch (slot) {
      SashNode s => OpeningChoice.values.byName(s.opening.name),
      SlideNode _ => OpeningChoice.slide,
      _ => OpeningChoice.fixed,
    };
  }

  /// Yuvanın içinde bulunduğu bölme (bölme ölçüsü düzenleme için).
  static SplitNode? splitAround(DesignNode root, String leafId) {
    final slot = slotOf(root, leafId);
    final p = parentOf(root, slot.id);
    return p is SplitNode ? p : null;
  }

  // ---------------- id ----------------

  static String nextId(DesignNode root) {
    var max = 0;
    final re = RegExp(r'^n(\d+)$');
    for (final n in walk(root)) {
      final m = re.firstMatch(n.id);
      if (m != null) {
        final v = int.parse(m.group(1)!);
        if (v > max) max = v;
      }
    }
    return 'n${max + 1}';
  }

  static List<String> _nextIds(DesignNode root, int count) {
    final first = int.parse(nextId(root).substring(1));
    return [for (var i = 0; i < count; i++) 'n${first + i}'];
  }

  // ---------------- yeniden kurma ----------------

  static DesignNode replace(DesignNode n, String id, DesignNode r) {
    if (n.id == id) return r;
    return switch (n) {
      SplitNode s => SplitNode(
          id: s.id,
          dir: s.dir,
          sizes: s.sizes,
          joint: s.joint,
          children: [for (final c in s.children) replace(c, id, r)],
        ),
      SashNode s => SashNode(
          id: s.id,
          opening: s.opening,
          kind: s.kind,
          passive: s.passive,
          outward: s.outward,
          child: replace(s.child, id, r),
        ),
      SlideNode s => SlideNode(id: s.id, left: replace(s.left, id, r), right: replace(s.right, id, r)),
      FillNode f => f,
    };
  }

  // ---------------- işlemler ----------------

  /// Seçili alanı [parts] eşit parçaya böler. Kanat varsa kaldırılır (parçalara ayrı ayrı kanat eklenir).
  static EditResult split(WindowDesign d, String leafId, SplitDir dir, int parts) {
    final leaf = find(d.root, leafId);
    if (leaf is! FillNode || parts < 2) return EditResult(d, leafId);
    final slot = slotOf(d.root, leafId);
    final ids = _nextIds(d.root, parts + 1);
    final kids = [for (var i = 0; i < parts; i++) leaf.copyWith(id: ids[i + 1])];
    final node = SplitNode(id: ids[0], dir: dir, sizes: List.filled(parts, 1.0), children: kids);
    return EditResult(d.copyWith(root: replace(d.root, slot.id, node)), kids.first.id);
  }

  /// Seçili alanın içinde bulunduğu bölmeyi kaldırır; bölmenin yerine tek cam gelir.
  static EditResult unsplit(WindowDesign d, String leafId) {
    final leaf = find(d.root, leafId);
    final sp = splitAround(d.root, leafId);
    if (leaf is! FillNode || sp == null) return EditResult(d, leafId);
    return EditResult(d.copyWith(root: replace(d.root, sp.id, leaf)), leaf.id);
  }

  static EditResult setOpening(WindowDesign d, String leafId, OpeningChoice choice) {
    final leaf = find(d.root, leafId);
    if (leaf is! FillNode) return EditResult(d, leafId);
    final slot = slotOf(d.root, leafId);
    if (openingOf(d.root, leafId) == choice) return EditResult(d, leafId);
    final DesignNode node;
    switch (choice) {
      case OpeningChoice.fixed:
        node = leaf;
      case OpeningChoice.slide:
        final ids = _nextIds(d.root, 2);
        node = SlideNode(id: ids[0], left: leaf, right: leaf.copyWith(id: ids[1]));
      default:
        final opening = OpeningType.values.byName(choice.name);
        if (slot is SashNode) {
          node = slot.copyWith(opening: opening, child: leaf);
        } else {
          node = SashNode(id: nextId(d.root), opening: opening, child: leaf);
        }
    }
    return EditResult(d.copyWith(root: replace(d.root, slot.id, node)), leaf.id);
  }

  static EditResult updateFill(WindowDesign d, String leafId,
      {FillType? fill, String? glassCode, int? duplexCols, int? duplexRows}) {
    final leaf = find(d.root, leafId);
    if (leaf is! FillNode) return EditResult(d, leafId);
    final next = leaf.copyWith(
      fill: fill,
      glassCode: glassCode,
      duplexCols: duplexCols?.clamp(1, 12).toInt(),
      duplexRows: duplexRows?.clamp(1, 12).toInt(),
    );
    return EditResult(d.copyWith(root: replace(d.root, leafId, next)), leafId);
  }

  /// Bütün cam/panel alanlarına aynı kodu verir.
  static WindowDesign setAllGlass(WindowDesign d, String glassCode, {FillType only = FillType.glass}) {
    var root = d.root;
    for (final f in fills(root)) {
      if (f.fill == only) root = replace(root, f.id, f.copyWith(glassCode: glassCode));
    }
    return d.copyWith(root: root);
  }

  /// Boş cam kodlarını varsayılanla doldurur (eski pencerelerden gelen belgeler için).
  static WindowDesign fillMissingCodes(WindowDesign d, {required String glass, String? panel}) {
    var root = d.root;
    for (final f in fills(root)) {
      if (f.glassCode.isEmpty) {
        final code = f.fill == FillType.panel ? (panel ?? glass) : glass;
        if (code.isNotEmpty) root = replace(root, f.id, f.copyWith(glassCode: code));
      }
    }
    return d.copyWith(root: root);
  }

  /// Katalogda olmayan veya pasif kodları varsayılan cam/panel koduyla değiştirir.
  static WindowDesign replaceUnknownCodes(
    WindowDesign d,
    Set<String> knownGlass,
    Set<String> knownPanel, {
    required String glass,
    String? panel,
  }) {
    var root = d.root;
    for (final f in fills(root)) {
      if (f.fill == FillType.panel) {
        if (!knownPanel.contains(f.glassCode)) {
          final code = (panel ?? glass);
          if (code.isNotEmpty) root = replace(root, f.id, f.copyWith(glassCode: code));
        }
      } else if (!knownGlass.contains(f.glassCode)) {
        if (glass.isNotEmpty) root = replace(root, f.id, f.copyWith(glassCode: glass));
      }
    }
    return d.copyWith(root: root);
  }

  /// Bölme parçasının ölçüsünü (mm) değiştirir; fark komşu parçadan alınır/verilir.
  /// [span] bölmenin referans aralığı (LayoutResult.splitSpans).
  static WindowDesign setPartSize(WindowDesign d, String splitId, int index, double mm, double span) {
    final sp = find(d.root, splitId);
    if (sp is! SplitNode) return d;
    final n = sp.sizes.length;
    final total = sp.sizes.fold<double>(0, (a, b) => a + b);
    final cur = [for (final v in sp.sizes) span * v / total];
    final upper = span - minPartMm * (n - 1);
    if (upper < minPartMm || index < 0 || index >= n) return d;
    final target = mm.clamp(minPartMm, upper).toDouble();
    final j = index < n - 1 ? index + 1 : index - 1;
    final delta = target - cur[index];
    if (cur[j] - delta < minPartMm) return d;
    cur[index] = target;
    cur[j] -= delta;
    final sizes = [for (final v in cur) (v * 10).roundToDouble() / 10];
    final next = sp.copyWith(sizes: sizes);
    return d.copyWith(root: replace(d.root, splitId, next));
  }

  /// Bir bölmenin parçalarını mm olarak döner.
  static List<double> partSizesMm(SplitNode sp, double span) {
    final total = sp.sizes.fold<double>(0, (a, b) => a + b);
    return [for (final v in sp.sizes) span * v / total];
  }

  /// Seçili cam/kanatı orta kayıtsız (adaptör) çift kanata çevirir.
  static EditResult makeDoubleSash(WindowDesign d, String fillId) {
    final leaf = find(d.root, fillId);
    if (leaf is! FillNode) return EditResult(d, fillId);
    final slot = slotOf(d.root, fillId);
    final ids = _nextIds(d.root, 5);
    final leftFill = leaf.copyWith(id: ids[3]);
    final rightFill = leaf.copyWith(id: ids[4]);
    final node = SplitNode(
      id: ids[0],
      dir: SplitDir.v,
      sizes: const [1, 1],
      joint: JointKind.adapter,
      children: [
        SashNode(id: ids[1], opening: OpeningType.turnLeft, passive: true, child: leftFill),
        SashNode(id: ids[2], opening: OpeningType.tiltTurnRight, child: rightFill),
      ],
    );
    return EditResult(d.copyWith(root: replace(d.root, slot.id, node)), leftFill.id);
  }

  /// Adaptör birleşimine geçiş için hata metni; geçerliyse null.
  static String? jointError(SplitNode sp, JointKind joint) {
    if (joint != JointKind.adapter) return null;
    if (sp.dir != SplitDir.v || sp.children.length != 2) {
      return 'Orta kayıtsız birleşim yalnızca dikey iki kanatlı bölmede kullanılabilir.';
    }
    if (sp.children.any((c) => c is! SashNode)) {
      return 'Orta kayıtsız birleşimde her iki yan da kanat olmalıdır.';
    }
    return null;
  }

  /// Bölme birleşimini ayarlar. Geçersiz adaptörde [EditResult.error] dolu döner.
  static EditResult setJoint(WindowDesign d, String splitId, JointKind joint) {
    final sp = find(d.root, splitId);
    if (sp is! SplitNode) return EditResult(d, splitId);
    final err = jointError(sp, joint);
    if (err != null) return EditResult(d, splitId, error: err);
    var children = sp.children;
    if (joint == JointKind.adapter) {
      final sashes = children.cast<SashNode>();
      final passiveCount = sashes.where((s) => s.passive).length;
      if (passiveCount == 0) {
        children = [sashes[0].copyWith(passive: true), sashes[1].copyWith(passive: false)];
      } else if (passiveCount > 1) {
        return EditResult(d, splitId, error: 'Orta kayıtsız birleşimde tam bir pasif kanat olmalıdır.');
      }
    }
    final next = sp.copyWith(joint: joint, children: children);
    return EditResult(d.copyWith(root: replace(d.root, splitId, next)), splitId);
  }

  static EditResult setSashKind(WindowDesign d, String sashId, SashKind kind) {
    final sash = find(d.root, sashId);
    if (sash is! SashNode) return EditResult(d, sashId);
    return EditResult(d.copyWith(root: replace(d.root, sashId, sash.copyWith(kind: kind))), sashId);
  }

  /// Adaptör bölmesinde bu kanadı pasif yapar; diğerini aktifleştirir.
  static EditResult setPassive(WindowDesign d, String sashId) {
    final sash = find(d.root, sashId);
    if (sash is! SashNode) return EditResult(d, sashId);
    final parent = parentOf(d.root, sashId);
    if (parent is SplitNode && parent.joint == JointKind.adapter && parent.children.length == 2) {
      var root = d.root;
      for (final c in parent.children) {
        if (c is! SashNode) continue;
        root = replace(root, c.id, c.copyWith(passive: c.id == sashId));
      }
      return EditResult(d.copyWith(root: root), sashId);
    }
    return EditResult(d.copyWith(root: replace(d.root, sashId, sash.copyWith(passive: !sash.passive))), sashId);
  }

  static EditResult setOutward(WindowDesign d, String sashId, bool outward) {
    final sash = find(d.root, sashId);
    if (sash is! SashNode) return EditResult(d, sashId);
    return EditResult(d.copyWith(root: replace(d.root, sashId, sash.copyWith(outward: outward))), sashId);
  }

  static EditResult setBottom(WindowDesign d, BottomKind bottom) =>
      EditResult(d.copyWith(bottom: bottom), null);
}
