import 'package:windoor_core/windoor_core.dart';

import '../models/catalog.dart';
import 'format.dart';

/// Müşteri teklifi için kısa tasarım özeti (cam / açılım / sineklik).
class DesignSummary {
  final List<String> glassCodes;
  final List<String> openings;
  final List<String> screens;
  final String shutterLabel;
  final String extrasLabel;

  const DesignSummary({
    required this.glassCodes,
    required this.openings,
    this.screens = const [],
    this.shutterLabel = '',
    this.extrasLabel = '',
  });

  String get glassLabel => glassCodes.isEmpty ? '—' : glassCodes.join(', ');
  String get openingLabel => openings.isEmpty ? 'Sabit' : openings.join(', ');
  String get screenLabel => screens.isEmpty ? '' : screens.join(', ');
}

DesignSummary summarizeDesign(WindowDesign design, {CatalogSnapshot? catalog}) {
  final glasses = <String>{};
  final openings = <String>{};
  final screens = <String>{};

  String glassName(String code) {
    if (code.isEmpty) return '—';
    final g = catalog?.glassByCode(code);
    return (g?.name.trim().isNotEmpty == true) ? g!.name : code;
  }

  void addScreen(ScreenKind? s) {
    if (s != null) screens.add(screenKindTr(s));
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
        addScreen(s.screen);
        walk(s.child);
      case SlideNode s:
        openings.add(s.system == SlideSystem.liftSlide ? 'Kaldır-sür' : 'Sürme');
        for (final p in s.panels) {
          addScreen(p.screen);
          walk(p.child);
        }
      case FillNode f:
        if (f.fill == FillType.panel) {
          glasses.add(f.glassCode.isEmpty ? 'Panel' : 'Panel (${glassName(f.glassCode)})');
        } else if (f.glassCode.isNotEmpty) {
          glasses.add(glassName(f.glassCode));
        }
    }
  }

  walk(design.root);
  return DesignSummary(
    glassCodes: glasses.toList()..sort(),
    openings: openings.toList()..sort(),
    screens: screens.toList()..sort(),
    shutterLabel: shutterSummaryLabel(design.shutter),
    extrasLabel: extrasSummaryLabel(design.extras),
  );
}

String screenKindTr(ScreenKind k) => switch (k) {
      ScreenKind.plise => 'Pileli',
      ScreenKind.hinged => 'Menteşeli',
      ScreenKind.sliding => 'Sürme',
    };

String _openingTr(OpeningType o) => switch (o) {
      OpeningType.turnLeft => 'Açılır sol',
      OpeningType.turnRight => 'Açılır sağ',
      OpeningType.tilt => 'Vasistas',
      OpeningType.tiltTurnLeft => 'Çift açılım sol',
      OpeningType.tiltTurnRight => 'Çift açılım sağ',
    };
