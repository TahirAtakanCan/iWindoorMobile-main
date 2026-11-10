import 'package:windoor_core/windoor_core.dart';

import '../services/design_api.dart';

/// Atölye kesim listesi sırası: Kasa → Eşik → Kanat → Kapı → Sürme → Orta kayıt → Birleştirme → Adaptör → Çıta → Dubleks.
int cutListRank(BomLine l) {
  if (l.group == BomGroup.color) return 100; // kesim tablosunda gösterilmez
  if (l.group == BomGroup.profile) {
    return switch (l.role) {
      ProfileRole.frame => 0,
      ProfileRole.threshold => 1,
      ProfileRole.sash => 2,
      ProfileRole.doorSash => 3,
      ProfileRole.slideSash => 4,
      ProfileRole.mullion => 5,
      ProfileRole.coupling => 6,
      ProfileRole.adapter => 7,
      ProfileRole.extension => 8,
      null => 9,
    };
  }
  if (l.group == BomGroup.extra) return 11;
  if (l.group == BomGroup.bead) return 12;
  if (l.group == BomGroup.duplex) return 13;
  if (l.group == BomGroup.shutter) return 98;
  return 99;
}

/// Parça adı + boy + kesim aynıysa adetleri birleştirir (cam kodu yok sayılır).
/// Çekirdek BOM değişmez; yalnızca gösterim.
List<BomLine> workshopCutLines(Iterable<BomLine> bom) {
  final raw = bom.where(
    (l) =>
        (l.group == BomGroup.profile ||
            l.group == BomGroup.bead ||
            l.group == BomGroup.duplex ||
            l.group == BomGroup.extra) &&
        l.group != BomGroup.color,
  );
  final map = <String, BomLine>{};
  final order = <String>[];
  for (final l in raw) {
    final key =
        '${l.group.name}|${l.kind ?? ''}|${l.role?.name ?? ''}|${l.label}|${l.length?.toStringAsFixed(1)}|${l.cut ?? ''}|${l.bent}|${l.radius?.toStringAsFixed(1)}';
    final prev = map[key];
    if (prev == null) {
      map[key] = l;
      order.add(key);
    } else if (prev.bent && prev.radius != null) {
      map[key] = BomLine.barBent(
        prev.group,
        prev.label,
        prev.length,
        prev.cut,
        prev.qty + l.qty,
        prev.radius!,
        role: prev.role,
        glassCode: prev.glassCode,
      );
    } else if (prev.group == BomGroup.extra) {
      map[key] = BomLine.extra(prev.kind!, prev.label, prev.length!, prev.cut!, prev.qty + l.qty);
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

const _quoteGroupOrder = ['PROFILE', 'BEAD', 'DUPLEX', 'GLASS', 'PANEL', 'ACCESSORY', 'COLOR', 'HARDWARE'];

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
