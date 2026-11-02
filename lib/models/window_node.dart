import 'profile.dart';

class WindowNode {
  final int id;
  final String nodeType; // 'FRAME', 'SASH', 'GLASS' vb.
  final double width;
  final double height;
  final List<WindowNode> children;
  final int itemOrder;
  final Profile? profile; // Yeni alan
  // final Glass? glass; // Cam modeli ekleyince burayı açacağım

  WindowNode({
    required this.id,
    required this.nodeType,
    required this.width,
    required this.height,
    required this.children,
    required this.itemOrder,
    this.profile,
  });

  factory WindowNode.fromJson(Map<String, dynamic> json) {
    var childrenJson = json['children'] as List;
    List<WindowNode> childrenList = childrenJson
        .map((i) => WindowNode.fromJson(i))
        .toList();

    return WindowNode(
      id: json['id'],
      nodeType: json['nodeType'],
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      itemOrder: json['itemOrder'] ?? 0,
      children: childrenList,
      profile: json['profile'] != null ? Profile.fromJson(json['profile']) : null,
    );
  }
}