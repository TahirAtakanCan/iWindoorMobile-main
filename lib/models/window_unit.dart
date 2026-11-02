import 'window_node.dart';

class WindowUnit {
  final int id;
  final String name;
  final double width;
  final double height;
  final WindowNode? rootNode; // Artık null gelemez ama güvenlik için ? koyabiliriz

  WindowUnit({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    this.rootNode,
  });

  factory WindowUnit.fromJson(Map<String, dynamic> json) {
    return WindowUnit(
      id: json['id'],
      name: json['name'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      rootNode: json['rootNode'] != null 
          ? WindowNode.fromJson(json['rootNode']) 
          : null,
    );
  }
}