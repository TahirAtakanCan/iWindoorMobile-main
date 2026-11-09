import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

List<CutPiece> _pcs(List<double> lens) => [
      for (var i = 0; i < lens.length; i++) CutPiece(length: lens[i], label: 'p$i'),
    ];

void main() {
  const opt = CutOptimizer();

  test('BF: 3×3000 + 2×2000 + 1000 → 3 boy, kullanılan 14000', () {
    final plan = opt.optimize(
      pieces: _pcs([3000, 3000, 3000, 2000, 2000, 1000]),
      barLength: 6500,
      trim: 0,
      kerf: 0,
    );
    expect(plan.totalBars, 3);
    expect(plan.totalUsedMm, 14000);
    expect(plan.uncuttable, isEmpty);
  });

  test('kerf 4: 3248+3248 sığmaz → 2 boy', () {
    final plan = opt.optimize(
      pieces: _pcs([3248, 3248]),
      barLength: 6500,
      trim: 0,
      kerf: 4,
    );
    expect(plan.totalBars, 2);
  });

  test('kerf 4: 3246+3246 → 1 boy', () {
    final plan = opt.optimize(
      pieces: _pcs([3246, 3246]),
      barLength: 6500,
      trim: 0,
      kerf: 4,
    );
    expect(plan.totalBars, 1);
  });

  test('boydan uzun parça kesilemez', () {
    final plan = opt.optimize(
      pieces: [const CutPiece(length: 7000, label: 'uzun')],
      barLength: 6500,
      trim: 0,
      kerf: 0,
    );
    expect(plan.totalBars, 0);
    expect(plan.uncuttable.single.length, 7000);
  });

  test('trim 10: kullanılabilir 6480', () {
    final a = opt.optimize(
      pieces: _pcs([3236, 3236]),
      barLength: 6500,
      trim: 10,
      kerf: 4,
    );
    expect(a.totalBars, 1);

    final b = opt.optimize(
      pieces: _pcs([3237, 3237]),
      barLength: 6500,
      trim: 10,
      kerf: 4,
    );
    expect(b.totalBars, 2);
  });

  group('ProfileResolver', () {
    CatalogProfile p({
      required int id,
      required String type,
      required String code,
      int? seriesId = 1,
      bool isDefault = false,
      bool isActive = true,
      double? minGlass,
      double? maxGlass,
    }) =>
        CatalogProfile(
          id: id,
          seriesId: seriesId,
          type: type,
          code: code,
          name: code,
          barLengthMm: 6500,
          isDefault: isDefault,
          isActive: isActive,
          minGlass: minGlass,
          maxGlass: maxGlass,
        );

    test('aktifler içinde isDefault tercih edilir', () {
      final r = ProfileResolver(profiles: [
        p(id: 1, type: 'FRAME', code: 'F-A'),
        p(id: 2, type: 'FRAME', code: 'F-DEF', isDefault: true),
        p(id: 3, type: 'FRAME', code: 'F-B'),
      ]);
      expect(r.resolve(seriesId: 1, role: 'FRAME')!.code, 'F-DEF');
    });

    test('aktif yoksa pasiflerden isDefault', () {
      final r = ProfileResolver(profiles: [
        p(id: 1, type: 'SASH', code: 'S-pasif', isActive: false, isDefault: true),
        p(id: 2, type: 'SASH', code: 'S-pasif2', isActive: false),
      ]);
      expect(r.resolve(seriesId: 1, role: 'SASH')!.code, 'S-pasif');
    });

    test('SLIDE_SASH → SASH tipi', () {
      final r = ProfileResolver(profiles: [
        p(id: 1, type: 'SASH', code: 'KANAT', isDefault: true),
      ]);
      expect(r.resolve(seriesId: 1, role: 'SLIDE_SASH')!.code, 'KANAT');
    });

    test('DOOR_SASH yoksa SASH düşüşü', () {
      final r = ProfileResolver(profiles: [
        p(id: 1, type: 'SASH', code: 'KANAT', isDefault: true),
      ]);
      expect(r.resolve(seriesId: 1, role: 'DOOR_SASH')!.code, 'KANAT');
    });

    test('çıta: kalınlık aralığına göre seçim', () {
      final r = ProfileResolver(
        profiles: [
          p(id: 1, type: 'BEAD', code: 'CITA-20', minGlass: 18, maxGlass: 22, isDefault: true),
          p(id: 2, type: 'BEAD', code: 'CITA-28', minGlass: 24, maxGlass: 32),
        ],
        glassThicknessMm: {'4+16+4': 24, 'ince': 20},
      );
      expect(r.resolve(seriesId: 1, role: 'BEAD', glassCode: '4+16+4')!.code, 'CITA-28');
      expect(r.resolve(seriesId: 1, role: 'BEAD', glassCode: 'ince')!.code, 'CITA-20');
    });

    test('çıta: aralığa uyan yoksa tüm çıtalardan seç', () {
      final r = ProfileResolver(
        profiles: [
          p(id: 1, type: 'BEAD', code: 'CITA-A', minGlass: 10, maxGlass: 12),
          p(id: 2, type: 'BEAD', code: 'CITA-DEF', isDefault: true),
        ],
        glassThicknessMm: {'kalin': 40},
      );
      expect(r.resolve(seriesId: 1, role: 'BEAD', glassCode: 'kalin')!.code, 'CITA-DEF');
    });
  });
}
