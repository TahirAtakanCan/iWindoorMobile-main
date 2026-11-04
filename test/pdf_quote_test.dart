import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/catalog.dart';
import 'package:iwindoor_mobil/models/project_quote.dart';
import 'package:iwindoor_mobil/services/pdf_service.dart';
import 'package:pdf/widgets.dart' as pw;

ProjectQuote _sampleQuote({int windowCount = 1}) {
  Map<String, dynamic> window(int i) => {
        'windowId': i,
        'name': 'P-0$i',
        'quantity': 1,
        'width': 1200,
        'height': 1400,
        'seriesName': 'Ekonomik',
        'design': {
          'schemaVersion': 1,
          'width': 1200,
          'height': 1400,
          'series': '0',
          'color': 'white',
          'root': {
            'id': 'n1',
            'type': 'split',
            'dir': 'V',
            'sizes': [600, 600],
            'children': [
              {'id': 'a', 'type': 'glass', 'glass': '4+16+4', 'duplex': [1, 1]},
              {
                'id': 'b',
                'type': 'sash',
                'open': 'tiltTurnLeft',
                'child': {'id': 'c', 'type': 'glass', 'glass': '4+16+4', 'duplex': [1, 1]},
              },
            ],
          },
        },
        'unitPrice': 1000,
        'lineTotal': 1000,
        'lines': [
          {
            'group': 'PROFILE',
            'code': 'K',
            'name': 'Kasa',
            'quantity': 1,
            'unit': 'm',
            'unitPrice': 10,
            'total': 10,
          }
        ],
        'warnings': <String>[],
      };

  return ProjectQuote.fromJson({
    'generatedAt': '2026-11-04T10:00:00Z',
    'validUntil': '2026-12-04T10:00:00Z',
    'currency': 'TRY',
    'company': {
      'id': 1,
      'name': 'Demo PVC',
      'address': 'OSB 1',
      'taxNumber': '111',
      'taxOffice': 'Merkez',
      'phone': '0500',
      'email': 'demo@test.com',
      'vatRate': 20,
      'defaultDiscountPct': 0,
      'currency': 'TRY',
      'quoteNote': 'Teşekkürler',
      'quoteValidityDays': 30,
    },
    'project': {'id': 1, 'name': 'Test Proje', 'description': 'PDF deneme'},
    'windows': [for (var i = 1; i <= windowCount; i++) window(i)],
    'materials': [
      {
        'group': 'GLASS',
        'code': '4+16+4',
        'name': 'Cam',
        'quantity': 2,
        'unit': 'm2',
        'unitPrice': 100,
        'total': 200,
      }
    ],
    'subtotal': 1000.0 * windowCount,
    'discountPct': 0,
    'discountAmount': 0,
    'netTotal': 1000.0 * windowCount,
    'vatRate': 20,
    'vatAmount': 200.0 * windowCount,
    'grandTotal': 1200.0 * windowCount,
  });
}

int _pdfPageCount(Uint8List bytes) {
  // Ham PDF içinde sayfa nesnelerini say (ağ / font indirmeden).
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('örnek tekliften PDF üretir; %PDF ile başlar ve sayfa sayısı doğru', () async {
    final quote = _sampleQuote(windowCount: 2);
    final bytes = await PdfService().buildQuotePdf(
      quote,
      CatalogSnapshot.fallback,
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(_pdfPageCount(bytes), expectedQuotePageCount(quote));
  });
}
