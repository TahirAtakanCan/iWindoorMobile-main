import 'dart:math' as math;

import 'package:flutter/material.dart' show Color;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:windoor_core/windoor_core.dart';

import '../drawing/glass_look.dart';

class _Xform {
  final double ox, oy, k, designH, widgetH;
  const _Xform(this.ox, this.oy, this.k, this.designH, this.widgetH);

  /// mm (y aşağı) → PDF nokta (y yukarı, widget sol alt orijin).
  double x(double mmX) => ox + mmX * k;
  double y(double mmY) => oy + (designH - mmY) * k;

  /// Stack Positioned için üstten mesafe.
  double topFromMm(double mmY, {double textH = 0}) => widgetH - y(mmY) - textH;
}

PdfColor _pdf(Color c) {
  final v = c.toARGB32();
  return PdfColor(
    ((v >> 16) & 0xFF) / 255.0,
    ((v >> 8) & 0xFF) / 255.0,
    (v & 0xFF) / 255.0,
  );
}

PdfColor _mixBlack(PdfColor base, double amount) => PdfColor(
      base.red * (1 - amount),
      base.green * (1 - amount),
      base.blue * (1 - amount),
    );

PdfColor _mixWhite(PdfColor base, double amount) => PdfColor(
      base.red + (1 - base.red) * amount,
      base.green + (1 - base.green) * amount,
      base.blue + (1 - base.blue) * amount,
    );

List<double> _uniq(List<double> v) => (v.map((e) => (e * 10).round() / 10).toSet().toList()..sort());

/// Vektör pencere çizimi (PDF). Ölçü yazıları Positioned + Text ile üstte.
pw.Widget pdfWindowDrawing({
  required WindowDesign design,
  required LayoutResult layout,
  required GlassLook Function(String glassCode) lookOf,
  required ProfileColor color,
  required double width,
  required double height,
  bool showDimensions = true,
}) {
  final fsMm = math.max(design.width, design.height) / 30;
  final frameXs = <double>{0.0, design.width};
  for (final f in layout.frames) {
    frameXs.add(f.box.l);
    frameXs.add(f.box.r);
  }
  final xs = [..._uniq([...layout.mullionX, ...frameXs])];
  final ys = [0.0, ..._uniq(layout.mullionY), design.height];
  final hasX = xs.length > 2, hasY = ys.length > 2;
  final multiHeight = layout.frames.length > 1;
  final chainGap = fsMm * 2.4;

  // İki ölçü zinciri + yazılar kesilmesin (DesignPainter pad mantığı, dinamik alt/sol).
  final padL = showDimensions ? math.max(240.0, 80 + (hasY ? chainGap : 0) + fsMm * 1.8) : 30.0;
  final padB = showDimensions ? math.max(240.0, 80 + (hasX ? chainGap : 0) + fsMm * 1.8) : 30.0;
  final padT = showDimensions ? 50.0 : 30.0;
  final padR = showDimensions ? math.max(50.0, multiHeight ? 120.0 : 50.0) : 30.0;

  final totalW = design.width + padL + padR;
  final totalH = design.height + padT + padB;
  final k = math.min(width / totalW, height / totalH);
  final ox = (width - totalW * k) / 2 + padL * k;
  final oy = (height - totalH * k) / 2 + padB * k;
  final xf = _Xform(ox, oy, k, design.height, height);
  final fs = math.max(6.0, fsMm * k);

  final labels = <pw.Widget>[];
  if (showDimensions) {
    labels.addAll(_dimLabels(
      xf,
      xs,
      ys,
      hasX,
      hasY,
      design.width,
      design.height,
      fsMm,
      fs,
      frames: layout.frames,
    ));
  }

  return pw.SizedBox(
    width: width,
    height: height,
    child: pw.Stack(
      children: [
        pw.CustomPaint(
          size: PdfPoint(width, height),
          painter: (canvas, size) => _paintGeometry(
            canvas,
            xf,
            layout,
            lookOf,
            color,
            showDimensions: showDimensions,
            designW: design.width,
            designH: design.height,
            xs: xs,
            ys: ys,
            hasX: hasX,
            hasY: hasY,
            fsMm: fsMm,
          ),
        ),
        ...labels,
      ],
    ),
  );
}

List<pw.Widget> _dimLabels(
  _Xform xf,
  List<double> xs,
  List<double> ys,
  bool hasX,
  bool hasY,
  double designW,
  double designH,
  double fsMm,
  double fs, {
  List<FrameBox> frames = const [],
}) {
  final fontSize = fs.clamp(6.0, 11.0);
  final out = <pw.Widget>[];

  void addHoriz(List<double> v, double offMm) {
    for (var i = 0; i < v.length - 1; i++) {
      final mid = (v[i] + v[i + 1]) / 2;
      final label = '${(v[i + 1] - v[i]).round()}';
      // DesignPainter: off - fs*.25, above → çizginin hemen üstü (kasaya binmez).
      final labelMmY = offMm - fsMm * 0.25;
      final left = xf.x(mid) - fontSize * 1.2;
      final top = xf.topFromMm(labelMmY, textH: fontSize);
      out.add(pw.Positioned(
        left: left,
        top: top,
        child: pw.SizedBox(
          width: fontSize * 2.4,
          child: pw.Text(
            label,
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(fontSize: fontSize, color: PdfColors.grey800),
          ),
        ),
      ));
    }
  }

  void addVert(List<double> v, double offMm, {double fontScale = 1}) {
    final localFs = (fontSize * fontScale).clamp(5.0, 11.0);
    for (var i = 0; i < v.length - 1; i++) {
      final mid = (v[i] + v[i + 1]) / 2;
      final label = '${(v[i + 1] - v[i]).round()}';
      // Solunda; PDF y-up olduğu için +π/2 → aşağıdan yukarı okunur.
      final anchorX = xf.x(offMm - fsMm * 0.25);
      final midTop = xf.topFromMm(mid);
      out.add(pw.Positioned(
        left: anchorX - localFs * 1.2,
        top: midTop - localFs * 1.2,
        child: pw.Transform.rotate(
          angle: math.pi / 2,
          child: pw.SizedBox(
            width: localFs * 2.4,
            child: pw.Text(
              label,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: localFs, color: PdfColors.grey800),
            ),
          ),
        ),
      ));
    }
  }

  if (hasX) addHoriz(xs, designH + 80);
  addHoriz([0, designW], designH + 80 + (hasX ? fsMm * 2.4 : 0));
  if (hasY) addVert(ys, -80);
  addVert([0, designH], -80 - (hasY ? fsMm * 2.4 : 0));
  if (frames.length > 1) {
    for (final f in frames) {
      if ((f.box.h - designH).abs() < 0.5) continue;
      addVert([f.box.t, f.box.b], f.box.r + 60, fontScale: 0.85);
    }
  }
  return out;
}

void _paintGeometry(
  PdfGraphics canvas,
  _Xform xf,
  LayoutResult layout,
  GlassLook Function(String) lookOf,
  ProfileColor color, {
  required bool showDimensions,
  required double designW,
  required double designH,
  required List<double> xs,
  required List<double> ys,
  required bool hasX,
  required bool hasY,
  required double fsMm,
}) {
  final hair = math.max(0.35, 0.7);
  final fill = _pdf(color.fill);
  final stroke = _pdf(color.stroke);
  final hardware = _pdf(color.hardware);

  final prims = [...layout.prims]..sort((a, b) {
      final la = a.layer.index.compareTo(b.layer.index);
      return la != 0 ? la : a.z.compareTo(b.z);
    });

  for (final p in prims) {
    switch (p) {
      case ProfilePoly pp:
        _profile(canvas, xf, pp, fill, stroke, hair);
      case BarRect b:
        _bar(canvas, xf, b, fill, stroke, hair);
      case GlassPrim g:
        _glass(canvas, xf, g, lookOf, stroke, hair);
      case PolylinePrim l:
        if (l.pts.isEmpty) continue;
        if (l.layer == DrawLayer.screen) {
          canvas.setStrokeColor(const PdfColor(0.5, 0.5, 0.5, 0.35));
          canvas.setLineWidth(0.6);
        } else {
          canvas.setStrokeColor(const PdfColor(0.125, 0.188, 0.227));
          canvas.setLineWidth(1.1);
        }
        canvas.setLineJoin(PdfLineJoin.round);
        if (l.dashed) {
          for (var i = 0; i < l.pts.length - 1; i++) {
            final a = l.pts[i], b = l.pts[i + 1];
            final dx = b.x - a.x, dy = b.y - a.y;
            final len = math.sqrt(dx * dx + dy * dy);
            if (len <= 0) continue;
            const dash = 12.0, gap = 7.0;
            var d = 0.0;
            while (d < len) {
              final n = math.min(d + dash, len);
              canvas.moveTo(xf.x(a.x + dx * d / len), xf.y(a.y + dy * d / len));
              canvas.lineTo(xf.x(a.x + dx * n / len), xf.y(a.y + dy * n / len));
              canvas.strokePath();
              d += dash + gap;
            }
          }
        } else {
          canvas.moveTo(xf.x(l.pts.first.x), xf.y(l.pts.first.y));
          for (final q in l.pts.skip(1)) {
            canvas.lineTo(xf.x(q.x), xf.y(q.y));
          }
          canvas.strokePath();
        }
      case HandlePrim h:
        for (final box in [h.base, h.lever, if (h.lock != null) h.lock!]) {
          canvas.setFillColor(hardware);
          canvas.drawRect(xf.x(box.l), xf.y(box.b), (box.r - box.l) * xf.k, (box.b - box.t) * xf.k);
          canvas.fillPath();
          canvas.setStrokeColor(const PdfColor(0.227, 0.255, 0.275));
          canvas.setLineWidth(hair);
          canvas.drawRect(xf.x(box.l), xf.y(box.b), (box.r - box.l) * xf.k, (box.b - box.t) * xf.k);
          canvas.strokePath();
        }
      case TextPrim _:
        break;
    }
  }

  if (showDimensions) {
    _dimLines(canvas, xf, xs, ys, hasX, hasY, designW, designH, fsMm, frames: layout.frames);
  }
}

const _sashShade = {ProfileSide.top: 0.0, ProfileSide.left: .04, ProfileSide.right: .10, ProfileSide.bottom: .15};
const _beadShade = {ProfileSide.top: .16, ProfileSide.left: .10, ProfileSide.right: .03, ProfileSide.bottom: 0.0};

void _profile(PdfGraphics c, _Xform xf, ProfilePoly p, PdfColor fill, PdfColor stroke, double hair) {
  void path() {
    c.moveTo(xf.x(p.pts.first.x), xf.y(p.pts.first.y));
    for (final q in p.pts.skip(1)) {
      c.lineTo(xf.x(q.x), xf.y(q.y));
    }
    c.closePath();
  }

  path();
  c.setFillColor(fill);
  c.fillPath();

  final shade = (p.layer == DrawLayer.bead ? _beadShade : _sashShade)[p.side] ?? 0;
  if (shade > 0) {
    path();
    c.setFillColor(_mixBlack(fill, shade));
    c.fillPath();
  }

  path();
  c.setStrokeColor(stroke);
  c.setLineWidth(hair);
  c.setLineJoin(PdfLineJoin.round);
  c.strokePath();
}

void _bar(PdfGraphics c, _Xform xf, BarRect b, PdfColor fill, PdfColor stroke, double hair) {
  final l = xf.x(b.box.l), bottom = xf.y(b.box.b);
  final w = (b.box.r - b.box.l) * xf.k, h = (b.box.b - b.box.t) * xf.k;
  c.setFillColor(b.metallic ? const PdfColor(0.55, 0.58, 0.62) : fill);
  c.drawRect(l, bottom, w, h);
  c.fillPath();
  if (!b.metallic && b.dir != null) {
    final v = b.dir == SplitDir.v;
    if (v) {
      c.setFillColor(_mixBlack(fill, .08));
      c.drawRect(l + w * .62, bottom, w * .38, h);
      c.fillPath();
    } else {
      c.setFillColor(_mixBlack(fill, .08));
      c.drawRect(l, bottom, w, h * .38);
      c.fillPath();
    }
  }
  c.setStrokeColor(stroke);
  c.setLineWidth(hair);
  c.drawRect(l, bottom, w, h);
  c.strokePath();
}

void _polyPath(PdfGraphics c, _Xform xf, List<Pt> pts) {
  if (pts.isEmpty) return;
  c.moveTo(xf.x(pts.first.x), xf.y(pts.first.y));
  for (final p in pts.skip(1)) {
    c.lineTo(xf.x(p.x), xf.y(p.y));
  }
  c.closePath();
}

void _glass(
  PdfGraphics c,
  _Xform xf,
  GlassPrim g,
  GlassLook Function(String) lookOf,
  PdfColor stroke,
  double hair,
) {
  final box = g.visible;
  final wMm = box.r - box.l, hMm = box.b - box.t;
  if (wMm <= 0 || hMm <= 0) return;
  final l = xf.x(box.l), bottom = xf.y(box.b);
  final w = wMm * xf.k, h = hMm * xf.k;
  final look = g.fill == FillType.panel ? GlassLook.panelLook : lookOf(g.glassCode);
  final mid = _pdf(look.gradient[look.gradient.length ~/ 2]);
  final clip = g.clip;

  void fillShape() {
    if (clip != null && clip.length >= 3) {
      _polyPath(c, xf, clip);
      c.fillPath();
    } else {
      c.drawRect(l, bottom, w, h);
      c.fillPath();
    }
  }

  if (look.panel) {
    c.setFillColor(_pdf(look.gradient.first));
    fillShape();
    c.setStrokeColor(const PdfColor(0.604, 0.639, 0.663));
    c.setLineWidth(hair);
    for (var yMm = box.t + 60; yMm < box.b; yMm += 60) {
      final yy = xf.y(yMm);
      c.moveTo(l, yy);
      c.lineTo(l + w, yy);
      c.strokePath();
    }
    c.setStrokeColor(stroke);
    if (clip != null && clip.length >= 3) {
      _polyPath(c, xf, clip);
      c.strokePath();
    } else {
      c.drawRect(l, bottom, w, h);
      c.strokePath();
    }
    return;
  }

  if (look.frosted) {
    c.setFillColor(_mixWhite(mid, 0.55));
    fillShape();
  } else {
    c.setFillColor(mid);
    fillShape();
  }

  c.saveContext();
  if (clip != null && clip.length >= 3) {
    _polyPath(c, xf, clip);
  } else {
    c.drawRect(l, bottom, w, h);
  }
  c.clipPath();

  if (look.reflection > 0 && !look.frosted) {
    final kBand = math.min(hMm * .55, wMm * .9) * xf.k;
    void band(double a, double t, double opacity) {
      c.setGraphicState(PdfGraphicState(opacity: opacity));
      c.setFillColor(PdfColors.white);
      final x0 = l + a * w;
      final x1 = l + (a + t) * w;
      c.moveTo(x0, bottom);
      c.lineTo(x1, bottom);
      c.lineTo(x1 + kBand, bottom + h);
      c.lineTo(x0 + kBand, bottom + h);
      c.closePath();
      c.fillPath();
      c.setGraphicState(const PdfGraphicState(opacity: 1));
    }

    band(.08, .16, 0.35);
    band(.30, .05, 0.28);
  }

  if (look.patterned) {
    c.setStrokeColor(_mixWhite(mid, 0.7));
    c.setLineWidth(0.8);
    const step = 36.0;
    for (var d = -hMm; d < wMm; d += step) {
      c.moveTo(xf.x(box.l + d), xf.y(box.b));
      c.lineTo(xf.x(box.l + d + hMm), xf.y(box.t));
      c.strokePath();
      c.moveTo(xf.x(box.l + d), xf.y(box.t));
      c.lineTo(xf.x(box.l + d + hMm), xf.y(box.b));
      c.strokePath();
    }
  }

  if (look.laminated) {
    final inner = box.deflate(8);
    c.setStrokeColor(const PdfColor(0.373, 0.541, 0.651));
    c.setLineWidth(hair);
    c.setLineDashPattern([6, 4]);
    c.moveTo(xf.x(inner.l), xf.y(inner.t));
    c.lineTo(xf.x(inner.r), xf.y(inner.t));
    c.lineTo(xf.x(inner.r), xf.y(inner.b));
    c.lineTo(xf.x(inner.l), xf.y(inner.b));
    c.closePath();
    c.strokePath();
    c.setLineDashPattern([]);
  }

  c.restoreContext();

  c.setStrokeColor(const PdfColor(0.373, 0.541, 0.651));
  c.setLineWidth(0.7);
  c.drawRect(l, bottom, w, h);
  c.strokePath();
}

void _dimLines(
  PdfGraphics c,
  _Xform xf,
  List<double> xs,
  List<double> ys,
  bool hasX,
  bool hasY,
  double designW,
  double designH,
  double fsMm, {
  List<FrameBox> frames = const [],
}) {
  void chain(List<double> v, bool horiz, double off) {
    c.setStrokeColor(PdfColors.grey800);
    c.setLineWidth(0.6);
    final t = fsMm * .35;
    if (horiz) {
      c.moveTo(xf.x(v.first), xf.y(off));
      c.lineTo(xf.x(v.last), xf.y(off));
      c.strokePath();
    } else {
      c.moveTo(xf.x(off), xf.y(v.first));
      c.lineTo(xf.x(off), xf.y(v.last));
      c.strokePath();
    }
    for (final x in v) {
      if (horiz) {
        c.moveTo(xf.x(x), xf.y(off - t * 2));
        c.lineTo(xf.x(x), xf.y(off + t * 2));
        c.strokePath();
        c.moveTo(xf.x(x - t), xf.y(off + t));
        c.lineTo(xf.x(x + t), xf.y(off - t));
        c.strokePath();
      } else {
        c.moveTo(xf.x(off - t * 2), xf.y(x));
        c.lineTo(xf.x(off + t * 2), xf.y(x));
        c.strokePath();
        c.moveTo(xf.x(off - t), xf.y(x + t));
        c.lineTo(xf.x(off + t), xf.y(x - t));
        c.strokePath();
      }
    }
  }

  if (hasX) chain(xs, true, designH + 80);
  chain([0, designW], true, designH + 80 + (hasX ? fsMm * 2.4 : 0));
  if (hasY) chain(ys, false, -80);
  chain([0, designH], false, -80 - (hasY ? fsMm * 2.4 : 0));
  if (frames.length > 1) {
    for (final f in frames) {
      if ((f.box.h - designH).abs() < 0.5) continue;
      chain([f.box.t, f.box.b], false, f.box.r + 60);
    }
  }
}
