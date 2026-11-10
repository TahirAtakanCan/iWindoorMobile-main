import 'package:windoor_core/windoor_core.dart';

import '../models/catalog.dart';
import '../models/project.dart';
import '../models/window_unit.dart';
import '../utils/format.dart';

/// Bir profil kodu için optimize edilmiş kesim planı.
class ProfileCutGroup {
  final String code;
  final String name;
  final double barLengthMm;
  final CutPlan plan;
  final List<CutPiece> pieces;

  const ProfileCutGroup({
    required this.code,
    required this.name,
    required this.barLengthMm,
    required this.plan,
    required this.pieces,
  });

  double get totalMeters => plan.totalBars * barLengthMm / 1000.0;
  double get wastePct => plan.wastePct * 100;
}

class ProjectCutPlan {
  final List<ProfileCutGroup> groups;
  const ProjectCutPlan(this.groups);

  List<CutPiece> get allUncuttable => [for (final g in groups) ...g.plan.uncuttable];
}

class GlassOrderLine {
  final String posLabel; // "P1, P4"
  final double width;
  final double height;
  final int qty;
  final double areaM2;

  const GlassOrderLine({
    required this.posLabel,
    required this.width,
    required this.height,
    required this.qty,
    required this.areaM2,
  });
}

class GlassOrderGroup {
  final String code;
  final String name;
  final bool isPanel;
  final List<GlassOrderLine> lines;

  const GlassOrderGroup({
    required this.code,
    required this.name,
    required this.isPanel,
    required this.lines,
  });

  int get totalQty => lines.fold(0, (a, l) => a + l.qty);
  double get totalAreaM2 => lines.fold(0.0, (a, l) => a + l.areaM2);
}

class GlassOrder {
  final List<GlassOrderGroup> groups;
  const GlassOrder(this.groups);

  int get totalQty => groups.fold(0, (a, g) => a + g.totalQty);
  double get totalAreaM2 => groups.fold(0.0, (a, g) => a + g.totalAreaM2);
}

class WorkshopPos {
  final int index; // 1-based
  final WindowUnit unit;
  final WindowDesign design;
  final LayoutResult layout;
  final SeriesInfo series;
  final String? colorName;

  const WorkshopPos({
    required this.index,
    required this.unit,
    required this.design,
    required this.layout,
    required this.series,
    this.colorName,
  });

  String get pos => 'P$index';
}

/// Proje → kesim planı / cam siparişi / poz listesi.
class ProductionPlanner {
  static ProfileResolver resolverOf(CatalogSnapshot catalog) {
    final thickness = <String, double>{
      for (final g in catalog.glasses)
        if (g.thicknessMm != null) g.code: g.thicknessMm!.toDouble(),
    };
    return ProfileResolver(
      profiles: [for (final p in catalog.profiles) p.toCatalogProfile()],
      glassThicknessMm: thickness,
    );
  }

  static List<WorkshopPos> positions(Project project, CatalogSnapshot catalog) {
    final out = <WorkshopPos>[];
    for (var i = 0; i < project.windowUnits.length; i++) {
      final u = project.windowUnits[i];
      final design = u.previewDesign;
      final series = catalog.seriesFor(u.seriesId ?? design.seriesId);
      final layout = LayoutEngine(series.geometry).run(design);
      final color = catalog.colorByCode(design.colorCode);
      out.add(WorkshopPos(
        index: i + 1,
        unit: u,
        design: design,
        layout: layout,
        series: series,
        colorName: color?.name,
      ));
    }
    return out;
  }

  static ProjectCutPlan buildCutPlan(
    Project project,
    CatalogSnapshot catalog, {
    required double kerf,
    required double trim,
    required double minOffcut,
  }) {
    final resolver = resolverOf(catalog);
    final pos = positions(project, catalog);
    final byCode = <String, _Acc>{};

    void addPiece({
      required String code,
      required String name,
      required double barLength,
      required CutPiece piece,
      required int qty,
    }) {
      final acc = byCode.putIfAbsent(
        code,
        () => _Acc(code: code, name: name, barLength: barLength),
      );
      for (var i = 0; i < qty; i++) {
        acc.pieces.add(piece);
      }
    }

    for (final p in pos) {
      final seriesId = p.unit.seriesId ?? int.tryParse('${p.design.seriesId}');
      final bom = BomLine.aggregate(p.layout.bom);
      for (final line in bom) {
        if (line.length == null || line.qty <= 0) continue;
        final totalQty = line.qty * p.unit.quantity;
        if (line.group == BomGroup.profile && line.role != null) {
          final role = _roleName(line.role!);
          final profile = resolver.resolve(seriesId: seriesId, role: role);
          final code = profile?.code ?? role;
          final name = profile?.name ?? line.label;
          final barLen = profile?.barLengthMm ?? 6500;
          final label = '${p.pos} · ${profileRoleTr(role)} · ${line.cut ?? ''}';
          addPiece(
            code: code,
            name: name,
            barLength: barLen,
            piece: CutPiece(length: line.length!, label: label.trim(), cut: line.cut),
            qty: totalQty,
          );
        } else if (line.group == BomGroup.bead) {
          final profile = resolver.resolve(seriesId: seriesId, role: 'BEAD', glassCode: line.glassCode);
          final code = profile?.code ?? 'BEAD';
          final name = profile?.name ?? 'Cam çıtası';
          final barLen = profile?.barLengthMm ?? 6500;
          final label = '${p.pos} · Çıta · ${line.cut ?? ''}';
          addPiece(
            code: code,
            name: name,
            barLength: barLen,
            piece: CutPiece(length: line.length!, label: label.trim(), cut: line.cut),
            qty: totalQty,
          );
        } else if (line.group == BomGroup.duplex) {
          final label = '${p.pos} · Dubleks · ${line.cut ?? ''}';
          addPiece(
            code: 'DUPLEX',
            name: 'Dubleks',
            barLength: 6000,
            piece: CutPiece(length: line.length!, label: label.trim(), cut: line.cut),
            qty: totalQty,
          );
        } else if (line.group == BomGroup.extra) {
          final code = switch ((line.kind ?? '').toUpperCase()) {
            'SILL_OUTER' => 'DENIZLIK-DIS',
            'SILL_INNER' => 'DENIZLIK-IC',
            'TRIM' => 'PERVAZ',
            _ => line.kind ?? 'EXTRA',
          };
          final label = '${p.pos} · ${line.label} · ${line.cut ?? ''}';
          addPiece(
            code: code,
            name: line.label,
            barLength: 6000,
            piece: CutPiece(length: line.length!, label: label.trim(), cut: line.cut),
            qty: totalQty,
          );
        }
      }
    }

    const opt = CutOptimizer();
    final groups = byCode.values.toList()
      ..sort((a, b) => a.code.compareTo(b.code));
    return ProjectCutPlan([
      for (final a in groups)
        ProfileCutGroup(
          code: a.code,
          name: a.name,
          barLengthMm: a.barLength,
          pieces: a.pieces,
          plan: opt.optimize(
            pieces: a.pieces,
            barLength: a.barLength,
            trim: trim,
            kerf: kerf,
            minOffcut: minOffcut,
          ),
        ),
    ]);
  }

  static GlassOrder buildGlassOrder(Project project, CatalogSnapshot catalog) {
    final pos = positions(project, catalog);
    // key: panel|code|w|h → positions + qty
    final map = <String, _GlassAcc>{};
    for (final p in pos) {
      final bom = BomLine.aggregate(p.layout.bom);
      for (final line in bom) {
        if (line.group != BomGroup.glass && line.group != BomGroup.panel) continue;
        if (line.w == null || line.h == null || line.glassCode == null) continue;
        final isPanel = line.group == BomGroup.panel;
        final code = line.glassCode!;
        final w = line.w!;
        final h = line.h!;
        final key = '${isPanel ? 'P' : 'G'}|$code|${w.toStringAsFixed(1)}|${h.toStringAsFixed(1)}';
        final info = catalog.glassByCode(code);
        final acc = map.putIfAbsent(
          key,
          () => _GlassAcc(
            code: code,
            name: info?.name ?? code,
            isPanel: isPanel,
            width: w,
            height: h,
          ),
        );
        acc.qty += line.qty * p.unit.quantity;
        if (!acc.positions.contains(p.pos)) acc.positions.add(p.pos);
      }
    }

    final glassGroups = <String, List<GlassOrderLine>>{};
    final panelGroups = <String, List<GlassOrderLine>>{};
    final names = <String, String>{};

    for (final a in map.values) {
      final line = GlassOrderLine(
        posLabel: a.positions.join(', '),
        width: a.width,
        height: a.height,
        qty: a.qty,
        areaM2: a.width * a.height * a.qty / 1e6,
      );
      names[a.code] = a.name;
      if (a.isPanel) {
        panelGroups.putIfAbsent(a.code, () => []).add(line);
      } else {
        glassGroups.putIfAbsent(a.code, () => []).add(line);
      }
    }

    final groups = <GlassOrderGroup>[
      for (final code in (glassGroups.keys.toList()..sort()))
        GlassOrderGroup(code: code, name: names[code] ?? code, isPanel: false, lines: glassGroups[code]!),
    ];
    if (panelGroups.isNotEmpty) {
      final panelLines = <GlassOrderLine>[
        for (final code in (panelGroups.keys.toList()..sort())) ...panelGroups[code]!,
      ];
      groups.add(GlassOrderGroup(code: 'PANEL', name: 'Paneller', isPanel: true, lines: panelLines));
    }
    return GlassOrder(groups);
  }
}

class _Acc {
  final String code;
  final String name;
  final double barLength;
  final List<CutPiece> pieces = [];
  _Acc({required this.code, required this.name, required this.barLength});
}

class _GlassAcc {
  final String code;
  final String name;
  final bool isPanel;
  final double width;
  final double height;
  final List<String> positions = [];
  int qty = 0;
  _GlassAcc({
    required this.code,
    required this.name,
    required this.isPanel,
    required this.width,
    required this.height,
  });
}

String _roleName(ProfileRole r) => switch (r) {
      ProfileRole.frame => 'FRAME',
      ProfileRole.sash => 'SASH',
      ProfileRole.mullion => 'MULLION',
      ProfileRole.slideSash => 'SLIDE_SASH',
      ProfileRole.adapter => 'ADAPTER',
      ProfileRole.doorSash => 'DOOR_SASH',
      ProfileRole.threshold => 'THRESHOLD',
      ProfileRole.coupling => 'COUPLING',
      ProfileRole.extension => 'EXTENSION',
    };
