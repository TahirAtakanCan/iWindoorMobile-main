// Yeni çizici: LayoutEngine'in ürettiği primitifleri Canvas'a basar.
// Geometri hesabı burada YOK. Sadece "nasıl görünsün" kararları var (renk, gölge, cam efekti).

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

import 'glass_look.dart';

/// mm <-> ekran dönüşümü (ölçek + öteleme). Dokunmayı mm'ye çevirmek için de kullanılır.
class DrawTransform {
  final double ox, oy, k;
  const DrawTransform(this.ox, this.oy, this.k);
  Offset toMm(Offset p) => Offset((p.dx - ox) / k, (p.dy - oy) / k);
}

class DesignPainter extends CustomPainter {
  final LayoutResult layout;
  final double designW, designH;
  final ProfileColor color;
  final GlassLook Function(String glassCode) lookOf;
  final String? selectedId;
  final Set<String> issueIds;
  final bool showDimensions;
  final bool showLabels;
  final Color dimColor;
  final Color selectionColor;
  final Color issueColor;

  DesignPainter({
    required this.layout,
    required this.designW,
    required this.designH,
    required this.lookOf,
    this.color = ProfileColor.white,
    this.selectedId,
    this.issueIds = const {},
    this.showDimensions = true,
    this.showLabels = false,
    this.dimColor = const Color(0xFF333333),
    this.selectionColor = const Color(0xFFE0701A),
    this.issueColor = const Color(0xFFC62828),
  });

  // Ölçü çizgileri için kenar boşlukları (mm, çizim ölçeğinde)
  double get _padL => showDimensions ? 240 : 30;
  double get _padB => showDimensions ? 240 : 30;
  double get _padT => showDimensions ? 50 : 30;
  double get _padR => showDimensions ? 50 : 30;

  DrawTransform transformFor(Size size) {
    final totalW = designW + _padL + _padR, totalH = designH + _padT + _padB;
    final k = math.min(size.width / totalW, size.height / totalH);
    final ox = (size.width - totalW * k) / 2 + _padL * k;
    final oy = (size.height - totalH * k) / 2 + _padT * k;
    return DrawTransform(ox, oy, k);
  }

  /// Dokunulan noktadaki cam/panel alanının id'si.
  /// (CustomPainter.hitTest ile karışmasın diye adı farklı.)
  String? fillIdAt(Size size, Offset local) {
    final mm = transformFor(size).toMm(local);
    return layout.hitTest(mm.dx, mm.dy);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final t = transformFor(size);
    canvas.save();
    canvas.translate(t.ox, t.oy);
    canvas.scale(t.k);
    final hair = 1.0 / t.k; // ekranda 1 px kalınlık

    final prims = [...layout.prims]..sort((a, b) {
        final la = a.layer.index.compareTo(b.layer.index);
        return la != 0 ? la : a.z.compareTo(b.z);
      });

    for (final p in prims) {
      switch (p) {
        case ProfilePoly pp:
          _profile(canvas, pp, hair);
        case BarRect b:
          _bar(canvas, b, hair);
        case GlassPrim g:
          _glass(canvas, g, hair);
        case PolylinePrim l:
          final paint = _stroke(const Color(0xFF20303A), 1.3 * hair)..strokeJoin = StrokeJoin.round;
          if (l.dashed) {
            _drawDashedPolyline(canvas, l.pts, paint, 14 / t.k, 8 / t.k);
          } else {
            final path = Path()..moveTo(l.pts.first.x, l.pts.first.y);
            for (final q in l.pts.skip(1)) {
              path.lineTo(q.x, q.y);
            }
            canvas.drawPath(path, paint);
          }
        case HandlePrim h:
          for (final (box, radius) in [(h.base, 6.0), (h.lever, 7.0)]) {
            final rr = RRect.fromLTRBR(box.l, box.t, box.r, box.b, Radius.circular(radius));
            canvas.drawRRect(rr, Paint()..color = color.hardware);
            canvas.drawRRect(rr, _stroke(const Color(0xFF3A4146), hair));
          }
          if (h.lock != null) {
            final lock = h.lock!;
            final rr = RRect.fromLTRBR(lock.l, lock.t, lock.r, lock.b, Radius.circular(lock.w / 2));
            canvas.drawRRect(rr, Paint()..color = color.hardware);
            canvas.drawRRect(rr, _stroke(const Color(0xFF3A4146), hair));
          }
        case TextPrim tp:
          if (showLabels && tp.text.isNotEmpty) {
            _text(canvas, tp.text, Offset(tp.at.x, tp.at.y), math.max(designW, designH) / 52,
                const Color(0xB31F3A4D), center: true);
          }
      }
    }

    for (final id in issueIds) {
      final box = layout.boxOf(id);
      if (box == null) continue;
      final r = Rect.fromLTRB(box.l, box.t, box.r, box.b).deflate(4);
      _drawDashedRect(canvas, r, issueColor, 2.2 * hair, 12 / t.k, 7 / t.k);
    }
    if (selectedId != null) {
      final box = layout.boxOf(selectedId!);
      if (box != null) {
        final r = Rect.fromLTRB(box.l, box.t, box.r, box.b).deflate(6);
        canvas.drawRect(r, Paint()..color = selectionColor.withValues(alpha: .10));
        canvas.drawRect(r, _stroke(selectionColor, 3 * hair));
      }
    }
    if (showDimensions) _dims(canvas, t.k);
    canvas.restore();
  }

  void _drawDashedRect(Canvas c, Rect r, Color col, double w, double dash, double gap) {
    final path = Path()..addRect(r);
    final dashed = Path();
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        final next = math.min(d + dash, m.length);
        dashed.addPath(m.extractPath(d, next), Offset.zero);
        d += dash + gap;
      }
    }
    c.drawPath(dashed, _stroke(col, w));
  }

  // --- profil (kasa / kanat / çıta): dolgu + kenar + yön gölgesi ---
  static const _sashShade = {ProfileSide.top: 0.0, ProfileSide.left: .04, ProfileSide.right: .10, ProfileSide.bottom: .15};
  static const _beadShade = {ProfileSide.top: .16, ProfileSide.left: .10, ProfileSide.right: .03, ProfileSide.bottom: 0.0};

  void _profile(Canvas c, ProfilePoly p, double hair) {
    final path = Path()..addPolygon(p.pts.map((q) => Offset(q.x, q.y)).toList(), true);
    c.drawPath(path, Paint()..color = color.fill);
    final shade = (p.layer == DrawLayer.bead ? _beadShade : _sashShade)[p.side]!;
    if (shade > 0) c.drawPath(path, Paint()..color = Colors.black.withValues(alpha: shade));
    c.drawPath(path, _stroke(color.stroke, hair)..strokeJoin = StrokeJoin.round); // gönye çizgisi buradan gelir
  }

  void _bar(Canvas c, BarRect b, double hair) {
    final r = Rect.fromLTRB(b.box.l, b.box.t, b.box.r, b.box.b);
    if (b.metallic) {
      c.drawRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFB0B6BC), Color(0xFF7A828A), Color(0xFF9AA1A8)],
          ).createShader(r),
      );
    } else {
      c.drawRect(r, Paint()..color = color.fill);
      if (b.dir != null) {
        final v = b.dir == SplitDir.v;
        final shadow = v
            ? Rect.fromLTRB(r.left + r.width * .62, r.top, r.right, r.bottom)
            : Rect.fromLTRB(r.left, r.top + r.height * .62, r.right, r.bottom);
        c.drawRect(shadow, Paint()..color = Colors.black.withValues(alpha: .08));
      }
    }
    c.drawRect(r, _stroke(color.stroke, hair));
  }

  void _drawDashedPolyline(Canvas c, List<Pt> pts, Paint paint, double dash, double gap) {
    if (pts.length < 2) return;
    for (var i = 0; i < pts.length - 1; i++) {
      final a = Offset(pts[i].x, pts[i].y);
      final b = Offset(pts[i + 1].x, pts[i + 1].y);
      final len = (b - a).distance;
      if (len <= 0) continue;
      final dir = (b - a) / len;
      var d = 0.0;
      while (d < len) {
        final next = math.min(d + dash, len);
        c.drawLine(a + dir * d, a + dir * next, paint);
        d += dash + gap;
      }
    }
  }

  // --- cam: degrade + çapraz parlama şeritleri (clip ile) ---
  void _glass(Canvas c, GlassPrim g, double hair) {
    final r = Rect.fromLTRB(g.visible.l, g.visible.t, g.visible.r, g.visible.b);
    if (r.width <= 0 || r.height <= 0) return;
    final look = g.fill == FillType.panel ? GlassLook.panelLook : lookOf(g.glassCode);

    if (look.panel) {
      c.drawRect(
          r,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: look.gradient,
            ).createShader(r));
      for (var y = r.top + 60; y < r.bottom; y += 60) {
        c.drawLine(Offset(r.left, y), Offset(r.right, y), _stroke(const Color(0xFF9AA3A9), hair));
      }
      c.drawRect(r, _stroke(color.stroke, hair));
      return;
    }

    c.drawRect(
        r,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: look.gradient,
          ).createShader(r));

    c.save();
    c.clipRect(r);
    if (look.reflection > 0) {
      final k = math.min(r.height * .55, r.width * .9);
      Path band(double a, double t) => Path()
        ..addPolygon([
          Offset(r.left + a * r.width, r.bottom),
          Offset(r.left + (a + t) * r.width, r.bottom),
          Offset(r.left + (a + t) * r.width + k, r.top),
          Offset(r.left + a * r.width + k, r.top),
        ], true);
      c.drawPath(band(.08, .16), Paint()..color = Colors.white.withValues(alpha: look.reflection));
      c.drawPath(band(.30, .05), Paint()..color = Colors.white.withValues(alpha: look.reflection * .8));
    }
    if (look.frosted) {
      // satina/buzlu: sabit tohumlu nokta dokusu (her çizimde aynı görünsün)
      final rnd = math.Random(g.nodeId.hashCode);
      final n = (r.width * r.height / 180).clamp(0, 6000).toInt();
      final pts = [
        for (var i = 0; i < n; i++) Offset(r.left + rnd.nextDouble() * r.width, r.top + rnd.nextDouble() * r.height)
      ];
      c.drawPoints(
          ui.PointMode.points,
          pts,
          Paint()
            ..color = Colors.white.withValues(alpha: .85)
            ..strokeWidth = 2.6
            ..strokeCap = StrokeCap.round);
    }
    if (look.patterned) {
      // desenli cam: 45° baklava deseni
      final p = _stroke(Colors.white.withValues(alpha: .85), 2);
      const step = 36.0;
      for (var d = -r.height; d < r.width; d += step) {
        c.drawLine(Offset(r.left + d, r.bottom), Offset(r.left + d + r.height, r.top), p);
        c.drawLine(Offset(r.left + d, r.top), Offset(r.left + d + r.height, r.bottom), p);
      }
    }
    if (look.laminated) {
      // lamine: içte kesik çizgi
      final inner = r.deflate(8);
      final p = _stroke(const Color(0xFF5F8AA6), hair);
      const dash = 6.0, gap = 4.0;
      void dashed(Offset a, Offset b) {
        final len = (b - a).distance;
        final dir = (b - a) / len;
        for (var s = 0.0; s < len; s += dash + gap) {
          c.drawLine(a + dir * s, a + dir * math.min(s + dash, len), p);
        }
      }

      dashed(inner.topLeft, inner.topRight);
      dashed(inner.topRight, inner.bottomRight);
      dashed(inner.bottomRight, inner.bottomLeft);
      dashed(inner.bottomLeft, inner.topLeft);
    }
    c.restore();
    c.drawRect(r, _stroke(const Color(0xFF5F8AA6), .8 * hair));
  }

  // --- ölçüler: zincir (kayıt eksenleri) + toplam ---
  void _dims(Canvas c, double k) {
    final fs = math.max(designW, designH) / 30;
    List<double> uniq(List<double> v) => (v.map((e) => (e * 10).round() / 10).toSet().toList()..sort());
    final xs = [0.0, ...uniq(layout.mullionX), designW];
    final ys = [0.0, ...uniq(layout.mullionY), designH];
    final hasX = xs.length > 2, hasY = ys.length > 2;
    if (hasX) _chain(c, xs, true, designH + 80, fs, k);
    _chain(c, [0, designW], true, designH + 80 + (hasX ? fs * 2.4 : 0), fs, k);
    if (hasY) _chain(c, ys, false, -80, fs, k);
    _chain(c, [0, designH], false, -80 - (hasY ? fs * 2.4 : 0), fs, k);
  }

  void _chain(Canvas c, List<double> v, bool horiz, double off, double fs, double k) {
    final p = _stroke(dimColor, 1 / k);
    final t = fs * .35;
    void line(double x1, double y1, double x2, double y2) => c.drawLine(Offset(x1, y1), Offset(x2, y2), p);
    if (horiz) {
      line(v.first, off, v.last, off);
    } else {
      line(off, v.first, off, v.last);
    }
    for (final x in v) {
      if (horiz) {
        line(x, off - t * 2, x, off + t * 2);
        line(x - t, off + t, x + t, off - t);
      } else {
        line(off - t * 2, x, off + t * 2, x);
        line(off - t, x + t, off + t, x - t);
      }
    }
    for (var i = 0; i < v.length - 1; i++) {
      final mid = (v[i] + v[i + 1]) / 2;
      final label = '${(v[i + 1] - v[i]).round()}';
      if (horiz) {
        _text(c, label, Offset(mid, off - fs * .25), fs, dimColor, above: true);
      } else {
        c.save();
        c.translate(off - fs * .25, mid);
        c.rotate(-math.pi / 2);
        _text(c, label, Offset.zero, fs, dimColor, above: true);
        c.restore();
      }
    }
  }

  void _text(Canvas c, String text, Offset at, double fs, Color col, {bool center = false, bool above = false}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fs, color: col, fontWeight: FontWeight.w500)),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = center ? -tp.height / 2 : (above ? -tp.height : 0.0);
    tp.paint(c, at + Offset(-tp.width / 2, dy));
  }

  Paint _stroke(Color col, double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = col;

  @override
  bool shouldRepaint(covariant DesignPainter old) =>
      old.layout != layout ||
      old.selectedId != selectedId ||
      !setEquals(old.issueIds, issueIds) ||
      old.color != color ||
      old.showDimensions != showDimensions ||
      old.showLabels != showLabels ||
      old.dimColor != dimColor;
}
