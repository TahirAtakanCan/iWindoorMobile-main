import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/utils/version_compare.dart';

void main() {
  test('sürüm karşılaştırma: eklenen/çıkarılan/değişen ve toplam fark', () {
    final r = compareVersions(
      grandTotalA: 100000,
      grandTotalB: 110000,
      windowsA: const [
        VersionWindowSnap(name: 'Salon', width: 1400, height: 1400, quantity: 1, glass: '4+12+4', unitPrice: 5000),
        VersionWindowSnap(name: 'Mutfak', width: 900, height: 1200, quantity: 1, unitPrice: 3000),
      ],
      windowsB: const [
        VersionWindowSnap(name: 'Salon', width: 1500, height: 1400, quantity: 2, glass: 'Low-E', unitPrice: 6000),
        VersionWindowSnap(name: 'Banyo', width: 600, height: 800, quantity: 1, unitPrice: 2000),
      ],
    );

    expect(r.totalDiff, 10000);
    expect(r.totalDiffPct, closeTo(10, 0.01));

    final byName = {for (final d in r.windows) d.name: d};
    expect(byName['Mutfak']!.kind, WindowDiffKind.removed);
    expect(byName['Banyo']!.kind, WindowDiffKind.added);
    expect(byName['Salon']!.kind, WindowDiffKind.changed);
    expect(byName['Salon']!.changes.any((c) => c.contains('Ölçü')), isTrue);
    expect(byName['Salon']!.changes.any((c) => c.contains('Adet')), isTrue);
    expect(byName['Salon']!.changes.any((c) => c.contains('Cam')), isTrue);
    expect(byName['Salon']!.changes.any((c) => c.contains('Fiyat')), isTrue);
  });
}
