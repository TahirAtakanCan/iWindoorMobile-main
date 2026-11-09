import 'package:windoor_core/windoor_core.dart';

import '../services/design_api.dart';

/// Atölye kesim listesi sırası: Kasa → Kanat → Sürme → Orta kayıt → Çıta → Dubleks.
int cutListRank(BomLine l) {
  if (l.group == BomGroup.profile) {
    return switch (l.role) {
      ProfileRole.frame => 0,
      ProfileRole.sash => 1,
      ProfileRole.slideSash => 2,
      ProfileRole.mullion => 3,
      null => 4,
    };
  }
  if (l.group == BomGroup.bead) return 5;
  if (l.group == BomGroup.duplex) return 6;
  return 99;
}

/// Parça adı + boy + kesim aynıysa adetleri birleştirir (cam kodu yok sayılır).
/// Çekirdek BOM değişmez; yalnızca gösterim.
List<BomLine> workshopCutLines(Iterable<BomLine> bom) {
  final raw = bom.where(
    (l) => l.group == BomGroup.profile || l.group == BomGroup.bead || l.group == BomGroup.duplex,
  );
  final map = <String, BomLine>{};
  final order = <String>[];
  for (final l in raw) {
    final key = '${l.label}|${l.length?.toStringAsFixed(1)}|${l.cut ?? ''}';
    final prev = map[key];
    if (prev == null) {
      map[key] = l;
      order.add(key);
    } else {
      map[key] = BomLine.bar(prev.group, prev.label, prev.length, prev.cut, prev.qty + l.qty, role: prev.role);
    }
  }
  final list = [for (final k in order) map[k]!];
  list.sort((a, b) {
    final r = cutListRank(a).compareTo(cutListRank(b));
    if (r != 0) return r;
    return (b.length ?? 0).compareTo(a.length ?? 0);
  });
  return list;
}

const _quoteGroupOrder = ['PROFILE', 'BEAD', 'DUPLEX', 'GLASS', 'PANEL', 'ACCESSORY', 'HARDWARE'];

int _quoteGroupRank(String group) {
  final i = _quoteGroupOrder.indexOf(group.trim().toUpperCase());
  return i < 0 ? 99 : i;
}

/// Kalem / malzeme listesi: grup sırası, grup içinde tutara göre azalan.
List<QuoteLine> sortedQuoteLines(Iterable<QuoteLine> lines) {
  final list = lines.toList();
  list.sort((a, b) {
    final g = _quoteGroupRank(a.group).compareTo(_quoteGroupRank(b.group));
    if (g != 0) return g;
    return b.total.compareTo(a.total);
  });
  return list;
}
