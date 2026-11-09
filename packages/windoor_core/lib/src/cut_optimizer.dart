/// Tek kesilecek parça.
class CutPiece {
  final double length;
  final String label;
  final String? cut;

  const CutPiece({required this.length, required this.label, this.cut});
}

/// Bir boy üzerindeki yerleşim.
class CutBar {
  final List<CutPiece> pieces;
  final double used;
  final double remaining;

  const CutBar({required this.pieces, required this.used, required this.remaining});
}

/// Bir profil kodu için kesim planı.
class CutPlan {
  final List<CutBar> bars;
  final int totalBars;
  final double wasteMm;
  final double usableOffcuts;
  final double wastePct;
  final List<CutPiece> uncuttable;

  const CutPlan({
    required this.bars,
    required this.totalBars,
    required this.wasteMm,
    required this.usableOffcuts,
    required this.wastePct,
    this.uncuttable = const [],
  });

  double get totalUsedMm => bars.fold(0.0, (a, b) => a + b.used);
}

/// Best Fit Decreasing kesim optimizasyonu.
class CutOptimizer {
  const CutOptimizer();

  /// [kerf] her parça için testere payı (mm).
  /// [trim] her uçtan kesim payı; kullanılabilir boy = barLength - 2×trim.
  CutPlan optimize({
    required List<CutPiece> pieces,
    required double barLength,
    double trim = 0,
    double kerf = 0,
    double minOffcut = 0,
  }) {
    final usable = barLength - 2 * trim;
    final uncuttable = <CutPiece>[];
    final workable = <CutPiece>[];
    for (final p in pieces) {
      // Tek parça + kendi kerf'i kullanılabilir boya sığmalı.
      if (p.length + kerf > usable + 1e-9) {
        uncuttable.add(p);
      } else {
        workable.add(p);
      }
    }

    workable.sort((a, b) {
      final c = b.length.compareTo(a.length);
      if (c != 0) return c;
      return a.label.compareTo(b.label);
    });

    final bars = <_BarAcc>[];
    for (final p in workable) {
      int? bestIdx;
      double bestRemain = double.infinity;
      for (var i = 0; i < bars.length; i++) {
        final b = bars[i];
        final need = p.length + kerf;
        if (b.used + need <= usable + 1e-9) {
          final remainAfter = usable - (b.used + need);
          if (remainAfter < bestRemain - 1e-9 ||
              (remainAfter - bestRemain).abs() < 1e-9 && bestIdx != null && i < bestIdx) {
            bestRemain = remainAfter;
            bestIdx = i;
          }
        }
      }
      if (bestIdx != null) {
        bars[bestIdx].add(p, kerf);
      } else {
        final nb = _BarAcc();
        nb.add(p, kerf);
        bars.add(nb);
      }
    }

    final result = <CutBar>[];
    var wasteMm = 0.0;
    var usableOffcuts = 0.0;
    for (final b in bars) {
      final remaining = usable - b.used;
      result.add(CutBar(pieces: List.unmodifiable(b.pieces), used: b.used, remaining: remaining));
      if (remaining + 1e-9 >= minOffcut) {
        usableOffcuts += remaining;
      } else {
        wasteMm += remaining;
      }
    }

    final totalBars = result.length;
    final denom = totalBars * barLength;
    final wastePct = denom <= 0 ? 0.0 : wasteMm / denom;

    return CutPlan(
      bars: result,
      totalBars: totalBars,
      wasteMm: wasteMm,
      usableOffcuts: usableOffcuts,
      wastePct: wastePct,
      uncuttable: uncuttable,
    );
  }
}

class _BarAcc {
  final List<CutPiece> pieces = [];
  double used = 0;

  void add(CutPiece p, double kerf) {
    pieces.add(p);
    used += p.length + kerf;
  }
}
