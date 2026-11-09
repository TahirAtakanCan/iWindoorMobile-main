import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/project_quote.dart';
import 'package:iwindoor_mobil/utils/format.dart';

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
        'pricingMode': 'COST_PLUS',
        'profitMarginPct': 25,
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
          'saleUnitPrice': 1800,
          'materialUnitPrice': 1200,
          'overridden': true,
          'lineTotal': 3600,
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
      'extras': [
        {'id': 1, 'name': 'Nakliye', 'quantity': 1, 'unit': 'adet', 'unitPrice': 500, 'sortOrder': 0},
      ],
      'costSummary': {
        'materialTotal': 2400,
        'laborTotal': 300,
        'installTotal': 200,
        'saleSubtotal': 4100,
        'grossProfit': 1200,
        'grossProfitPct': 29.3,
        'windows': [
          {
            'windowId': 3,
            'name': 'P-01',
            'material': 2400,
            'labor': 300,
            'install': 200,
            'sale': 3600,
            'profit': 700,
          }
        ],
      },
      'subtotal': 4100,
      'discountPct': 5,
      'discount': 205,
      'net': 3895,
      'vatRate': 20,
      'vat': 779,
      'grandTotal': 4674,
    };

    final q = ProjectQuote.fromJson(json);
    expect(q.currency, 'TRY');
    expect(q.company.name, 'Demo PVC');
    expect(q.company.pricingMode.name, 'costPlus');
    expect(q.company.profitMarginPct, 25);
    expect(q.project.id, 9);
    expect(q.project.name, 'Villa');
    expect(q.windows, hasLength(1));
    expect(q.windows.first.name, 'P-01');
    expect(q.windows.first.design.width, 1200);
    expect(q.windows.first.design.root.id, 'n1');
    expect(q.windows.first.saleUnitPrice, 1800);
    expect(q.windows.first.materialUnitPrice, 1200);
    expect(q.windows.first.overridden, isTrue);
    expect(q.windows.first.displaySaleUnit, 1800);
    expect(q.windows.first.lines.first.code, 'KASA');
    expect(q.windows.first.warnings, ['Uyarı 1']);
    expect(q.materials.first.group, 'GLASS');
    expect(q.extras, hasLength(1));
    expect(q.extras.first.name, 'Nakliye');
    expect(q.extras.first.total, 500);
    expect(q.costSummary, isNotNull);
    expect(q.costSummary!.materialTotal, 2400);
    expect(q.costSummary!.windows.single.profit, 700);
    expect(q.subtotal, 4100);
    expect(q.discountAmount, 205);
    expect(q.netTotal, 3895);
    expect(q.vatAmount, 779);
    expect(q.grandTotal, 4674);
    expect(formatMoney(q.grandTotal), contains('TL'));
    expect(q.generatedAt, isNotNull);
    expect(q.validUntil, isNotNull);
  });
}
