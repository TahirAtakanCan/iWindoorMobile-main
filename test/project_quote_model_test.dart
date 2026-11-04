import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/project_quote.dart';

void main() {
  test('ProjectQuote.fromJson alanları doğru okunur', () {
    final json = {
      'generatedAt': '2026-11-04T10:00:00Z',
      'validUntil': '2026-12-04T10:00:00Z',
      'currency': 'TRY',
      'company': {
        'id': 1,
        'name': 'Demo PVC',
        'address': 'Organize Sanayi',
        'taxNumber': '123',
        'taxOffice': 'Merkez',
        'phone': '0555',
        'email': 'a@b.com',
        'vatRate': 20,
        'defaultDiscountPct': 5,
        'currency': 'TRY',
        'quoteNote': 'Not',
        'quoteValidityDays': 30,
      },
      'project': {'id': 9, 'name': 'Villa', 'description': 'Salon'},
      'windows': [
        {
          'windowId': 3,
          'name': 'P-01',
          'quantity': 2,
          'width': 1200,
          'height': 1400,
          'seriesName': 'Ekonomik',
          'design': {
            'schemaVersion': 1,
            'width': 1200,
            'height': 1400,
            'series': '1',
            'color': 'white',
            'root': {'id': 'n1', 'type': 'glass', 'glass': '4+16+4', 'duplex': [1, 1]},
          },
          'unitPrice': 1500.5,
          'lineTotal': 3001,
          'lines': [
            {
              'group': 'PROFILE',
              'code': 'KASA',
              'name': 'Kasa',
              'quantity': 5.2,
              'unit': 'm',
              'unitPrice': 100,
              'total': 520,
            }
          ],
          'warnings': ['Uyarı 1'],
        }
      ],
      'materials': [
        {
          'group': 'GLASS',
          'code': '4+16+4',
          'name': 'Cam',
          'quantity': 3.2,
          'unit': 'm2',
          'unitPrice': 200,
          'total': 640,
        }
      ],
      'subtotal': 3001,
      'discountPct': 5,
      'discountAmount': 150.05,
      'netTotal': 2850.95,
      'vatRate': 20,
      'vatAmount': 570.19,
      'grandTotal': 3421.14,
    };

    final q = ProjectQuote.fromJson(json);
    expect(q.currency, 'TRY');
    expect(q.company.name, 'Demo PVC');
    expect(q.company.vatRate, 20);
    expect(q.project.id, 9);
    expect(q.project.name, 'Villa');
    expect(q.windows, hasLength(1));
    expect(q.windows.first.name, 'P-01');
    expect(q.windows.first.design.width, 1200);
    expect(q.windows.first.design.root.id, 'n1');
    expect(q.windows.first.lines.first.code, 'KASA');
    expect(q.windows.first.warnings, ['Uyarı 1']);
    expect(q.materials.first.group, 'GLASS');
    expect(q.subtotal, 3001);
    expect(q.discountPct, 5);
    expect(q.grandTotal, 3421.14);
    expect(q.generatedAt, isNotNull);
    expect(q.validUntil, isNotNull);
  });
}
