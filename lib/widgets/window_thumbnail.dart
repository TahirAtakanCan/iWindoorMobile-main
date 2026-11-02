import 'package:flutter/material.dart';
import '../models/window_node.dart';
import 'window_painter.dart';

class WindowThumbnail extends StatelessWidget {
  final WindowNode rootNode;
  final String name;
  final double widthMm;
  final double heightMm;

  const WindowThumbnail({
    super.key,
    required this.rootNode,
    required this.name,
    required this.widthMm,
    required this.heightMm,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              // FittedBox ile sığdırma
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  // Sadece pencere boyutu kadar yer ayır (Padding yok)
                  width: widthMm,
                  height: heightMm,
                  child: CustomPaint(
                    painter: WindowPainter(
                      rootNode: rootNode,
                      showDimensions: false, // <--- ÖNEMLİ: Ölçüleri ve Padding'i kapat
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Alt bilgi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: Colors.grey[50], borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), overflow: TextOverflow.ellipsis),
              Text("${widthMm.toInt()} x ${heightMm.toInt()}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ]),
          ),
        ],
      ),
    );
  }
}