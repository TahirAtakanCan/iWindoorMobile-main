// Sürüm karşılaştırma (pencere ad eşleşmesi).

class VersionWindowSnap {
  final String name;
  final double width;
  final double height;
  final int quantity;
  final String? glass;
  final String? color;
  final double unitPrice;

  const VersionWindowSnap({
    required this.name,
    required this.width,
    required this.height,
    this.quantity = 1,
    this.glass,
    this.color,
    this.unitPrice = 0,
  });
}

enum WindowDiffKind { added, removed, changed, same }

class WindowDiff {
  final WindowDiffKind kind;
  final String name;
  final VersionWindowSnap? a;
  final VersionWindowSnap? b;
  final List<String> changes;

  const WindowDiff({
    required this.kind,
    required this.name,
    this.a,
    this.b,
    this.changes = const [],
  });
}

class VersionCompareResult {
  final double grandTotalA;
  final double grandTotalB;
  final double totalDiff;
  final double totalDiffPct;
  final List<WindowDiff> windows;

  const VersionCompareResult({
    required this.grandTotalA,
    required this.grandTotalB,
    required this.totalDiff,
    required this.totalDiffPct,
    required this.windows,
  });
}

VersionCompareResult compareVersions({
  required double grandTotalA,
  required double grandTotalB,
  required List<VersionWindowSnap> windowsA,
  required List<VersionWindowSnap> windowsB,
}) {
  final mapA = {for (final w in windowsA) w.name: w};
  final mapB = {for (final w in windowsB) w.name: w};
  final names = {...mapA.keys, ...mapB.keys}.toList()..sort();
  final diffs = <WindowDiff>[];

  for (final name in names) {
    final a = mapA[name];
    final b = mapB[name];
    if (a == null && b != null) {
      diffs.add(WindowDiff(kind: WindowDiffKind.added, name: name, b: b));
    } else if (a != null && b == null) {
      diffs.add(WindowDiff(kind: WindowDiffKind.removed, name: name, a: a));
    } else if (a != null && b != null) {
      final changes = <String>[];
      if (a.width != b.width || a.height != b.height) {
        changes.add('Ölçü: ${a.width.round()}×${a.height.round()} → ${b.width.round()}×${b.height.round()}');
      }
      if (a.quantity != b.quantity) changes.add('Adet: ${a.quantity} → ${b.quantity}');
      if ((a.glass ?? '') != (b.glass ?? '')) changes.add('Cam: ${a.glass ?? '—'} → ${b.glass ?? '—'}');
      if ((a.color ?? '') != (b.color ?? '')) changes.add('Renk: ${a.color ?? '—'} → ${b.color ?? '—'}');
      if (a.unitPrice != b.unitPrice) {
        changes.add('Fiyat: ${a.unitPrice.toStringAsFixed(2)} → ${b.unitPrice.toStringAsFixed(2)}');
      }
      diffs.add(WindowDiff(
        kind: changes.isEmpty ? WindowDiffKind.same : WindowDiffKind.changed,
        name: name,
        a: a,
        b: b,
        changes: changes,
      ));
    }
  }

  final diff = grandTotalB - grandTotalA;
  final pct = grandTotalA.abs() < 0.0001 ? 0.0 : diff / grandTotalA * 100;
  return VersionCompareResult(
    grandTotalA: grandTotalA,
    grandTotalB: grandTotalB,
    totalDiff: diff,
    totalDiffPct: pct,
    windows: diffs,
  );
}
