import 'package:windoor_core/windoor_core.dart';

import '../models/catalog.dart';

/// Müşteri teklifi için kısa tasarım özeti (cam / açılım).
class DesignSummary {
  final List<String> glassCodes;
  final List<String> openings;

  const DesignSummary({required this.glassCodes, required this.openings});

  String get glassLabel => glassCodes.isEmpty ? '—' : glassCodes.join(', ');
  String get openingLabel => openings.isEmpty ? 'Sabit' : openings.join(', ');
}

DesignSummary summarizeDesign(WindowDesign design, {CatalogSnapshot? catalog}) {
  final glasses = <String>{};
  final openings = <String>{};

  String glassName(String code) {
    if (code.isEmpty) return '—';
    final g = catalog?.glassByCode(code);
    return (g?.name.trim().isNotEmpty == true) ? g!.name : code;
  }

  void walk(DesignNode n) {
    switch (n) {
      case CoupleNode c:
        for (final f in c.children) {
          walk(f);
        }
      case FrameNode f:
        walk(f.child);
      case SplitNode s:
        for (final c in s.children) {
          walk(c);
        }
      case SashNode s:
        openings.add(s.passive ? 'Pasif kanat' : _openingTr(s.opening));
        walk(s.child);
      case SlideNode s:
        openings.add('Sürme');
        walk(s.left);
        walk(s.right);
      case FillNode f:
        if (f.fill == FillType.panel) {
          glasses.add(f.glassCode.isEmpty ? 'Panel' : 'Panel (${glassName(f.glassCode)})');
        } else if (f.glassCode.isNotEmpty) {
          glasses.add(glassName(f.glassCode));
        }
    }
  }

  walk(design.root);
  return DesignSummary(glassCodes: glasses.toList()..sort(), openings: openings.toList()..sort());
}

String _openingTr(OpeningType o) => switch (o) {
      OpeningType.turnLeft => 'Açılır sol',
      OpeningType.turnRight => 'Açılır sağ',
      OpeningType.tilt => 'Vasistas',
      OpeningType.tiltTurnLeft => 'Çift açılım sol',
      OpeningType.tiltTurnRight => 'Çift açılım sağ',
    };
