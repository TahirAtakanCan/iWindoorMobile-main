import 'package:test/test.dart';
import 'package:windoor_core/windoor_core.dart';

final _geom = SeriesGeometry(id: 'test');
final _engine = LayoutEngine(_geom);

WindowDesign _base({double w = 1400, double h = 1400}) =>
    WindowDesign.single(w, h, seriesId: 'test');

BomLine? _shutter(List<BomLine> lines) {
  for (final l in lines) {
    if (l.group == BomGroup.shutter) return l;
  }
  return null;
}

List<BomLine> _extra(List<BomLine> lines, String kind) =>
    lines.where((l) => l.group == BomGroup.extra && l.kind == kind).toList();

List<BomLine> _extension(List<BomLine> lines) =>
    lines.where((l) => l.group == BomGroup.profile && l.role == ProfileRole.extension).toList();

void main() {
  test('shutter mono aluminum manual 1400×1400 → SHUTTER w1400 h1580', () {
    final d = _base().copyWith(
      shutter: const Shutter(type: ShutterType.mono, slat: ShutterSlat.aluminum, drive: ShutterDrive.manual),
    );
    final lines = BomLine.aggregate(_engine.run(d).bom);
    final sh = _shutter(lines);
    expect(sh, isNotNull);
    expect(sh!.toJson()['group'], 'SHUTTER');
    expect(sh.kind, 'MONO');
    expect(sh.slat, 'ALUMINUM');
    expect(sh.drive, 'MANUAL');
    expect(sh.w, closeTo(1400, 0.1));
    expect(sh.h, closeTo(1580, 0.1));
  });

  test('extras sillOuter → EXTRA SILL_OUTER 1460', () {
    final d = _base().copyWith(extras: const Extras(sillOuter: true));
    final lines = BomLine.aggregate(_engine.run(d).bom);
    final rows = _extra(lines, 'SILL_OUTER');
    expect(rows.length, 1);
    expect(rows.single.length, closeTo(1460, 0.1));
    expect(rows.single.cut, '90/90');
  });

  test('trim three → TRIM 1540 45/45 ×1 + 1470 45/90 ×2', () {
    final d = _base().copyWith(extras: const Extras(trim: TrimKind.three));
    final lines = BomLine.aggregate(_engine.run(d).bom);
    final tr = _extra(lines, 'TRIM');
    final top = tr.where((l) => l.cut == '45/45').toList();
    final sides = tr.where((l) => l.cut == '45/90').toList();
    expect(top.length, 1);
    expect(top.single.length, closeTo(1540, 0.1));
    expect(top.single.qty, 1);
    expect(sides.length, 1);
    expect(sides.single.length, closeTo(1470, 0.1));
    expect(sides.single.qty, 2);
  });

  test('trim four → 1540×2 top/bottom + 1540×2 sides', () {
    final d = _base().copyWith(extras: const Extras(trim: TrimKind.four));
    final tr = _engine.run(d).bom.where((l) => l.group == BomGroup.extra && l.kind == 'TRIM').toList();
    expect(tr.length, 2);
    expect(tr.every((l) => (l.length! - 1540).abs() < 0.2), isTrue);
    expect(tr.every((l) => l.cut == '45/45'), isTrue);
    expect(tr.fold<int>(0, (a, l) => a + l.qty), 4);
    final merged = BomLine.aggregate(tr);
    expect(merged.single.qty, 4);
  });

  test('extension top 30 → PROFILE EXTENSION 1400 ×1', () {
    final d = _base().copyWith(
      extras: const Extras(extension: FrameExtension(top: 30)),
    );
    final lines = BomLine.aggregate(_engine.run(d).bom);
    final ext = _extension(lines);
    expect(ext.length, 1);
    expect(ext.single.length, closeTo(1400, 0.1));
    expect(ext.single.qty, 1);
    expect(ext.single.toJson()['role'], 'EXTENSION');
  });

  test('shaped + shutter → ERROR', () {
    final d = _base().copyWith(
      shape: const ArchShape(),
      shutter: const Shutter(type: ShutterType.mono, slat: ShutterSlat.aluminum, drive: ShutterDrive.manual),
    );
    final layout = _engine.run(d);
    final issues = checkDesign(layout, _geom, d);
    expect(issues.any((i) => i.isError && i.message.contains('Şekilli pencereye panjur')), isTrue);
  });

  test('no shutter/extras → schemaVersion 1, JSON without shutter/extras keys', () {
    final d = _base();
    expect(d.schemaVersion, 1);
    final j = d.toJson();
    expect(j.containsKey('shutter'), isFalse);
    expect(j.containsKey('extras'), isFalse);
  });
}
