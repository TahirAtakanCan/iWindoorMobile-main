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
enum DrawLayer { glass, duplex, bead, mullion, frame, sash, hardware, symbol, label, dims }

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
  const BarRect(super.layer, this.box, {this.dir, super.z});
}

class GlassPrim extends Prim {
  final String nodeId;
  final Box visible; // çıta içinde görünen cam
  final String glassCode;
  final FillType fill;
  const GlassPrim(this.nodeId, this.visible, this.glassCode, this.fill) : super(DrawLayer.glass);
}

class PolylinePrim extends Prim {
  final List<Pt> pts;
  const PolylinePrim(super.layer, this.pts);
}

class HandlePrim extends Prim {
  final Box base, lever;
  const HandlePrim(this.base, this.lever) : super(DrawLayer.hardware);
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
enum BomGroup { profile, bead, duplex, glass, panel }

/// Profil satırının rolü: sunucu bunu serideki ilgili profile eşler.
enum ProfileRole { frame, sash, mullion, slideSash }

class BomLine {
  final BomGroup group;
  final ProfileRole? role;
  final String label; // ekranda gösterilecek ad
  final double? length; // çubuk ise (mm)
  final double? w, h; // cam/panel ise (mm)
  final String? cut; // "45/45" , "90/90"
  final String? glassCode; // cam/panel kodu; çıtada camın kodu (kalınlığa göre çıta seçimi için)
  final int qty;

  const BomLine.bar(this.group, this.label, this.length, this.cut, this.qty, {this.role, this.glassCode})
      : w = null,
        h = null;

  const BomLine.sheet(this.group, this.label, this.w, this.h, this.qty, {required this.glassCode})
      : length = null,
        cut = null,
        role = null;

  bool get isBar => length != null;

  static String _roleName(ProfileRole r) => switch (r) {
        ProfileRole.frame => 'FRAME',
        ProfileRole.sash => 'SASH',
        ProfileRole.mullion => 'MULLION',
        ProfileRole.slideSash => 'SLIDE_SASH',
      };

  /// Backend'in beklediği satır: {"group":"PROFILE","role":"FRAME","length":1806,"qty":2,"cut":"45/45"}
  Map<String, dynamic> toJson() => {
        'group': group.name.toUpperCase(),
        if (role != null) 'role': _roleName(role!),
        if (length != null) 'length': _r1(length!),
        if (w != null) 'w': _r1(w!),
        if (h != null) 'h': _r1(h!),
        if (glassCode != null && glassCode!.isNotEmpty) 'glassCode': glassCode,
        if (cut != null) 'cut': cut,
        'qty': qty,
      };

  String get _key => '${group.name}|${role?.name}|$label|${length?.toStringAsFixed(1)}|'
      '${w?.toStringAsFixed(1)}|${h?.toStringAsFixed(1)}|$cut|$glassCode';

  BomLine _withQty(int q) => isBar
      ? BomLine.bar(group, label, length, cut, q, role: role, glassCode: glassCode)
      : BomLine.sheet(group, label, w, h, q, glassCode: glassCode);

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

class LayoutResult {
  final List<Prim> prims = [];
  final List<BomLine> bom = [];
  final List<HitArea> hits = [];
  final List<double> mullionX = [], mullionY = [];

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
    final inner = outer.deflate(s.frameFace);
    _ring(out, DrawLayer.frame, outer, inner);
    _bars(out, 'Kasa', ProfileRole.frame, outer);
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

  void _bars(LayoutResult out, String name, ProfileRole role, Box o) {
    final weld = s.weldAllowance * 2;
    out.bom
      ..add(BomLine.bar(BomGroup.profile, name, o.w + weld, '45/45', 2, role: role))
      ..add(BomLine.bar(BomGroup.profile, name, o.h + weld, '45/45', 2, role: role));
  }

  /// [rect] net açıklık; [ref] referans çizgileri (kasa dışı veya kayıt ekseni) - ölçüler buna göre.
  void _area(LayoutResult out, DesignNode node, Box rect, Box ref, _Edges edges) {
    switch (node) {
      case SplitNode n:
        _split(out, n, rect, ref, edges);
      case SashNode n:
        final so = rect.inflate(s.sashLap);
        final si = so.deflate(s.sashFace);
        _ring(out, DrawLayer.sash, so, si);
        _bars(out, 'Kanat', ProfileRole.sash, so);
        _symbol(out, n.opening, si);
        _handle(out, n.opening, so);
        _area(out, n.child, si, ref, const _Edges.all(EdgeKind.sash));
      case SlideNode n:
        final mid = rect.cx, il = s.slideInterlock, lap = s.sashLap;
        final a = Box(rect.l - lap, rect.t - lap, mid + il / 2, rect.b + lap);
        final b = Box(mid - il / 2, rect.t - lap, rect.r + lap, rect.b + lap);
        for (final (i, so, child, dir) in [(0, a, n.left, 1.0), (1, b, n.right, -1.0)]) {
          final si = so.deflate(s.sashFace);
          _ring(out, DrawLayer.sash, so, si, z: i);
          _bars(out, 'Sürme kanat', ProfileRole.slideSash, so);
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

    final centers = <double>[];
    var acc = 0.0;
    for (var i = 0; i < n.children.length - 1; i++) {
      acc += n.sizes[i];
      centers.add(r0 + span * acc / total);
    }
    for (final c in centers) {
      final bar = v ? Box(c - m / 2, rect.t, c + m / 2, rect.b) : Box(rect.l, c - m / 2, rect.r, c + m / 2);
      out.prims.add(BarRect(DrawLayer.mullion, bar, dir: n.dir));
      out.bom.add(BomLine.bar(BomGroup.profile, 'Orta kayıt', (v ? rect.h : rect.w) + 2 * s.mullionEndAllowance,
          '90/90', 1,
          role: ProfileRole.mullion));
      (v ? out.mullionX : out.mullionY).add(c);
    }

    final last = n.children.length - 1;
    for (var i = 0; i <= last; i++) {
      final lo = i == 0 ? (v ? rect.l : rect.t) : centers[i - 1] + m / 2;
      final hi = i == last ? (v ? rect.r : rect.b) : centers[i] - m / 2;
      final refLo = i == 0 ? (v ? ref.l : ref.t) : centers[i - 1];
      final refHi = i == last ? (v ? ref.r : ref.b) : centers[i];
      final cr = v ? Box(lo, rect.t, hi, rect.b) : Box(rect.l, lo, rect.r, hi);
      final cref = v ? Box(refLo, ref.t, refHi, ref.b) : Box(ref.l, refLo, ref.r, refHi);
      final ce = v
          ? edges.copyWith(l: i > 0 ? EdgeKind.mullion : null, r: i < last ? EdgeKind.mullion : null)
          : edges.copyWith(t: i > 0 ? EdgeKind.mullion : null, b: i < last ? EdgeKind.mullion : null);
      _area(out, n.children[i], cr, cref, ce);
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
    out.prims.add(GlassPrim(n.id, vis, n.glassCode, n.fill));
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

  /// DIN/EN çizim kuralı: üçgenin tepesi menteşe tarafını gösterir.
  void _symbol(LayoutResult out, OpeningType o, Box r) {
    void line(List<Pt> p) => out.prims.add(PolylinePrim(DrawLayer.symbol, p));
    final hingeLeft = o == OpeningType.turnLeft || o == OpeningType.tiltTurnLeft;
    final hingeRight = o == OpeningType.turnRight || o == OpeningType.tiltTurnRight;
    final tilt = o == OpeningType.tilt || o == OpeningType.tiltTurnLeft || o == OpeningType.tiltTurnRight;
    if (hingeLeft) line([Pt(r.r, r.t), Pt(r.l, r.cy), Pt(r.r, r.b)]);
    if (hingeRight) line([Pt(r.l, r.t), Pt(r.r, r.cy), Pt(r.l, r.b)]);
    if (tilt) line([Pt(r.l, r.t), Pt(r.cx, r.b), Pt(r.r, r.t)]);
  }

  void _handle(LayoutResult out, OpeningType o, Box so) {
    final f = s.sashFace, bw = f * .42, bh = 64.0, lw = 16.0, ll = 120.0;
    final onRight = o == OpeningType.turnLeft || o == OpeningType.tiltTurnLeft;
    final onLeft = o == OpeningType.turnRight || o == OpeningType.tiltTurnRight;
    if (onRight || onLeft) {
      final x = onRight ? so.r - f / 2 : so.l + f / 2;
      out.prims.add(HandlePrim(Box.xywh(x - bw / 2, so.cy - bh / 2, bw, bh), Box.xywh(x - lw / 2, so.cy, lw, ll)));
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
