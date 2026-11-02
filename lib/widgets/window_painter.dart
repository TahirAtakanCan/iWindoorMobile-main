import 'package:flutter/material.dart';
import '../models/window_node.dart';

class WindowPainter extends CustomPainter {
  final WindowNode rootNode;
  final int? selectedNodeId;
  final bool showDimensions;

  WindowPainter({
    required this.rootNode,
    this.selectedNodeId,
    this.showDimensions = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double padding = showDimensions ? 40.0 : 0.0;
    final double drawWidth = size.width - (padding * 2);
    final double drawHeight = size.height - (padding * 2);

    canvas.translate(padding, padding);

    // 1. DIŞ KASA (SABİT)
    Paint framePaint = Paint()..color = Colors.grey[850]!..style = PaintingStyle.stroke..strokeWidth = 4.0;
    canvas.drawRect(Rect.fromLTWH(0, 0, drawWidth, drawHeight), framePaint);

    // 2. İÇERİK
    _drawNode(canvas, rootNode, Offset.zero, Size(drawWidth, drawHeight));
    
    // 3. ÖLÇÜLER
    if (showDimensions) _drawDimensions(canvas, Size(drawWidth, drawHeight));
  }

  void _drawNode(Canvas canvas, WindowNode node, Offset pos, Size size) {
    Rect rect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);

    // Kapsayıcı mı? (Mullion veya Bölünmüş Frame)
    bool isContainer = node.nodeType.contains('MULLION') || (node.nodeType == 'FRAME' && node.children.isNotEmpty);

    // Sadece YAPRAK (Leaf) parçaları çiz
    if (!isContainer) {
      Paint borderPaint = Paint()..color = Colors.grey[800]!..style = PaintingStyle.stroke..strokeWidth = 1.0;
      
      // Dolgu
      if (node.nodeType == 'GLASS' || node.nodeType == 'SASH') {
        canvas.drawRect(rect.deflate(1), Paint()..color = Colors.lightBlue.withOpacity(0.2)..style = PaintingStyle.fill);
      }
      
      // Kanat Çizimi
      if (node.nodeType == 'SASH') {
         // Kırmızı Çerçeve
         canvas.drawRect(rect.deflate(4), Paint()..color = Colors.red[800]!..style = PaintingStyle.stroke..strokeWidth = 2.5);
         // Açılım Üçgeni
         Path p = Path();
         p.moveTo(rect.right - 10, rect.top + 10);
         p.lineTo(rect.left + 10, rect.center.dy);
         p.lineTo(rect.right - 10, rect.bottom - 10);
         canvas.drawPath(p, Paint()..color = Colors.red.withOpacity(0.6)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      }

      // İnce Sınır Çizgisi
      canvas.drawRect(rect, borderPaint);

      // Seçim
      if (node.id == selectedNodeId) {
        canvas.drawRect(rect.deflate(2), Paint()..color = Colors.blueAccent..style = PaintingStyle.stroke..strokeWidth = 3);
      }
    }

    // Çocukları Gez
    if (node.children.isNotEmpty) {
      double currentPos = 0;
      
      // MULLION_VERTICAL: Dikme atar, YAN YANA böler (Width değişir).
      // MULLION_HORIZONTAL: Kayıt atar, ALT ALTA böler (Height değişir).
      bool splitHorizontally = (node.nodeType == 'MULLION_VERTICAL'); // Yan yana (X ekseninde git)

      for (var child in node.children) {
        double childSize = splitHorizontally 
            ? (child.width / node.width) * size.width
            : (child.height / node.height) * size.height;

        Offset childOffset = splitHorizontally
            ? Offset(pos.dx + currentPos, pos.dy)
            : Offset(pos.dx, pos.dy + currentPos);
            
        Size childDrawSize = splitHorizontally
            ? Size(childSize, size.height)
            : Size(size.width, childSize);

        _drawNode(canvas, child, childOffset, childDrawSize);
        currentPos += childSize;
      }
    }
  }
  
  // _drawDimensions ve _drawText aynı kalabilir (Önceki cevaptaki gibi)
  void _drawDimensions(Canvas canvas, Size size) {
    Paint dimPaint = Paint()..color = Colors.black54..strokeWidth = 1;
    TextStyle textStyle = const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold);
    
    // Sol Ok
    canvas.drawLine(Offset(-15, 0), Offset(-15, size.height), dimPaint);
    _drawText(canvas, "${rootNode.height.toInt()}", Offset(-25, size.height/2), textStyle, rotate: true);
    
    // Alt Ok
    canvas.drawLine(Offset(0, size.height+15), Offset(size.width, size.height+15), dimPaint);
    _drawText(canvas, "${rootNode.width.toInt()}", Offset(size.width/2, size.height+25), textStyle);
  }

  void _drawText(Canvas canvas, String text, Offset center, TextStyle style, {bool rotate = false}) {
    TextSpan span = TextSpan(style: style, text: text);
    TextPainter tp = TextPainter(text: span, textAlign: TextAlign.center, textDirection: TextDirection.ltr);
    tp.layout();
    canvas.save();
    canvas.translate(center.dx, center.dy);
    if (rotate) canvas.rotate(-3.14159 / 2);
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant WindowPainter oldDelegate) => true;
}