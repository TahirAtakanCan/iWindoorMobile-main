// Yerleşim motoru: WindowDesign + SeriesGeometry  ->  primitifler + kesim listesi.
// Saf Dart: Flutter'a bağımlı değil. Mobil, masaüstü, PDF ve testler aynı kodu kullanır.

import 'dart:math' as math;
import 'catalog.dart';
import 'model.dart';
import 'shape_geometry.dart';

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
enum DrawLayer { glass, duplex, screen, bead, mullion, frame, coupling, sash, adapter, hardware, symbol, label, dims }

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
  final List<Pt>? clip;
  final String? shapeType;
  const GlassPrim(
    this.nodeId,
    this.visible,
    this.cutW,
    this.cutH,
    this.glassCode,
    this.fill, {
    this.clip,
    this.shapeType,
  }) : super(DrawLayer.glass);
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
  final List<Pt>? polygon;
  const HitArea(this.nodeId, this.box, {this.polygon});
}

// ---------- kesim listesi (backend BomPricer biçimi) ----------
enum BomGroup { profile, bead, duplex, glass, panel, hardware, color, screen, shutter, extra }

/// Profil satırının rolü: sunucu bunu serideki ilgili profile eşler.
enum ProfileRole { frame, sash, mullion, slideSash, adapter, doorSash, threshold, coupling, extension }

class BomLine {
  final BomGroup group;
  final ProfileRole? role;
  final String label; // ekranda gösterilecek ad
  final double? length; // çubuk ise (mm)
  final double? w, h; // cam/panel / donanım kanat ölçüsü (mm)
  final String? cut; // "45/45" , "90/90" , "45/90"
  final String? glassCode; // cam/panel kodu; çıtada camın kodu (kalınlığa göre çıta seçimi için)
  final String? kind; // donanım: TURN | TILT | TILT_TURN | SLIDE | PASSIVE | DOOR | DOOR_PASSIVE
  final String? colorCode;
  final int qty;
  final bool bent;
  final double? radius;
  final String? shape;
  final String? slat;
  final String? drive;

  const BomLine.bar(
    this.group,
    this.label,
    this.length,
    this.cut,
    this.qty, {
    this.role,
    this.glassCode,
    this.bent = false,
    this.radius,
    this.shape,
  })  : w = null,
        h = null,
        kind = null,
        colorCode = null,
        slat = null,
        drive = null;

  BomLine.barBent(
    this.group,
    this.label,
    this.length,
    this.cut,
    this.qty,
    this.radius, {
    this.role,
    this.glassCode,
  })  : w = null,
        h = null,
        kind = null,
        colorCode = null,
        bent = true,
        shape = null,
        slat = null,
        drive = null;

  const BomLine.sheet(
    this.group,
    this.label,
    this.w,
    this.h,
    this.qty, {
    required this.glassCode,
    this.shape,
  })  : length = null,
        cut = null,
        role = null,
        kind = null,
        colorCode = null,
        bent = false,
        radius = null,
        slat = null,
        drive = null;

  const BomLine.hardware(this.kind, this.w, this.h, this.qty)
      : group = BomGroup.hardware,
        label = 'Donanım',
        length = null,
        cut = null,
        role = null,
        glassCode = null,
        colorCode = null,
        bent = false,
        radius = null,
        shape = null,
        slat = null,
        drive = null;

  const BomLine.color(this.colorCode)
      : group = BomGroup.color,
        label = 'Renk farkı',
        length = null,
        w = null,
        h = null,
        cut = null,
        role = null,
        kind = null,
        glassCode = null,
        qty = 1,
        bent = false,
        radius = null,
        shape = null,
        slat = null,
        drive = null;

  BomLine.screen(ScreenKind screenKind, this.w, this.h, this.qty)
      : group = BomGroup.screen,
        label = 'Sineklik',
        kind = switch (screenKind) {
          ScreenKind.plise => 'PLISE',
          ScreenKind.hinged => 'HINGED',
          ScreenKind.sliding => 'SLIDING',
        },
        length = null,
        cut = null,
        role = null,
        glassCode = null,
        colorCode = null,
        bent = false,
        radius = null,
        shape = null,
        slat = null,
        drive = null;

  BomLine.shutter({
    required this.kind,
    required this.slat,
    required this.drive,
    required this.w,
    required this.h,
    this.qty = 1,
  })  : group = BomGroup.shutter,
        label = 'Panjur',
        length = null,
        cut = null,
        role = null,
        glassCode = null,
        colorCode = null,
        bent = false,
        radius = null,
        shape = null;

  BomLine.extra(this.kind, this.label, this.length, this.cut, this.qty)
      : group = BomGroup.extra,
        role = null,
        w = null,
        h = null,
        glassCode = null,
        colorCode = null,
        bent = false,
        radius = null,
        shape = null,
        slat = null,
        drive = null;

  bool get isBar => length != null;
  bool get isHardware => group == BomGroup.hardware;
  bool get isColor => group == BomGroup.color;
  bool get isScreen => group == BomGroup.screen;

  static String _roleName(ProfileRole r) => switch (r) {
        ProfileRole.frame => 'FRAME',
        ProfileRole.sash => 'SASH',
        ProfileRole.mullion => 'MULLION',
        ProfileRole.slideSash => 'SLIDE_SASH',
        ProfileRole.adapter => 'ADAPTER',
        ProfileRole.doorSash => 'DOOR_SASH',
        ProfileRole.threshold => 'THRESHOLD',
        ProfileRole.coupling => 'COUPLING',
        ProfileRole.extension => 'EXTENSION',
      };

  /// Backend'in beklediği satır: {"group":"PROFILE","role":"FRAME","length":1806,"qty":2,"cut":"45/45"}
  /// Donanım: {"group":"HARDWARE","kind":"TILT_TURN","w":536,"h":1214,"qty":1}
  /// Renk: {"group":"COLOR","colorCode":"ANT-1","qty":1}
  Map<String, dynamic> toJson() => {
        'group': group.name.toUpperCase(),
        if (role != null) 'role': _roleName(role!),
        if (kind != null) 'kind': kind,
        if (colorCode != null) 'colorCode': colorCode,
        if (length != null) 'length': _r1(length!),
        if (w != null) 'w': _r1(w!),
        if (h != null) 'h': _r1(h!),
        if (glassCode != null && glassCode!.isNotEmpty) 'glassCode': glassCode,
        if (cut != null) 'cut': cut,
        if (bent) 'bent': true,
        if (radius != null) 'radius': _r1(radius!),
        if (shape != null) 'shape': shape,
        if (slat != null) 'slat': slat,
        if (drive != null) 'drive': drive,
        'qty': qty,
      };

  String get _key =>
      '${group.name}|${role?.name}|$kind|$colorCode|$label|${length?.toStringAsFixed(1)}|'
      '${w?.toStringAsFixed(1)}|${h?.toStringAsFixed(1)}|$cut|$glassCode|$bent|${radius?.toStringAsFixed(1)}|$shape|$slat|$drive';

  BomLine _withQty(int q) {
    if (group == BomGroup.shutter) {
      return BomLine.shutter(kind: kind!, slat: slat!, drive: drive!, w: w!, h: h!, qty: q);
    }
    if (group == BomGroup.extra) {
      return BomLine.extra(kind!, label, length!, cut!, q);
    }
    if (isColor) return BomLine.color(colorCode);
    if (isHardware) return BomLine.hardware(kind!, w!, h!, q);
    if (isScreen) {
      final sk = switch ((kind ?? '').toUpperCase()) {
        'HINGED' => ScreenKind.hinged,
        'SLIDING' => ScreenKind.sliding,
        _ => ScreenKind.plise,
      };
      return BomLine.screen(sk, w!, h!, q);
    }
    if (isBar) {
      if (bent) {
        return BomLine.barBent(group, label, length, cut, q, radius!, role: role, glassCode: glassCode);
      }
      return BomLine.bar(
        group,
        label,
        length,
        cut,
        q,
        role: role,
        glassCode: glassCode,
        bent: bent,
        radius: radius,
        shape: shape,
      );
    }
    return BomLine.sheet(group, label, w, h, q, glassCode: glassCode!, shape: shape);
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
  final SlideMove? slideMove;
  final SlideSystem? slideSystem;
  final String? slideNodeId;

  const SashInfo({
    required this.fillIds,
    required this.outer,
    required this.sliding,
    this.kind = SashKind.window,
    this.passive = false,
    this.opening,
    this.slideMove,
    this.slideSystem,
    this.slideNodeId,
  });
}

class FrameBox {
  final String id;
  final Box box;
  const FrameBox(this.id, this.box);
}

class LayoutResult {
  final List<Prim> prims = [];
  final List<BomLine> bom = [];
  final List<HitArea> hits = [];
  final List<double> mullionX = [], mullionY = [];
  final List<SashInfo> sashes = [];
  final List<FrameBox> frames = [];

  /// Bölme id -> referans aralığı (mm). Bölme ölçüsünü düzenlerken kullanılır.
  final Map<String, double> splitSpans = {};

  Box? sceneBounds;
  double dimWidth = 0;
  double dimHeight = 0;

  /// Backend'e gönderilecek kesim listesi (birleştirilmiş).
  List<Map<String, dynamic>> bomJson() => BomLine.aggregate(bom).map((l) => l.toJson()).toList();

  String? hitTest(double x, double y) {
    for (final h in hits.reversed) {
      if (h.polygon != null) {
        final poly = [for (final p in h.polygon!) ShapePt(p.x, p.y)];
        if (pointInPolygon(x, y, poly)) return h.nodeId;
      } else if (h.box.contains(x, y)) {
        return h.nodeId;
      }
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
    final root = d.root;
    if (root is CoupleNode) {
      _runCouple(out, d, root);
    } else {
      final outer = Box(0, 0, d.width, d.height);
      out.frames.add(FrameBox('root', outer));
      if (d.shape.isRect) {
        _frame(out, outer, d.bottom, root);
      } else {
        _shapedFrame(out, outer, d.bottom, d.shape, root, d.width, d.height);
      }
    }
    if (d.colorCode != 'white' && d.colorCode.isNotEmpty) {
      out.bom.add(BomLine.color(d.colorCode));
    }
    _addShutterAndExtras(out, d);
    _finalizeSceneBounds(out, d.width, d.height);
    return out;
  }

  void _finalizeSceneBounds(LayoutResult out, double w, double h) {
    var l = 0.0, t = 0.0, r = w, b = h;
    for (final p in out.prims) {
      void consider(double x, double y) {
        if (x < l) l = x;
        if (y < t) t = y;
        if (x > r) r = x;
        if (y > b) b = y;
      }

      switch (p) {
        case BarRect b:
          consider(b.box.l, b.box.t);
          consider(b.box.r, b.box.b);
        case PolylinePrim pl:
          for (final pt in pl.pts) {
            consider(pt.x, pt.y);
          }
        case ProfilePoly pp:
          for (final pt in pp.pts) {
            consider(pt.x, pt.y);
          }
        case GlassPrim g:
          consider(g.visible.l, g.visible.t);
          consider(g.visible.r, g.visible.b);
        case HandlePrim h:
          consider(h.base.l, h.base.t);
          consider(h.base.r, h.base.b);
          consider(h.lever.l, h.lever.t);
          consider(h.lever.r, h.lever.b);
          if (h.lock != null) {
            consider(h.lock!.l, h.lock!.t);
            consider(h.lock!.r, h.lock!.b);
          }
        case TextPrim _:
          break;
      }
    }
    out.sceneBounds = Box(l, t, r, b);
    out.dimWidth = r - l;
    out.dimHeight = b - t;
  }

  void _addShutterAndExtras(LayoutResult out, WindowDesign d) {
    final w = d.width;
    final h = d.height;
  final boxH = s.shutterBoxHeight;
    final trimW = s.trimWidth;
    final overhang = s.sillOverhang;
    final trimVis = trimW / 4;
    const sillThick = 20.0;

    if (d.shutter != null) {
      final sh = d.shutter!;
      final kind = sh.type == ShutterType.mono ? 'MONO' : 'EXTERNAL';
      final slat = sh.slat == ShutterSlat.aluminum ? 'ALUMINUM' : 'PVC';
      final drive = sh.drive == ShutterDrive.manual ? 'MANUAL' : 'MOTOR';
      out.bom.add(BomLine.shutter(
        kind: kind,
        slat: slat,
        drive: drive,
        w: w,
        h: h + boxH,
      ));
      final box = Box(0, -boxH, w, 0);
      out.prims.add(BarRect(DrawLayer.frame, box, metallic: true));
      final lamellaStep = 28.0;
      for (var y = -boxH + lamellaStep / 2; y < -2; y += lamellaStep) {
        out.prims.add(PolylinePrim(DrawLayer.frame, [Pt(4, y), Pt(w - 4, y)]));
      }
      const railW = 8.0;
      out.prims
        ..add(BarRect(DrawLayer.frame, Box(-railW, -boxH, 0, h), metallic: true))
        ..add(BarRect(DrawLayer.frame, Box(w, -boxH, w + railW, h), metallic: true));
    }

    final ex = d.extras;
    if (ex.sillOuter) {
      final len = w + 2 * overhang;
      out.bom.add(BomLine.extra('SILL_OUTER', 'Dış denizlik', len, '90/90', 1));
      out.prims.add(BarRect(DrawLayer.frame, Box(-overhang, h, w + overhang, h + sillThick)));
    }
    if (ex.sillInner) {
      final len = w + 2 * overhang;
      out.bom.add(BomLine.extra('SILL_INNER', 'İç denizlik', len, '90/90', 1));
      out.prims.add(BarRect(DrawLayer.bead, Box(4, h - 2, w - 4, h + sillThick - 6)));
    }
    if (ex.trim == TrimKind.three) {
      final topLen = w + 2 * trimW;
      final sideLen = h + trimW;
      out.bom
        ..add(BomLine.extra('TRIM', 'Pervaz', topLen, '45/45', 1))
        ..add(BomLine.extra('TRIM', 'Pervaz', sideLen, '45/90', 2));
      out.prims
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, -trimVis, w + trimVis, 0)))
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, 0, 0, h)))
        ..add(BarRect(DrawLayer.frame, Box(w, 0, w + trimVis, h)))
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, h, w + trimVis, h + trimVis)));
    } else if (ex.trim == TrimKind.four) {
      final horizLen = w + 2 * trimW;
      final vertLen = h + 2 * trimW;
      out.bom
        ..add(BomLine.extra('TRIM', 'Pervaz', horizLen, '45/45', 2))
        ..add(BomLine.extra('TRIM', 'Pervaz', vertLen, '45/45', 2));
      out.prims
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, -trimVis, w + trimVis, 0)))
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, h, w + trimVis, h + trimVis)))
        ..add(BarRect(DrawLayer.frame, Box(-trimVis, 0, 0, h)))
        ..add(BarRect(DrawLayer.frame, Box(w, 0, w + trimVis, h)));
    }
    final ext = ex.extension;
    if (ext.top > 0) {
      out.bom.add(BomLine.bar(BomGroup.profile, 'Kasa genişletme', w, '90/90', 1, role: ProfileRole.extension));
      out.prims.add(BarRect(DrawLayer.frame, Box(0, -ext.top, w, 0)));
    }
    if (ext.bottom > 0) {
      out.bom.add(BomLine.bar(BomGroup.profile, 'Kasa genişletme', w, '90/90', 1, role: ProfileRole.extension));
      out.prims.add(BarRect(DrawLayer.frame, Box(0, h, w, h + ext.bottom)));
    }
    if (ext.left > 0) {
      out.bom.add(BomLine.bar(BomGroup.profile, 'Kasa genişletme', h, '90/90', 1, role: ProfileRole.extension));
      out.prims.add(BarRect(DrawLayer.frame, Box(-ext.left, 0, 0, h)));
    }
    if (ext.right > 0) {
      out.bom.add(BomLine.bar(BomGroup.profile, 'Kasa genişletme', h, '90/90', 1, role: ProfileRole.extension));
      out.prims.add(BarRect(DrawLayer.frame, Box(w, 0, w + ext.right, h)));
    }
  }

  void _runCouple(LayoutResult out, WindowDesign d, CoupleNode couple) {
    final n = couple.children.length;
    if (n == 0) return;
    final gap = s.couplingGap;
    final total = couple.sizes.fold<double>(0, (a, b) => a + b);
    final boxes = <Box>[];
    if (couple.dir == SplitDir.v) {
      final usable = d.width - (n - 1) * gap;
      var x = 0.0;
      for (var i = 0; i < n; i++) {
        final w = usable * couple.sizes[i] / total;
        final h = couple.children[i].height ?? d.height;
        final box = Box(x, 0, x + w, h);
        boxes.add(box);
        out.frames.add(FrameBox(couple.children[i].id, box));
        _frameBody(out, box, couple.children[i].bottom, couple.children[i].shape, couple.children[i].child, w, h);
        x += w + gap;
      }
      for (var i = 0; i < n - 1; i++) {
        final a = boxes[i], b = boxes[i + 1];
        final commonH = math.min(a.h, b.h);
        final cx = a.r + gap / 2;
        out.prims.add(BarRect(
          DrawLayer.coupling,
          Box(cx - s.couplingFace / 2, 0, cx + s.couplingFace / 2, commonH),
        ));
        out.bom.add(BomLine.bar(
          BomGroup.profile,
          'Birleştirme profili',
          commonH,
          '90/90',
          1,
          role: ProfileRole.coupling,
        ));
      }
    } else {
      final usable = d.height - (n - 1) * gap;
      var y = 0.0;
      for (var i = 0; i < n; i++) {
        final h = usable * couple.sizes[i] / total;
        final w = couple.children[i].width ?? d.width;
        final box = Box(0, y, w, y + h);
        boxes.add(box);
        out.frames.add(FrameBox(couple.children[i].id, box));
        _frameBody(out, box, couple.children[i].bottom, couple.children[i].shape, couple.children[i].child, w, h);
        y += h + gap;
      }
      for (var i = 0; i < n - 1; i++) {
        final a = boxes[i], b = boxes[i + 1];
        final commonW = math.min(a.w, b.w);
        final cy = a.b + gap / 2;
        out.prims.add(BarRect(
          DrawLayer.coupling,
          Box(0, cy - s.couplingFace / 2, commonW, cy + s.couplingFace / 2),
        ));
        out.bom.add(BomLine.bar(
          BomGroup.profile,
          'Birleştirme profili',
          commonW,
          '90/90',
          1,
          role: ProfileRole.coupling,
        ));
      }
    }
  }

  void _frameBody(
    LayoutResult out,
    Box outer,
    BottomKind bottom,
    FrameShape shape,
    DesignNode child,
    double w,
    double h,
  ) {
    if (shape.isRect) {
      _frame(out, outer, bottom, child);
    } else {
      _shapedFrame(out, outer, bottom, shape, child, w, h);
    }
  }

  static List<Pt> _pts(List<ShapePt> poly) => [for (final p in poly) Pt(p.x, p.y)];

  static Box _bounds(List<Pt> pts) {
    var l = pts.first.x, r = pts.first.x, t = pts.first.y, b = pts.first.y;
    for (final p in pts) {
      if (p.x < l) l = p.x;
      if (p.x > r) r = p.x;
      if (p.y < t) t = p.y;
      if (p.y > b) b = p.y;
    }
    return Box(l, t, r, b);
  }

  void _polyStrip(
    LayoutResult out,
    DrawLayer layer,
    List<Pt> outer,
    List<Pt> inner, {
    int z = 0,
    ProfileSide side = ProfileSide.top,
  }) {
    final n = outer.length;
    for (var i = 0; i < n; i++) {
      final j = (i + 1) % n;
      out.prims.add(ProfilePoly(layer, [outer[i], outer[j], inner[j], inner[i]], side, z: z));
    }
  }

  double _arcPhiDeg(double thetaRad) => round1(45 + degFromRad(thetaRad) / 4);

  void _shapedFrameBom(LayoutResult out, FrameShape shape, double w, double h, ShapeOutline outline) {
    final weld = s.weldAllowance;
    switch (shape) {
      case ArchShape _ || SegmentArchShape _:
        final r = outline.leftSpringY;
        final sideLen = (h - r) + weld;
        final arcR = outline.arcRadius ?? w / 2;
        final theta = outline.arcTheta ?? math.pi;
        final arcLen = arcR * theta + 2 * weld;
        final phi = _arcPhiDeg(theta);
        final cutSide = formatCut(45, phi);
        final cutArc = formatCut(phi, phi);
        out.bom
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', w + 2 * weld, '45/45', 1, role: ProfileRole.frame))
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', sideLen, cutSide, 2, role: ProfileRole.frame))
          ..add(BomLine.barBent(
            BomGroup.profile,
            'Kasa',
            arcLen,
            cutArc,
            1,
            arcR,
            role: ProfileRole.frame,
          ));
      case TrapezoidShape t:
        final hl = t.leftHeight, hr = t.rightHeight;
        final dh = (hl - hr).abs();
        final alpha = math.atan(dh / w);
        final highLeft = hl >= hr;
        final mHigh = round1((90 - degFromRad(alpha)) / 2);
        final mLow = round1((90 + degFromRad(alpha)) / 2);
        final topLen = math.sqrt(w * w + dh * dh) + 2 * weld;
        final cutTop = highLeft ? formatCut(mHigh, mLow) : formatCut(mLow, mHigh);
        final cutLeft = formatCut(45, highLeft ? mHigh : mLow);
        final cutRight = formatCut(45, highLeft ? mLow : mHigh);
        out.bom
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', w + 2 * weld, '45/45', 1, role: ProfileRole.frame))
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', hl + 2 * weld, cutLeft, 1, role: ProfileRole.frame))
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', hr + 2 * weld, cutRight, 1, role: ProfileRole.frame))
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', topLen, cutTop, 1, role: ProfileRole.frame));
      case TriangleShape tri:
        final run = tri.apex == TriangleApex.center ? w / 2 : w;
        final baseHalf = math.atan(h / run);
        final mBase = round1(degFromRad(baseHalf) / 2);
        final mApex = round1((math.pi - 2 * baseHalf) / 2 * 180 / math.pi);
        final slant = math.sqrt(run * run + h * h) + 2 * weld;
        out.bom
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', w + 2 * weld, formatCut(mBase, mBase), 1, role: ProfileRole.frame))
          ..add(BomLine.bar(BomGroup.profile, 'Kasa', slant, formatCut(mBase, mApex), 2, role: ProfileRole.frame));
      case RectShape _:
        break;
    }
  }

  void _shapedFrame(LayoutResult out, Box outer, BottomKind bottom, FrameShape shape, DesignNode child, double w, double h) {
    final outline = buildOutline(w, h, shape);
    final outerPoly = _pts(outline.polygon());
    final innerPoly = _pts(insetPolygon(w, h, shape, s.frameFace));
    if (bottom == BottomKind.threshold) {
      // şekilli eşik: alt dikdörtgen şerit + yanlar (üst şekil aynı)
      final thrTop = outer.b - s.thresholdFace;
      final thrInnerPoly = [
        for (final p in innerPoly)
          if (p.y >= thrTop - 0.01) p else Pt(p.x, thrTop),
      ];
      _polyStrip(out, DrawLayer.frame, outerPoly, thrInnerPoly);
      out.prims.add(BarRect(
        DrawLayer.frame,
        Box(outer.l + s.frameFace, outer.b - s.thresholdFace, outer.r - s.frameFace, outer.b),
        metallic: true,
      ));
      _shapedFrameBom(out, shape, w, h, outline);
      _thresholdBom(out, outer);
    } else {
      _polyStrip(out, DrawLayer.frame, outerPoly, innerPoly);
      _shapedFrameBom(out, shape, w, h, outline);
    }
    final innerBounds = _bounds(innerPoly);
    final inner = Box(innerBounds.l, innerBounds.t, innerBounds.r, innerBounds.b);
  final ref = outer;
    _area(out, child, inner, ref, const _Edges.all(EdgeKind.frame), shape: shape, fullW: w, fullH: h);
  }

  void _shapedBeadBomFromEdges(LayoutResult out, List<ContourEdge> edges, {String glassCode = ''}) {
    if (edges.isEmpty) return;
    final miters = contourMiters(edges);
    for (var i = 0; i < edges.length; i++) {
      final e = edges[i];
      final cut = contourEdgeCut(miters, i);
      final len = round1(e.length);
      if (e.bent && e.radius != null) {
        out.bom.add(BomLine.barBent(
          BomGroup.bead,
          'Cam çıtası',
          len,
          cut,
          1,
          e.radius!,
          glassCode: glassCode,
        ));
      } else {
        out.bom.add(BomLine.bar(BomGroup.bead, 'Cam çıtası', len, cut, 1, glassCode: glassCode));
      }
    }
  }

  void _fillShaped(
    LayoutResult out,
    FillNode n,
    FrameShape shape,
    double fullW,
    double fullH,
    _Edges e, {
    required Box region,
  }) {
    final cutY = region.b;
    final fullInner = region.h >= fullH - 2 * s.frameFace - 1;

    var beadEdges = buildInsetContourEdges(fullW, fullH, shape, s.frameFace);
    if (!fullInner) beadEdges = clipContourMaxY(beadEdges, cutY);

    var glassEdges = buildInsetContourEdges(fullW, fullH, shape, s.frameFace + s.beadFace);
    if (!fullInner) glassEdges = clipContourMaxY(glassEdges, cutY - s.beadFace);

    final beadOuter = _pts(edgesToPoints(beadEdges));
    final glassPoly = _pts(edgesToPoints(glassEdges));
    if (beadOuter.length >= 3 && glassPoly.length >= 3) {
      _polyStrip(out, DrawLayer.bead, beadOuter, glassPoly);
    }
    _shapedBeadBomFromEdges(out, beadEdges, glassCode: n.glassCode);

    if (glassPoly.length < 3) return;
    final visBounds = _bounds(glassPoly);
    final vis = Box(visBounds.l, visBounds.t, visBounds.r, visBounds.b);
    final pay = s.frameFace - s.glassRebateFrame;
    final gw = fullInner ? fullW - 2 * pay : region.w + s.rebateFor(e.l) + s.rebateFor(e.r);
    final gh = fullInner ? fullH - 2 * pay : region.h + s.rebateFor(e.t) + s.rebateFor(e.b);
    final shapeCode = frameShapeBomCode(shape);
    out.prims.add(GlassPrim(
      n.id,
      vis,
      gw,
      gh,
      n.glassCode,
      n.fill,
      clip: glassPoly,
      shapeType: shapeCode,
    ));
    out.prims.add(TextPrim(DrawLayer.label, Pt(vis.cx, vis.cy), n.glassCode));
    out.bom.add(BomLine.sheet(
      n.fill == FillType.panel ? BomGroup.panel : BomGroup.glass,
      n.fill == FillType.panel ? 'Panel' : 'Cam',
      gw,
      gh,
      1,
      glassCode: n.glassCode,
      shape: shapeCode,
    ));
    out.hits.add(HitArea(n.id, vis, polygon: glassPoly));
  }

  /// Tek kasa gövdesi: eşik dahil. [outer] kasa dış kutusu.
  void _frame(LayoutResult out, Box outer, BottomKind bottom, DesignNode child) {
    final threshold = bottom == BottomKind.threshold;
    final inner = threshold
        ? Box(outer.l + s.frameFace, outer.t + s.frameFace, outer.r - s.frameFace, outer.b - s.thresholdFace)
        : outer.deflate(s.frameFace);
    if (threshold) {
      _frameU(out, outer, inner);
      _thresholdBom(out, outer);
      out.prims.add(BarRect(
        DrawLayer.frame,
        Box(outer.l + s.frameFace, outer.b - s.thresholdFace, outer.r - s.frameFace, outer.b),
        metallic: true,
      ));
    } else {
      _ring(out, DrawLayer.frame, outer, inner);
      _bars(out, 'Kasa', ProfileRole.frame, outer);
    }
    _area(out, child, inner, outer, const _Edges.all(EdgeKind.frame));
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
  void _area(
    LayoutResult out,
    DesignNode node,
    Box rect,
    Box ref,
    _Edges edges, {
    FrameShape shape = const RectShape(),
    double? fullW,
    double? fullH,
  }) {
    switch (node) {
      case CoupleNode _:
      case FrameNode _:
        break; // yalnızca root / couple çocukları; alan içinde beklenmez
      case SplitNode n:
        _split(out, n, rect, ref, edges, shape: shape, fullW: fullW, fullH: fullH);
      case SashNode n:
        final face = n.kind == SashKind.door ? s.doorSashFace : s.sashFace;
        final so = rect.inflate(s.sashLap);
        final si = so.deflate(face);
        _ring(out, DrawLayer.sash, so, si);
        final role = n.kind == SashKind.door ? ProfileRole.doorSash : ProfileRole.sash;
        final label = n.kind == SashKind.door ? 'Kapı kanadı' : 'Kanat';
        _bars(out, label, role, so);
        out.bom.add(BomLine.hardware(_hwKind(n), so.w, so.h, 1));
        if (n.screen != null) {
          out.bom.add(BomLine.screen(n.screen!, rect.w, rect.h, 1));
          _screenGrid(out, si);
        }
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
        final il = s.slideInterlock, lap = s.sashLap;
        final panels = n.panels;
        final count = panels.length;
        final pw = (rect.w + 2 * lap + (count - 1) * il) / count;
        for (var i = 0; i < count; i++) {
          final panel = panels[i];
          final x = rect.l - lap + i * (pw - il);
          final so = Box(x, rect.t - lap, x + pw, rect.b + lap);
          final si = so.deflate(s.sashFace);
          final z = i % 2;
          _ring(out, DrawLayer.sash, so, si, z: z);
          _bars(out, 'Sürme kanat', ProfileRole.slideSash, so);
          final hw = _slideHwKind(n.system, panel.move);
          out.bom.add(BomLine.hardware(hw, so.w, so.h, 1));
          if (panel.screen != null) {
            out.bom.add(BomLine.screen(panel.screen!, so.w, so.h, 1));
            _screenGrid(out, si);
          }
          out.sashes.add(SashInfo(
            fillIds: _fillIds(panel.child),
            outer: so,
            sliding: true,
            slideMove: panel.move,
            slideSystem: n.system,
            slideNodeId: n.id,
          ));
          if (panel.move == SlideMove.fixed) {
            out.prims.add(TextPrim(DrawLayer.label, Pt(si.cx, si.cy), 'Sabit'));
          } else {
            final dir = panel.move == SlideMove.right ? 1.0 : -1.0;
            _arrow(out, si, dir, lift: n.system == SlideSystem.liftSlide);
          }
          if (n.system == SlideSystem.liftSlide) {
            out.prims.add(TextPrim(DrawLayer.label, Pt(so.cx, so.b - 18), 'HS'));
          }
          _area(out, panel.child, si, ref, const _Edges.all(EdgeKind.sash));
        }
      case FillNode n:
        if (!shape.isRect && fullW != null && fullH != null) {
          final innerEdges = buildInsetContourEdges(fullW, fullH, shape, s.frameFace);
          final innerTop = contourTopY(innerEdges);
          // Üst kenarı kasa iç tepesine değen bölge şekillidir (alt sınırı serbest).
          final shapedRegion = rect.t <= innerTop + 1;
          if (shapedRegion) {
            _fillShaped(out, n, shape, fullW, fullH, edges, region: rect);
          } else {
            _fill(out, n, rect, edges);
          }
        } else {
          _fill(out, n, rect, edges);
        }
    }
  }

  void _split(
    LayoutResult out,
    SplitNode n,
    Box rect,
    Box ref,
    _Edges edges, {
    FrameShape shape = const RectShape(),
    double? fullW,
    double? fullH,
  }) {
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
      _area(out, n.children[i], cr, cref, ce, shape: shape, fullW: fullW, fullH: fullH);
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

  static String _slideHwKind(SlideSystem system, SlideMove move) {
    if (move == SlideMove.fixed) return 'SLIDE_FIXED';
    return system == SlideSystem.liftSlide ? 'LIFT_SLIDE' : 'SLIDE';
  }

  static List<String> _fillIds(DesignNode node) => switch (node) {
        FillNode n => [n.id],
        SashNode n => _fillIds(n.child),
        SlideNode n => [for (final p in n.panels) ..._fillIds(p.child)],
        SplitNode n => [for (final c in n.children) ..._fillIds(c)],
        FrameNode n => _fillIds(n.child),
        CoupleNode n => [for (final c in n.children) ..._fillIds(c)],
      };

  void _screenGrid(LayoutResult out, Box r) {
    const step = 12.0;
    for (var x = r.l; x <= r.r + 0.01; x += step) {
      out.prims.add(PolylinePrim(DrawLayer.screen, [Pt(x, r.t), Pt(x, r.b)]));
    }
    for (var y = r.t; y <= r.b + 0.01; y += step) {
      out.prims.add(PolylinePrim(DrawLayer.screen, [Pt(r.l, y), Pt(r.r, y)]));
    }
  }

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

  void _arrow(LayoutResult out, Box r, double dir, {bool lift = false}) {
    final len = math.min(r.w * .5, 360.0), hd = 40.0;
    final x0 = r.cx - dir * len / 2, x1 = r.cx + dir * len / 2;
    out.prims
      ..add(PolylinePrim(DrawLayer.symbol, [Pt(x0, r.cy), Pt(x1, r.cy)]))
      ..add(PolylinePrim(
          DrawLayer.symbol, [Pt(x1 - dir * hd, r.cy - hd * .6), Pt(x1, r.cy), Pt(x1 - dir * hd, r.cy + hd * .6)]));
    if (lift) {
      const up = 48.0, hdUp = 18.0;
      final y0 = r.cy + up * 0.55;
      final y1 = y0 - up;
      out.prims
        ..add(PolylinePrim(DrawLayer.symbol, [Pt(r.cx, y0), Pt(r.cx, y1)]))
        ..add(PolylinePrim(
            DrawLayer.symbol, [Pt(r.cx - hdUp, y1 + hdUp * .75), Pt(r.cx, y1), Pt(r.cx + hdUp, y1 + hdUp * .75)]));
    }
  }
}

class _Edges {
  final EdgeKind l, r, t, b;
  const _Edges(this.l, this.r, this.t, this.b);
  const _Edges.all(EdgeKind k) : this(k, k, k, k);
  _Edges copyWith({EdgeKind? l, EdgeKind? r, EdgeKind? t, EdgeKind? b}) =>
      _Edges(l ?? this.l, r ?? this.r, t ?? this.t, b ?? this.b);
}
