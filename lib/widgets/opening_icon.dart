import 'package:flutter/material.dart';
import 'package:windoor_core/windoor_core.dart';

/// iWindoor araç çubuğundaki gibi küçük çizim ikonları (açılım tipleri ve bölme).
class OpeningIcon extends StatelessWidget {
  final OpeningChoice? opening;
  final SplitDir? splitDir;
  final int parts;
  final bool unsplit;
  final double size;
  final Color? color;

  const OpeningIcon.opening(this.opening, {super.key, this.size = 26, this.color})
      : splitDir = null,
        parts = 0,
        unsplit = false;

  const OpeningIcon.split(this.splitDir, this.parts, {super.key, this.size = 26, this.color})
      : opening = null,
        unsplit = false;

  const OpeningIcon.unsplit({super.key, this.size = 26, this.color})
      : opening = null,
        splitDir = null,
        parts = 0,
        unsplit = true;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.blue;
    return CustomPaint(size: Size(size, size), painter: _IconPainter(opening, splitDir, parts, unsplit, c));
  }

  static String label(OpeningChoice c) => switch (c) {
        OpeningChoice.fixed => 'Sabit',
        OpeningChoice.turnLeft => 'Açılır (sol menteşe)',
        OpeningChoice.turnRight => 'Açılır (sağ menteşe)',
        OpeningChoice.tilt => 'Vasistas',
        OpeningChoice.tiltTurnLeft => 'Çift açılım (sol)',
        OpeningChoice.tiltTurnRight => 'Çift açılım (sağ)',
        OpeningChoice.slide => 'Sürme',
      };
}

class _IconPainter extends CustomPainter {
  final OpeningChoice? opening;
  final SplitDir? dir;
  final int parts;
  final bool unsplit;
  final Color color;
  _IconPainter(this.opening, this.dir, this.parts, this.unsplit, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final w = size.width, h = size.height;
    final r = Rect.fromLTWH(w * .14, h * .06, w * .72, h * .88);
    canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(1.5)), p);
    final i = r.deflate(w * .1);
    void path(List<Offset> pts) {
      final pa = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        pa.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(pa, p);
    }

    if (dir != null) {
      for (var k = 1; k < parts; k++) {
        if (dir == SplitDir.v) {
          final x = r.left + r.width * k / parts;
          canvas.drawLine(Offset(x, r.top), Offset(x, r.bottom), p);
        } else {
          final y = r.top + r.height * k / parts;
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), p);
        }
      }
      return;
    }
    if (unsplit) {
      final q = Paint()
        ..color = color
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final x = r.center.dx;
      for (var y = r.top; y < r.bottom; y += 4) {
        canvas.drawLine(Offset(x, y), Offset(x, (y + 2).clamp(r.top, r.bottom).toDouble()), q);
      }
      canvas.drawLine(Offset(r.left + 3, r.top + 3), Offset(r.right - 3, r.bottom - 3), p);
      return;
    }
    switch (opening) {
      case OpeningChoice.turnLeft:
        path([i.topRight, i.centerLeft, i.bottomRight]);
      case OpeningChoice.turnRight:
        path([i.topLeft, i.centerRight, i.bottomLeft]);
      case OpeningChoice.tilt:
        path([i.topLeft, i.bottomCenter, i.topRight]);
      case OpeningChoice.tiltTurnLeft:
        path([i.topRight, i.centerLeft, i.bottomRight]);
        path([i.topLeft, i.bottomCenter, i.topRight]);
      case OpeningChoice.tiltTurnRight:
        path([i.topLeft, i.centerRight, i.bottomLeft]);
        path([i.topLeft, i.bottomCenter, i.topRight]);
      case OpeningChoice.slide:
        final y1 = i.top + i.height * .38, y2 = i.top + i.height * .62;
        path([Offset(i.left, y1), Offset(i.right, y1)]);
        path([Offset(i.right - 4, y1 - 3), Offset(i.right, y1), Offset(i.right - 4, y1 + 3)]);
        path([Offset(i.right, y2), Offset(i.left, y2)]);
        path([Offset(i.left + 4, y2 - 3), Offset(i.left, y2), Offset(i.left + 4, y2 + 3)]);
      case OpeningChoice.fixed:
      case null:
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _IconPainter old) =>
      old.opening != opening || old.dir != dir || old.parts != parts || old.color != color || old.unsplit != unsplit;
}
