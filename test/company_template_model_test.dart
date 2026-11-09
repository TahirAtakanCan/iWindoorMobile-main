import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/services/template_api.dart';
import 'package:windoor_core/windoor_core.dart';

void main() {
  test('CompanyTemplate fromJson/toJson', () {
    final t = CompanyTemplate.fromJson({
      'id': 7,
      'name': 'Ofis penceresi',
      'category': 'WINDOW',
      'sortOrder': 2,
      'updatedAt': '2026-01-15T10:00:00Z',
      'design': WindowDesign.single(1200, 1400, seriesId: '3').toJson(),
    });
    expect(t.id, 7);
    expect(t.name, 'Ofis penceresi');
    expect(t.category, 'WINDOW');
    expect(t.sortOrder, 2);
    expect(t.design.width, 1200);
    expect(t.toJson()['name'], 'Ofis penceresi');
    expect(t.toJson()['design'], isA<Map>());
  });
}
