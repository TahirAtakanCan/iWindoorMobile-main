// Şekilli kasa / cam konturları. Koordinat: y aşağı, üst = 0.

import 'dart:math' as math;

import 'model.dart';

class ShapePt {
  final double x, y;
  const ShapePt(this.x, this.y);
}

/// Üst kenar profili: y = top(x); [offset] içe (aşağı) d kadar.
abstract class TopProfile {
  double top(double x);
  TopProfile offset(double d);
  List<ShapePt> sample({int segments = 48});
  double get length;
}

class FlatTop extends TopProfile {
  final double y;
  FlatTop(this.y);
  @override
  double top(double x) => y;
  @override
  TopProfile offset(double d) => FlatTop(y + d);
  @override
  List<ShapePt> sample({int segments = 48}) => [ShapePt(0, y), ShapePt(1, y)];
  @override
  double get length => 0;
}

/// Daire yayı: x = cx + r·cos(t), y = cy − r·sin(t); t: [t0]→[t1].
class ArcTop extends TopProfile {
  final double cx, cy, r, t0, t1;
  ArcTop({required this.cx, required this.cy, required this.r, required this.t0, required this.t1});

  @override
  double top(double x) {
    final dx = (x - cx).clamp(-r, r);
    return cy - math.sqrt(math.max(0, r * r - dx * dx));
  }

  @override
  TopProfile offset(double d) {
    final nr = r - d;
    if (nr <= 1e-6) return FlatTop(cy);
    return ArcTop(cx: cx, cy: cy, r: nr, t0: t0, t1: t1);
  }

  @override
  List<ShapePt> sample({int segments = 48}) {
    final pts = <ShapePt>[];
    for (var i = 0; i <= segments; i++) {
      final t = t0 + (t1 - t0) * (i / segments);
      pts.add(ShapePt(cx + r * math.cos(t), cy - r * math.sin(t)));
    }
    return pts;
  }

  @override
  double get length => r * (t0 - t1).abs();
}

class LineTop extends TopProfile {
  final double x0, y0, x1, y1;
  LineTop(this.x0, this.y0, this.x1, this.y1);

  @override
  double top(double x) {
    if ((x1 - x0).abs() < 1e-9) return y0;
    final t = ((x - x0) / (x1 - x0)).clamp(0.0, 1.0);
    return y0 + t * (y1 - y0);
  }

  @override
  TopProfile offset(double d) {
    final dx = x1 - x0, dy = y1 - y0;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-9) return LineTop(x0, y0 + d, x1, y1 + d);
    var nx = dy / len, ny = -dx / len;
    if (ny < 0) {
      nx = -nx;
      ny = -ny;
    }
    return LineTop(x0 + nx * d, y0 + ny * d, x1 + nx * d, y1 + ny * d);
  }

  @override
  List<ShapePt> sample({int segments = 48}) => [ShapePt(x0, y0), ShapePt(x1, y1)];

  @override
  double get length => math.sqrt((x1 - x0) * (x1 - x0) + (y1 - y0) * (y1 - y0));
}

class TriangleTop extends TopProfile {
  final double ax, w, h;
  TriangleTop({required this.ax, required this.w, required this.h});

  @override
  double top(double x) {
    if (x <= ax) {
      if (ax < 1e-9) return 0;
      return h * (ax - x) / ax;
    }
    if (w - ax < 1e-9) return 0;
    return h * (x - ax) / (w - ax);
  }

  @override
  TopProfile offset(double d) => this; // inset polygon ile yapılır

  @override
  List<ShapePt> sample({int segments = 48}) => [ShapePt(0, h), ShapePt(ax, 0), ShapePt(w, h)];

  @override
  double get length {
    final left = math.sqrt(ax * ax + h * h);
    final right = math.sqrt((w - ax) * (w - ax) + h * h);
    return left + right;
  }
}

class ShapeOutline {
  final double w, h;
  final FrameShape shape;
  final TopProfile top;
  final double leftSpringY;
  final double rightSpringY;
  final double? arcRadius;
  final double? arcTheta;

  const ShapeOutline({
    required this.w,
    required this.h,
    required this.shape,
    required this.top,
    required this.leftSpringY,
    required this.rightSpringY,
    this.arcRadius,
    this.arcTheta,
  });

  /// Dış kontur (CCW: alt-sol → alt-sağ → sağ yan → üst → sol yan).
  List<ShapePt> polygon({int arcSegments = 48}) {
    switch (shape) {
      case TriangleShape _:
        final t = top as TriangleTop;
        return [ShapePt(0, h), ShapePt(w, h), ShapePt(t.ax, 0)];
      case ArchShape _ || SegmentArchShape _:
        final arc = (top as ArcTop).sample(segments: arcSegments);
        return [ShapePt(0, h), ShapePt(w, h), ShapePt(w, rightSpringY), ...arc.reversed, ShapePt(0, leftSpringY)];
      case TrapezoidShape _:
        return [ShapePt(0, h), ShapePt(w, h), ShapePt(w, rightSpringY), ShapePt(0, leftSpringY)];
      case RectShape _:
        return [ShapePt(0, h), ShapePt(w, h), ShapePt(w, 0), ShapePt(0, 0)];
    }
  }

  /// Şekilli bölge (yay/eğik üst) ile dikdörtgen altın ayrıldığı y çizgisi.
  double get shapedZoneBottomY {
    switch (shape) {
      case ArchShape _:
        return leftSpringY; // = r
      case SegmentArchShape _:
        return leftSpringY; // = rise
      case TrapezoidShape _:
        return math.min(leftSpringY, rightSpringY);
      case TriangleShape _:
        return h; // bölme yok
      case RectShape _:
        return 0;
    }
  }
}

ShapeOutline buildOutline(double w, double h, FrameShape shape) {
  switch (shape) {
    case RectShape _:
      return ShapeOutline(
        w: w,
        h: h,
        shape: shape,
        top: FlatTop(0),
        leftSpringY: 0,
        rightSpringY: 0,
      );
    case ArchShape _:
      final r = w / 2;
      return ShapeOutline(
        w: w,
        h: h,
        shape: shape,
        top: ArcTop(cx: w / 2, cy: r, r: r, t0: math.pi, t1: 0),
        leftSpringY: r,
        rightSpringY: r,
        arcRadius: r,
        arcTheta: math.pi,
      );
    case SegmentArchShape s:
      final rise = s.rise;
      final R = (w * w / 4 + rise * rise) / (2 * rise);
      final theta = 2 * math.asin((w / 2) / R);
      return ShapeOutline(
        w: w,
        h: h,
        shape: shape,
        top: ArcTop(
          cx: w / 2,
          cy: R,
          r: R,
          t0: math.pi / 2 + theta / 2,
          t1: math.pi / 2 - theta / 2,
        ),
        leftSpringY: rise,
        rightSpringY: rise,
        arcRadius: R,
        arcTheta: theta,
      );
    case TrapezoidShape t:
      final yL = h - t.leftHeight;
      final yR = h - t.rightHeight;
      return ShapeOutline(
        w: w,
        h: h,
        shape: shape,
        top: LineTop(0, yL, w, yR),
        leftSpringY: yL,
        rightSpringY: yR,
      );
    case TriangleShape t:
      final ax = switch (t.apex) {
        TriangleApex.left => 0.0,
        TriangleApex.center => w / 2,
        TriangleApex.right => w,
      };
      return ShapeOutline(
        w: w,
        h: h,
        shape: shape,
        top: TriangleTop(ax: ax, w: w, h: h),
        leftSpringY: 0,
        rightSpringY: 0,
      );
  }
}

/// Çokgeni yaklaşık olarak d kadar içe küçült.
List<ShapePt> insetPolygon(double w, double h, FrameShape shape, double d) {
  if (d <= 0) return buildOutline(w, h, shape).polygon();
  switch (shape) {
    case RectShape _:
      return [ShapePt(d, h - d), ShapePt(w - d, h - d), ShapePt(w - d, d), ShapePt(d, d)];
    case ArchShape _ || SegmentArchShape _:
      final o = buildOutline(w, h, shape);
      final top = (o.top as ArcTop).offset(d) as ArcTop;
      final spring = o.leftSpringY;
      final arc = top.sample();
      return [
        ShapePt(d, h - d),
        ShapePt(w - d, h - d),
        ShapePt(w - d, spring),
        ...arc.reversed,
        ShapePt(d, spring),
      ];
    case TrapezoidShape t:
      final line = LineTop(0, h - t.leftHeight, w, h - t.rightHeight).offset(d) as LineTop;
      return [
        ShapePt(d, h - d),
        ShapePt(w - d, h - d),
        ShapePt(line.x1.clamp(d, w - d), line.y1),
        ShapePt(line.x0.clamp(d, w - d), line.y0),
      ];
    case TriangleShape t:
      final ax = switch (t.apex) {
        TriangleApex.left => 0.0,
        TriangleApex.center => w / 2,
        TriangleApex.right => w,
      };
      return _insetTriangle(ShapePt(0, h), ShapePt(w, h), ShapePt(ax, 0), d);
  }
}

List<ShapePt> _insetTriangle(ShapePt a, ShapePt b, ShapePt c, double d) {
  ShapePt n(ShapePt p, ShapePt q) {
    final dx = q.x - p.x, dy = q.y - p.y;
    final len = math.sqrt(dx * dx + dy * dy);
    return ShapePt(-dy / len, dx / len);
  }

  final nab = n(a, b), nbc = n(b, c), nca = n(c, a);
  final cx = (a.x + b.x + c.x) / 3, cy = (a.y + b.y + c.y) / 3;
  ShapePt fix(ShapePt p, ShapePt nn) {
    final toC = ShapePt(cx - p.x, cy - p.y);
    final s = nn.x * toC.x + nn.y * toC.y;
    return s >= 0 ? nn : ShapePt(-nn.x, -nn.y);
  }

  final na = fix(a, ShapePt(nca.x + nab.x, nca.y + nab.y));
  final nb = fix(b, ShapePt(nab.x + nbc.x, nab.y + nbc.y));
  final nc = fix(c, ShapePt(nbc.x + nca.x, nbc.y + nca.y));
  double nl(ShapePt p) => math.sqrt(p.x * p.x + p.y * p.y);
  ShapePt push(ShapePt p, ShapePt nn) {
    final l = nl(nn);
    if (l < 1e-9) return p;
    return ShapePt(p.x + nn.x / l * d, p.y + nn.y / l * d);
  }

  return [push(a, na), push(b, nb), push(c, nc)];
}

bool pointInPolygon(double x, double y, List<ShapePt> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].x, yi = poly[i].y;
    final xj = poly[j].x, yj = poly[j].y;
    final dy = (yj - yi).abs() < 1e-15 ? 1e-15 : (yj - yi);
    final intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / dy + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

double round1(double v) => (v * 10).roundToDouble() / 10;

String _cutNum(double v) {
  final r = round1(v);
  return r == r.roundToDouble() ? '${r.toInt()}' : '$r';
}

String formatCut(double a, double b) => '${_cutNum(a)}/${_cutNum(b)}';

String frameShapeLabel(FrameShape s) => switch (s) {
      RectShape _ => 'Dikdörtgen',
      ArchShape _ => 'Kemerli',
      SegmentArchShape _ => 'Basık kemer',
      TrapezoidShape _ => 'Eğik üst',
      TriangleShape _ => 'Üçgen',
    };

String frameShapeBomCode(FrameShape s) => switch (s) {
      RectShape _ => 'rect',
      ArchShape _ => 'arch',
      SegmentArchShape _ => 'segmentArch',
      TrapezoidShape _ => 'trapezoid',
      TriangleShape _ => 'triangle',
    };

double degFromRad(double rad) => rad * 180 / math.pi;

// ---------- kontur kenarları (düz / yay) + yatay kırpma ----------

class _Tan {
  final double dx, dy;
  const _Tan(this.dx, this.dy);
  _Tan get negated => _Tan(-dx, -dy);
  _Tan normalized() {
    final l = math.sqrt(dx * dx + dy * dy);
    if (l < 1e-12) return const _Tan(1, 0);
    return _Tan(dx / l, dy / l);
  }
}

/// Kapalı konturun bir kenarı: düz segment veya daire yayı.
sealed class ContourEdge {
  ShapePt get start;
  ShapePt get end;
  double get length;
  bool get bent => false;
  double? get radius => null;
  _Tan tangentAtStart();
  _Tan tangentAtEnd();
  List<ShapePt> sample({int segments = 48});

  /// [maxY] yarım düzleminde (y ≤ maxY) kalan alt-parçalar, kenar yönünde.
  List<ContourEdge> partsInsideMaxY(double maxY);
}

class LineContourEdge extends ContourEdge {
  @override
  final ShapePt start;
  @override
  final ShapePt end;
  LineContourEdge(this.start, this.end);

  @override
  double get length {
    final dx = end.x - start.x, dy = end.y - start.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  _Tan tangentAtStart() => _Tan(end.x - start.x, end.y - start.y).normalized();

  @override
  _Tan tangentAtEnd() => tangentAtStart();

  @override
  List<ShapePt> sample({int segments = 48}) => [start, end];

  @override
  List<ContourEdge> partsInsideMaxY(double maxY) {
    final aIn = start.y <= maxY + 1e-9;
    final bIn = end.y <= maxY + 1e-9;
    if (aIn && bIn) return [this];
    if (!aIn && !bIn) return const [];
    final hit = _lineHitY(start, end, maxY);
    if (hit == null) return aIn ? [this] : const [];
    if (aIn) return [LineContourEdge(start, hit)];
    return [LineContourEdge(hit, end)];
  }
}

/// Parametre: x = cx + r·cos(t), y = cy − r·sin(t); t [tStart]→[tEnd].
class ArcContourEdge extends ContourEdge {
  final double cx, cy, r, tStart, tEnd;
  ArcContourEdge({
    required this.cx,
    required this.cy,
    required this.r,
    required this.tStart,
    required this.tEnd,
  });

  ShapePt _at(double t) => ShapePt(cx + r * math.cos(t), cy - r * math.sin(t));

  /// Yay boyunca artan t yönünde teğet.
  _Tan _tanIncreasing(double t) => _Tan(-math.sin(t), -math.cos(t)).normalized();

  bool get _forward => tEnd >= tStart;

  @override
  ShapePt get start => _at(tStart);

  @override
  ShapePt get end => _at(tEnd);

  @override
  double get length => r * (tEnd - tStart).abs();

  @override
  bool get bent => true;

  @override
  double? get radius => r;

  @override
  _Tan tangentAtStart() {
    final t = _tanIncreasing(tStart);
    return _forward ? t : t.negated;
  }

  @override
  _Tan tangentAtEnd() {
    final t = _tanIncreasing(tEnd);
    return _forward ? t : t.negated;
  }

  @override
  List<ShapePt> sample({int segments = 48}) {
    final n = math.max(1, segments);
    return [for (var i = 0; i <= n; i++) _at(tStart + (tEnd - tStart) * i / n)];
  }

  @override
  List<ContourEdge> partsInsideMaxY(double maxY) {
    final s = (cy - maxY) / r;
    final ts = <double>[tStart];
    if (s.abs() <= 1 + 1e-12) {
      final base = math.asin(s.clamp(-1.0, 1.0));
      for (final cand in [base, math.pi - base]) {
        if (_tInSpan(cand, tStart, tEnd)) ts.add(_near(cand, tStart, tEnd));
      }
    }
    ts.add(tEnd);
    ts.sort();
    // tekil
    final uniq = <double>[ts.first];
    for (final t in ts.skip(1)) {
      if ((t - uniq.last).abs() > 1e-9) uniq.add(t);
    }
    // yön tEnd < tStart ise ters sırada parçala
    final ordered = _forward ? uniq : uniq.reversed.toList();
    final out = <ContourEdge>[];
    for (var i = 0; i < ordered.length - 1; i++) {
      final a = ordered[i], b = ordered[i + 1];
      if ((a - b).abs() < 1e-9) continue;
      final mid = (a + b) / 2;
      if (_at(mid).y <= maxY + 1e-9) {
        out.add(ArcContourEdge(cx: cx, cy: cy, r: r, tStart: a, tEnd: b));
      }
    }
    return out;
  }

  static bool _tInSpan(double t, double a, double b) {
    final lo = math.min(a, b), hi = math.max(a, b);
    return t >= lo - 1e-9 && t <= hi + 1e-9;
  }

  static double _near(double t, double a, double b) {
    // [0,2π) dışına taşan adayları span'a çek
    final lo = math.min(a, b), hi = math.max(a, b);
    if (t >= lo - 1e-9 && t <= hi + 1e-9) return t;
    final t2 = t + 2 * math.pi;
    if (t2 >= lo - 1e-9 && t2 <= hi + 1e-9) return t2;
    final t3 = t - 2 * math.pi;
    if (t3 >= lo - 1e-9 && t3 <= hi + 1e-9) return t3;
    return t;
  }
}

ShapePt? _lineHitY(ShapePt a, ShapePt b, double y) {
  final dy = b.y - a.y;
  if (dy.abs() < 1e-12) return null;
  final t = (y - a.y) / dy;
  if (t < -1e-9 || t > 1 + 1e-9) return null;
  return ShapePt(a.x + t * (b.x - a.x), y);
}

/// Kasa iç konturu (inset [d]) kenar listesi; dolaşım: alt → sağ → üst → sol.
List<ContourEdge> buildInsetContourEdges(double w, double h, FrameShape shape, double d) {
  switch (shape) {
    case RectShape _:
      return [
        LineContourEdge(ShapePt(d, h - d), ShapePt(w - d, h - d)),
        LineContourEdge(ShapePt(w - d, h - d), ShapePt(w - d, d)),
        LineContourEdge(ShapePt(w - d, d), ShapePt(d, d)),
        LineContourEdge(ShapePt(d, d), ShapePt(d, h - d)),
      ];
    case ArchShape _ || SegmentArchShape _:
      final o = buildOutline(w, h, shape);
      final arc = (o.top as ArcTop).offset(d) as ArcTop;
      final spring = o.leftSpringY;
      // Üst yay sağ → sol (t: t1 → t0; arch'ta 0 → π)
      return [
        LineContourEdge(ShapePt(d, h - d), ShapePt(w - d, h - d)),
        LineContourEdge(ShapePt(w - d, h - d), ShapePt(w - d, spring)),
        ArcContourEdge(cx: arc.cx, cy: arc.cy, r: arc.r, tStart: arc.t1, tEnd: arc.t0),
        LineContourEdge(ShapePt(d, spring), ShapePt(d, h - d)),
      ];
    case TrapezoidShape t:
      final line = LineTop(0, h - t.leftHeight, w, h - t.rightHeight).offset(d) as LineTop;
      return [
        LineContourEdge(ShapePt(d, h - d), ShapePt(w - d, h - d)),
        LineContourEdge(ShapePt(w - d, h - d), ShapePt(line.x1.clamp(d, w - d), line.y1)),
        LineContourEdge(ShapePt(line.x1.clamp(d, w - d), line.y1), ShapePt(line.x0.clamp(d, w - d), line.y0)),
        LineContourEdge(ShapePt(line.x0.clamp(d, w - d), line.y0), ShapePt(d, h - d)),
      ];
    case TriangleShape _:
      final pts = insetPolygon(w, h, shape, d);
      // inset üçgen: taban L, taban R, tepe — dolaşımı alt→sağ eğik→sol eğik için çevir
      // pts = [baseL, baseR, apex]
      return [
        LineContourEdge(pts[0], pts[1]),
        LineContourEdge(pts[1], pts[2]),
        LineContourEdge(pts[2], pts[0]),
      ];
  }
}

bool _samePt(ShapePt a, ShapePt b) => (a.x - b.x).abs() < 1e-6 && (a.y - b.y).abs() < 1e-6;

ContourEdge reverseContourEdge(ContourEdge e) => switch (e) {
      LineContourEdge l => LineContourEdge(l.end, l.start),
      ArcContourEdge a => ArcContourEdge(cx: a.cx, cy: a.cy, r: a.r, tStart: a.tEnd, tEnd: a.tStart),
    };

/// Kapalı konturu y ≤ [maxY] ile kırpar; kesimde yatay kiriş ekler.
List<ContourEdge> clipContourMaxY(List<ContourEdge> edges, double maxY) {
  if (edges.isEmpty) return const [];
  var maxEdgeY = -double.infinity;
  for (final e in edges) {
    maxEdgeY = math.max(maxEdgeY, math.max(e.start.y, e.end.y));
    if (e is ArcContourEdge) {
      for (final p in e.sample(segments: 12)) {
        maxEdgeY = math.max(maxEdgeY, p.y);
      }
    }
  }
  if (maxY >= maxEdgeY - 1e-6) return List.of(edges);

  final out = <ContourEdge>[];
  ShapePt? pendingExit;

  for (final edge in edges) {
    final startIn = edge.start.y <= maxY + 1e-9;
    final endIn = edge.end.y <= maxY + 1e-9;
    final parts = edge.partsInsideMaxY(maxY);
    if (parts.isEmpty) continue;

    if (!startIn && pendingExit != null) {
      out.add(LineContourEdge(pendingExit, parts.first.start));
      pendingExit = null;
    }

    for (var i = 0; i < parts.length; i++) {
      if (i > 0) {
        out.add(LineContourEdge(parts[i - 1].end, parts[i].start));
      }
      out.add(parts[i]);
    }

    final last = parts.last;
    if (!_samePt(last.end, edge.end) || !endIn) {
      pendingExit = last.end;
    } else {
      pendingExit = null;
    }
  }

  if (pendingExit != null && out.isNotEmpty) {
    out.add(LineContourEdge(pendingExit, out.first.start));
  }
  return orientContourBottomFirst(_dropTiny(out));
}

List<ContourEdge> _dropTiny(List<ContourEdge> edges) =>
    [for (final e in edges) if (e.length > 0.05) e];

/// Alt/kiriş kenarı önce, L→R; ardından sağ yan yukarı.
List<ContourEdge> orientContourBottomFirst(List<ContourEdge> edges) {
  if (edges.length < 2) return edges;
  var best = 0;
  var bestY = -double.infinity;
  for (var i = 0; i < edges.length; i++) {
    final e = edges[i];
    if (e.bent) continue;
    final y = (e.start.y + e.end.y) / 2;
    if (y > bestY) {
      bestY = y;
      best = i;
    }
  }
  var rot = [...edges.skip(best), ...edges.take(best)];
  if (rot.first.end.x + 1e-9 < rot.first.start.x) {
    rot = [for (final e in rot.reversed) reverseContourEdge(e)];
  }
  return rot;
}

/// Köşe gönyesi (derece, 1 ondalık): iç açı / 2.
double cornerMiterDeg(ContourEdge incoming, ContourEdge outgoing) {
  final tin = incoming.tangentAtEnd();
  final tout = outgoing.tangentAtStart();
  final cross = tin.dx * tout.dy - tin.dy * tout.dx;
  final dot = tin.dx * tout.dx + tin.dy * tout.dy;
  final turn = math.atan2(cross, dot);
  final interior = math.pi - turn.abs();
  return round1(degFromRad(interior) / 2);
}

/// miter[i] = edges[i] başlangıç köşesi; bitiş = miter[(i+1)%n].
List<double> contourMiters(List<ContourEdge> edges) {
  if (edges.isEmpty) return const [];
  final n = edges.length;
  return [for (var i = 0; i < n; i++) cornerMiterDeg(edges[(i - 1 + n) % n], edges[i])];
}

String contourEdgeCut(List<double> startMiters, int i) {
  final n = startMiters.length;
  return formatCut(startMiters[i], startMiters[(i + 1) % n]);
}

List<ShapePt> edgesToPoints(List<ContourEdge> edges, {int arcSegments = 48}) {
  final pts = <ShapePt>[];
  for (final e in edges) {
    final s = e.sample(segments: arcSegments);
    if (pts.isEmpty) {
      pts.addAll(s);
    } else {
      pts.addAll(s.skip(1));
    }
  }
  return pts;
}

double contourTopY(List<ContourEdge> edges) {
  var t = double.infinity;
  for (final e in edges) {
    for (final p in e.sample(segments: 24)) {
      if (p.y < t) t = p.y;
    }
  }
  return t.isFinite ? t : 0;
}
