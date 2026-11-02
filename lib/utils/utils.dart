import 'package:flutter/material.dart';
import '../models/window_node.dart';

WindowNode? findNodeAt(WindowNode node, Offset localPosition, Offset origin, double scale) {
  // Düğümün ekrandaki boyutu
  double w = node.width * scale;
  double h = node.height * scale;
  Rect rect = Rect.fromLTWH(origin.dx, origin.dy, w, h);

  // Dokunulan nokta bu dikdörtgenin içinde mi?
  if (rect.contains(localPosition)) {
    // Çocukları varsa, önce çocukların içinde ara (Derinlik öncelikli)
    if (node.children.isNotEmpty) {
      double currentX = origin.dx;
      double currentY = origin.dy;

      for (var child in node.children) {
        // Recursive Arama
        var found = findNodeAt(child, localPosition, Offset(currentX, currentY), scale);
        
        if (found != null) return found;

        // Koordinat kaydırma
        if (node.nodeType == 'MULLION_VERTICAL') {
          currentX += child.width * scale;
        } else if (node.nodeType == 'MULLION_HORIZONTAL') {
          currentY += child.height * scale;
        }
      }
    }
    // Çocuklarda bulunamadıysa ve bu alan tıklanan yerdeyse bunu döndür
    return node;
  }
  return null;
}