// Yerleşim motoru: WindowDesign + SeriesGeometry  ->  primitifler + kesim listesi.
// Saf Dart: Flutter'a bağımlı değil. Mobil, masaüstü, PDF ve testler aynı kodu kullanır.

import 'dart:math' as math;
import 'catalog.dart';
import 'model.dart';

// ---------- basit geometri ----------
class Pt {
  final double x, y;
  const Pt(this.x, this.y);
}

class Box {
  final double l, t, r, b;
  const Box(this.l, this.t, this.r, this.b);
  factory Box.xywh(double x, double y, double w, double h) => Box(x, y, x + w, y + h);
  double get w => r - l;
  double get h => b - t;
  double get cx => (l + r) / 2;
  double get cy => (t + b) / 2;
  Box deflate(double d) => Box(l + d, t + d, r - d, b - d);
  Box inflate(double d) => deflate(-d);
  bool contains(double x, double y) => x >= l && x <= r && y >= t && y <= b;
}

// ---------- primitifler ----------
/// Çizim sırası (alttan üste) bu enum sırasıdır.
enum DrawLayer { glass, duplex, bead, mullion, frame, sash, adapter, hardware, symbol, label, dims }

enum ProfileSide { top, right, bottom, left }

sealed class Prim {
  final DrawLayer layer;
  final int z; // aynı katmanda öne-arkaya (sürmede sağ kanat önde)
  const Prim(this.layer, {this.z = 0});
}

/// Gönyeli profil parçası (kasa, kanat, çıta): 4 köşeli yamuk.
class ProfilePoly extends Prim {
  final List<Pt> pts;
  final ProfileSide side;
  const ProfilePoly(super.layer, this.pts, this.side, {super.z});
}

class BarRect extends Prim {
  final Box box;
  final SplitDir? dir; // kayıt yönü (gölge için)
  final bool metallic;
  const BarRect(super.layer, this.box, {this.dir, this.metallic = false, super.z});
}

class GlassPrim extends Prim {
  final String nodeId;
  final Box visible; // çıta içinde görünen cam
  final double cutW, cutH; // cam kesim ölçüsü (BOM GLASS/PANEL ile aynı, mm)
  final String glassCode;
  final FillType fill;
  const GlassPrim(this.nodeId, this.visible, this.cutW, this.cutH, this.glassCode, this.fill)
      : super(DrawLayer.glass);
}

class PolylinePrim extends Prim {
  final List<Pt> pts;
  final bool dashed;
  const PolylinePrim(super.layer, this.pts, {this.dashed = false});
}

class HandlePrim extends Prim {
  final Box base, lever;
  final Box? lock;
  const HandlePrim(this.base, this.lever, {this.lock}) : super(DrawLayer.hardware);
}

class TextPrim extends Prim {
  final Pt at;
  final String text;
  const TextPrim(super.layer, this.at, this.text);
}

/// Dokunma alanı (seçim için) - çizilmez.
class HitArea {
  final String nodeId;
  final Box box;
  const HitArea(this.nodeId, this.box);
}

// ---------- kesim listesi (backend BomPricer biçimi) ----------
enum BomGroup { profile, bead, duplex, glass, panel, hardware }

/// Profil satırının rolü: sunucu bunu serideki ilgili profile eşler.
enum ProfileRole { frame, sash, mullion, slideSash, adapter, doorSash, threshold }

class BomLine {
  final BomGroup group;
  final ProfileRole? role;
  final String label; // ekranda gösterilecek ad
  final double? length; // çubuk ise (mm)
  final double? w, h; // cam/panel / donanım kanat ölçüsü (mm)
  final String? cut; // "45/45" , "90/90" , "45/90"
  final String? glassCode; // cam/panel kodu; çıtada camın kodu (kalınlığa göre çıta seçimi için)
  final String? kind; // donanım: TURN | TILT | TILT_TURN | SLIDE | PASSIVE | DOOR | DOOR_PASSIVE
  final int qty;

  const BomLine.bar(this.group, this.label, this.length, this.cut, this.qty, {this.role, this.glassCode})
      : w = null,
        h = null,
        kind = null;

  const BomLine.sheet(this.group, this.label, this.w, this.h, this.qty, {required this.glassCode})
      : length = null,
        cut = null,
        role = null,
        kind = null;

  const BomLine.hardware(this.kind, this.w, this.h, this.qty)
      : group = BomGroup.hardware,
        label = 'Donanım',
        length = null,
        cut = null,
        role = null,
        glassCode = null;

  bool get isBar => length != null;
  bool get isHardware => group == BomGroup.hardware;

  static String _roleName(ProfileRole r) => switch (r) {
        ProfileRole.frame => 'FRAME',
        ProfileRole.sash => 'SASH',
        ProfileRole.mullion => 'MULLION',
        ProfileRole.slideSash => 'SLIDE_SASH',
        ProfileRole.adapter => 'ADAPTER',
        ProfileRole.doorSash => 'DOOR_SASH',
        ProfileRole.threshold => 'THRESHOLD',
      };

  /// Backend'in beklediği satır: {"group":"PROFILE","role":"FRAME","length":1806,"qty":2,"cut":"45/45"}
  /// Donanım: {"group":"HARDWARE","kind":"TILT_TURN","w":536,"h":1214,"qty":1}
  Map<String, dynamic> toJson() => {
        'group': group.name.toUpperCase(),
        if (role != null) 'role': _roleName(role!),
        if (kind != null) 'kind': kind,
        if (length != null) 'length': _r1(length!),
        if (w != null) 'w': _r1(w!),
        if (h != null) 'h': _r1(h!),
        if (glassCode != null && glassCode!.isNotEmpty) 'glassCode': glassCode,
        if (cut != null) 'cut': cut,
        'qty': qty,
      };

  String get _key => '${group.name}|${role?.name}|$kind|$label|${length?.toStringAsFixed(1)}|'
      '${w?.toStringAsFixed(1)}|${h?.toStringAsFixed(1)}|$cut|$glassCode';

  BomLine _withQty(int q) {
    if (isHardware) return BomLine.hardware(kind!, w!, h!, q);
    if (isBar) return BomLine.bar(group, label, length, cut, q, role: role, glassCode: glassCode);
    return BomLine.sheet(group, label, w, h, q, glassCode: glassCode!);
  }

  static double _r1(double v) => (v * 10).roundToDouble() / 10;

  /// Aynı ölçüdeki satırları adet olarak birleştirir (sıra korunur).
  static List<BomLine> aggregate(Iterable<BomLine> lines) {
    final map = <String, BomLine>{};
    for (final l in lines) {
      final k = l._key;
      final prev = map[k];
      map[k] = prev == null ? l : prev._withQty(prev.qty + l.qty);
    }
    return map.values.toList();
  }
}

/// Kanat özeti: kural kontrolü ve seçim vurgusu için.
class SashInfo {
  final List<String> fillIds;
  final Box outer;
  final bool sliding;
  final SashKind kind;
  final bool passive;
  final OpeningType? opening;

  const SashInfo({
    required this.fillIds,
    required this.outer,
    required this.sliding,
    this.kind = SashKind.window,
    this.passive = false,
    this.opening,
  });
}

class LayoutResult {
  final List<Prim> prims = [];
  final List<BomLine> bom = [];
  final List<HitArea> hits = [];
  final List<double> mullionX = [], mullionY = [];
  final List<SashInfo> sashes = [];

  /// Bölme id -> referans aralığı (mm). Bölme ölçüsünü düzenlerken kullanılır.
  final Map<String, double> splitSpans = {};

  /// Backend'e gönderilecek kesim listesi (birleştirilmiş).
  List<Map<String, dynamic>> bomJson() => BomLine.aggregate(bom).map((l) => l.toJson()).toList();

  String? hitTest(double x, double y) {
    for (final h in hits.reversed) {
      if (h.box.contains(x, y)) return h.nodeId;
    }
    return null;
  }

  Box? boxOf(String nodeId) {
    for (final h in hits) {
      if (h.nodeId == nodeId) return h.box;
    }
    return null;
  }
}

// ---------- motor ----------
class LayoutEngine {
  final SeriesGeometry s;
  const LayoutEngine(this.s);

  LayoutResult run(WindowDesign d) {
    final out = LayoutResult();
    final outer = Box(0, 0, d.width, d.height);
    final threshold = d.bottom == BottomKind.threshold;
    final inner = threshold
        ? Box(s.frameFace, s.frameFace, d.width - s.frameFace, d.height - s.thresholdFace)
        : outer.deflate(s.frameFace);
    if (threshold) {
      _frameU(out, outer, inner);
      _thresholdBom(out, outer);
      out.prims.add(BarRect(
        DrawLayer.frame,
        Box(s.frameFace, d.height - s.thresholdFace, d.width - s.frameFace, d.height),
        metallic: true,
      ));
    } else {
      _ring(out, DrawLayer.frame, outer, inner);
      _bars(out, 'Kasa', ProfileRole.frame, outer);
    }
    _area(out, d.root, inner, outer, const _Edges.all(EdgeKind.frame));
    return out;
  }

  /// Çekirdek numara: dış ve iç dikdörtgen arasında 4 gönyeli yamuk.
  void _ring(LayoutResult out, DrawLayer layer, Box o, Box i, {int z = 0}) {
    out.prims
      ..add(ProfilePoly(layer, [Pt(o.l, o.t), Pt(o.r, o.t), Pt(i.r, i.t), Pt(i.l, i.t)], ProfileSide.top, z: z))
      ..add(ProfilePoly(layer, [Pt(o.r, o.t), Pt(o.r, o.b), Pt(i.r, i.b), Pt(i.r, i.t)], ProfileSide.right, z: z))
      ..add(ProfilePoly(layer, [Pt(o.r, o.b), Pt(o.l, o.b), Pt(i.l, i.b), Pt(i.r, i.b)], ProfileSide.bottom, z: z))
      ..add(ProfilePoly(layer, [Pt(o.l, o.b), Pt(o.l, o.t), Pt(i.l, i.t), Pt(i.l, i.b)], ProfileSide.left, z: z));
  }

  /// Eşikli kasa: üst + iki yan; alt köşeler düz biter.
  void _frameU(LayoutResult out, Box o, Box i) {
    final thrTop = i.b;
    out.prims
      ..add(ProfilePoly(DrawLayer.frame, [Pt(o.l, o.t), Pt(o.r, o.t), Pt(i.r, i.t), Pt(i.l, i.t)], ProfileSide.top))
      ..add(ProfilePoly(
          DrawLayer.frame, [Pt(o.r, o.t), Pt(o.r, thrTop), Pt(i.r, thrTop), Pt(i.r, i.t)], ProfileSide.right))
      ..add(ProfilePoly(
          DrawLayer.frame, [Pt(o.l, thrTop), Pt(o.l, o.t), Pt(i.l, i.t), Pt(i.l, thrTop)], ProfileSide.left));
  }

  void _bars(LayoutResult out, String name, ProfileRole role, Box o) {
    final weld = s.weldAllowance * 2;
    out.bom
      ..add(BomLine.bar(BomGroup.profile, name, o.w + weld, '45/45', 2, role: role))
      ..add(BomLine.bar(BomGroup.profile, name, o.h + weld, '45/45', 2, role: role));
  }

  void _thresholdBom(LayoutResult out, Box outer) {
    final weld = s.weldAllowance;
    out.bom
      ..add(BomLine.bar(BomGroup.profile, 'Kasa', outer.w + 2 * weld, '45/45', 1, role: ProfileRole.frame))
      ..add(BomLine.bar(BomGroup.profile, 'Kasa', outer.h + weld, '45/90', 2, role: ProfileRole.frame))
      ..add(BomLine.bar(
        BomGroup.profile,
        'Eşik',
        (outer.w - 2 * s.frameFace) + 2 * s.thresholdEndAllowance,
        '90/90',
        1,
        role: ProfileRole.threshold,
      ));
  }

  /// [rect] net açıklık; [ref] referans çizgileri (kasa dışı veya kayıt ekseni) - ölçüler buna göre.
  void _area(LayoutResult out, DesignNode node, Box rect, Box ref, _Edges edges) {
    switch (node) {
      case SplitNode n:
        _split(out, n, rect, ref, edges);
      case SashNode n:
        final face = n.kind == SashKind.door ? s.doorSashFace : s.sashFace;
        final so = rect.inflate(s.sashLap);
        final si = so.deflate(face);
        _ring(out, DrawLayer.sash, so, si);
        final role = n.kind == SashKind.door ? ProfileRole.doorSash : ProfileRole.sash;
        final label = n.kind == SashKind.door ? 'Kapı kanadı' : 'Kanat';
        _bars(out, label, role, so);
        out.bom.add(BomLine.hardware(_hwKind(n), so.w, so.h, 1));
        out.sashes.add(SashInfo(
          fillIds: _fillIds(n.child),
          outer: so,
          sliding: false,
          kind: n.kind,
          passive: n.passive,
          opening: n.opening,
        ));
        _symbol(out, n.opening, si, dashed: n.outward);
        if (!n.passive) _handle(out, n.opening, so, face: face, door: n.kind == SashKind.door);
        _area(out, n.child, si, ref, const _Edges.all(EdgeKind.sash));
      case SlideNode n:
        final mid = rect.cx, il = s.slideInterlock, lap = s.sashLap;
        final a = Box(rect.l - lap, rect.t - lap, mid + il / 2, rect.b + lap);
        final b = Box(mid - il / 2, rect.t - lap, rect.r + lap, rect.b + lap);
        for (final (i, so, child, dir) in [(0, a, n.left, 1.0), (1, b, n.right, -1.0)]) {
          final si = so.deflate(s.sashFace);
          _ring(out, DrawLayer.sash, so, si, z: i);
          _bars(out, 'Sürme kanat', ProfileRole.slideSash, so);
          out.bom.add(BomLine.hardware('SLIDE', so.w, so.h, 1));
          out.sashes.add(SashInfo(fillIds: _fillIds(child), outer: so, sliding: true));
          _arrow(out, si, dir);
          _area(out, child, si, ref, const _Edges.all(EdgeKind.sash));
        }
      case FillNode n:
        _fill(out, n, rect, edges);
    }
  }

  void _split(LayoutResult out, SplitNode n, Box rect, Box ref, _Edges edges) {
    final v = n.dir == SplitDir.v;
    final total = n.sizes.fold<double>(0, (a, b) => a + b);
    final r0 = v ? ref.l : ref.t;
    final span = (v ? ref.r : ref.b) - r0;
    out.splitSpans[n.id] = span;
    final m = s.mullionFace;
    final adapter = n.joint == JointKind.adapter && v && n.children.length == 2;

    final centers = <double>[];
    var acc = 0.0;
    for (var i = 0; i < n.children.length - 1; i++) {
      acc += n.sizes[i];
      centers.add(r0 + span * acc / total);
    }

    if (!adapter) {
      for (final c in centers) {
        final bar = v ? Box(c - m / 2, rect.t, c + m / 2, rect.b) : Box(rect.l, c - m / 2, rect.r, c + m / 2);
        out.prims.add(BarRect(DrawLayer.mullion, bar, dir: n.dir));
        out.bom.add(BomLine.bar(BomGroup.profile, 'Orta kayıt', (v ? rect.h : rect.w) + 2 * s.mullionEndAllowance,
            '90/90', 1,
            role: ProfileRole.mullion));
        (v ? out.mullionX : out.mullionY).add(c);
      }
    }

    final last = n.children.length - 1;
    Box? leftOuter;
    Box? rightOuter;
    for (var i = 0; i <= last; i++) {
      final double lo;
      final double hi;
      if (adapter) {
        final c = centers.first;
        lo = i == 0 ? (v ? rect.l : rect.t) : c + s.sashLap;
        hi = i == last ? (v ? rect.r : rect.b) : c - s.sashLap;
      } else {
        lo = i == 0 ? (v ? rect.l : rect.t) : centers[i - 1] + m / 2;
        hi = i == last ? (v ? rect.r : rect.b) : centers[i] - m / 2;
      }
      final refLo = i == 0 ? (v ? ref.l : ref.t) : centers[i - 1];
      final refHi = i == last ? (v ? ref.r : ref.b) : centers[i];
      final cr = v ? Box(lo, rect.t, hi, rect.b) : Box(rect.l, lo, rect.r, hi);
      final cref = v ? Box(refLo, ref.t, refHi, ref.b) : Box(ref.l, refLo, ref.r, refHi);
      final ce = adapter
          ? edges
          : (v
              ? edges.copyWith(l: i > 0 ? EdgeKind.mullion : null, r: i < last ? EdgeKind.mullion : null)
              : edges.copyWith(t: i > 0 ? EdgeKind.mullion : null, b: i < last ? EdgeKind.mullion : null));
      if (adapter) {
        final so = cr.inflate(s.sashLap);
        if (i == 0) {
          leftOuter = so;
        } else {
          rightOuter = so;
        }
      }
      _area(out, n.children[i], cr, cref, ce);
    }

    if (adapter && centers.isNotEmpty) {
      final c = centers.first;
      final left = n.children[0];
      final right = n.children[1];
      final leftPassive = left is SashNode && left.passive;
      final rightPassive = right is SashNode && right.passive;
      final so = leftPassive
          ? leftOuter
          : (rightPassive ? rightOuter : leftOuter);
      if (so != null) {
        out.prims.add(BarRect(
          DrawLayer.adapter,
          Box(c - s.adapterFace / 2, so.t, c + s.adapterFace / 2, so.b),
        ));
        out.bom.add(BomLine.bar(BomGroup.profile, 'Adaptör', so.h, '90/90', 1, role: ProfileRole.adapter));
      }
    }
  }

  void _fill(LayoutResult out, FillNode n, Box rect, _Edges e) {
    // 1) çıta halkası  2) görünen cam  3) gerçek cam ölçüsü (profil altına giren pay dahil)
    final vis = rect.deflate(s.beadFace);
    _ring(out, DrawLayer.bead, rect, vis);
    out.bom
      ..add(BomLine.bar(BomGroup.bead, 'Cam çıtası', rect.w, '45/45', 2, glassCode: n.glassCode))
      ..add(BomLine.bar(BomGroup.bead, 'Cam çıtası', rect.h, '45/45', 2, glassCode: n.glassCode));

    final gw = rect.w + s.rebateFor(e.l) + s.rebateFor(e.r);
    final gh = rect.h + s.rebateFor(e.t) + s.rebateFor(e.b);
    out.prims.add(GlassPrim(n.id, vis, gw, gh, n.glassCode, n.fill));
    out.prims.add(TextPrim(DrawLayer.label, Pt(vis.cx, vis.cy), n.glassCode));
    out.bom.add(BomLine.sheet(
      n.fill == FillType.panel ? BomGroup.panel : BomGroup.glass,
      n.fill == FillType.panel ? 'Panel' : 'Cam',
      gw,
      gh,
      1,
      glassCode: n.glassCode,
    ));

    if (n.fill == FillType.glass) {
      final dw = s.duplexWidth;
      for (var i = 1; i < n.duplexCols; i++) {
        final x = vis.l + vis.w * i / n.duplexCols;
        out.prims.add(BarRect(DrawLayer.duplex, Box(x - dw / 2, vis.t, x + dw / 2, vis.b)));
      }
      for (var j = 1; j < n.duplexRows; j++) {
        final y = vis.t + vis.h * j / n.duplexRows;
        out.prims.add(BarRect(DrawLayer.duplex, Box(vis.l, y - dw / 2, vis.r, y + dw / 2)));
      }
      if (n.duplexCols > 1) {
        out.bom.add(BomLine.bar(BomGroup.duplex, 'Dubleks', vis.h, '90/90', n.duplexCols - 1));
      }
      if (n.duplexRows > 1) {
        out.bom.add(BomLine.bar(BomGroup.duplex, 'Dubleks', vis.w, '90/90', n.duplexRows - 1));
      }
    }
    out.hits.add(HitArea(n.id, rect));
  }

  static String _hwKind(SashNode n) {
    if (n.kind == SashKind.door) return n.passive ? 'DOOR_PASSIVE' : 'DOOR';
    if (n.passive) return 'PASSIVE';
    return switch (n.opening) {
      OpeningType.turnLeft || OpeningType.turnRight => 'TURN',
      OpeningType.tilt => 'TILT',
      OpeningType.tiltTurnLeft || OpeningType.tiltTurnRight => 'TILT_TURN',
    };
  }

  static List<String> _fillIds(DesignNode node) => switch (node) {
        FillNode n => [n.id],
        SashNode n => _fillIds(n.child),
        SlideNode n => [..._fillIds(n.left), ..._fillIds(n.right)],
        SplitNode n => [for (final c in n.children) ..._fillIds(c)],
      };

  /// DIN/EN çizim kuralı: üçgenin tepesi menteşe tarafını gösterir.
  void _symbol(LayoutResult out, OpeningType o, Box r, {bool dashed = false}) {
    void line(List<Pt> p) => out.prims.add(PolylinePrim(DrawLayer.symbol, p, dashed: dashed));
    final hingeLeft = o == OpeningType.turnLeft || o == OpeningType.tiltTurnLeft;
    final hingeRight = o == OpeningType.turnRight || o == OpeningType.tiltTurnRight;
    final tilt = o == OpeningType.tilt || o == OpeningType.tiltTurnLeft || o == OpeningType.tiltTurnRight;
    if (hingeLeft) line([Pt(r.r, r.t), Pt(r.l, r.cy), Pt(r.r, r.b)]);
    if (hingeRight) line([Pt(r.l, r.t), Pt(r.r, r.cy), Pt(r.l, r.b)]);
    if (tilt) line([Pt(r.l, r.t), Pt(r.cx, r.b), Pt(r.r, r.t)]);
  }

  void _handle(LayoutResult out, OpeningType o, Box so, {required double face, required bool door}) {
    final f = face;
    final bw = door ? f * .48 : f * .42;
    final bh = door ? 96.0 : 64.0;
    final lw = door ? 22.0 : 16.0;
    final ll = door ? 170.0 : 120.0;
    final onRight = o == OpeningType.turnLeft || o == OpeningType.tiltTurnLeft;
    final onLeft = o == OpeningType.turnRight || o == OpeningType.tiltTurnRight;
    if (onRight || onLeft) {
      final x = onRight ? so.r - f / 2 : so.l + f / 2;
      final base = Box.xywh(x - bw / 2, so.cy - bh / 2, bw, bh);
      final lever = Box.xywh(x - lw / 2, so.cy, lw, ll);
      Box? lock;
      if (door) {
        final ls = math.min(f * .28, 22.0);
        lock = Box.xywh(x - ls / 2, so.cy - bh / 2 - ls * 1.4, ls, ls);
      }
      out.prims.add(HandlePrim(base, lever, lock: lock));
    } else {
      final y = so.t + f / 2;
      out.prims.add(HandlePrim(Box.xywh(so.cx - bh / 2, y - bw / 2, bh, bw), Box.xywh(so.cx, y - lw / 2, ll, lw)));
    }
  }

  void _arrow(LayoutResult out, Box r, double dir) {
    final len = math.min(r.w * .5, 360.0), hd = 40.0;
    final x0 = r.cx - dir * len / 2, x1 = r.cx + dir * len / 2;
    out.prims
      ..add(PolylinePrim(DrawLayer.symbol, [Pt(x0, r.cy), Pt(x1, r.cy)]))
      ..add(PolylinePrim(
          DrawLayer.symbol, [Pt(x1 - dir * hd, r.cy - hd * .6), Pt(x1, r.cy), Pt(x1 - dir * hd, r.cy + hd * .6)]));
  }
}

class _Edges {
  final EdgeKind l, r, t, b;
  const _Edges(this.l, this.r, this.t, this.b);
  const _Edges.all(EdgeKind k) : this(k, k, k, k);
  _Edges copyWith({EdgeKind? l, EdgeKind? r, EdgeKind? t, EdgeKind? b}) =>
      _Edges(l ?? this.l, r ?? this.r, t ?? this.t, b ?? this.b);
}
