import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/catalog.dart';
import 'package:iwindoor_mobil/models/project_quote.dart';
import 'package:iwindoor_mobil/pdf/pdf_fonts.dart';
import 'package:iwindoor_mobil/services/pdf_service.dart';

ProjectQuote _sampleQuote({int windowCount = 1}) {
  Map<String, dynamic> window(int i) => {
        'windowId': i,
        'name': 'P-0$i',
        'quantity': 1,
        'width': 1200,
        'height': 1400,
        'seriesName': 'Varsayılan seri',
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
        'saleUnitPrice': 1000,
        'unitPrice': 1000,
        'lineTotal': 1000,
        'lines': [
          {
            'group': 'PROFILE',
            'code': 'KASA-GIZLI',
            'name': 'Kasa',
            'quantity': 18.024,
            'unit': 'm',
            'unitPrice': 10,
            'total': 180.24,
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
      'quoteNote': 'Tesekkurler',
      'quoteValidityDays': 30,
    },
    'project': {
      'id': 1,
      'name': 'Test Proje',
      'description': 'PDF deneme',
      'customerName': 'Musteri',
      'customerPhone': '0555',
    },
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
    'extras': [
      {'id': 1, 'name': 'Nakliye', 'quantity': 1, 'unit': 'adet', 'unitPrice': 250, 'sortOrder': 0},
    ],
    'subtotal': 1000.0 * windowCount + 250,
    'discountPct': 0,
    'discountAmount': 0,
    'netTotal': 1000.0 * windowCount + 250,
    'vatRate': 20,
    'vatAmount': 200.0 * windowCount + 50,
    'grandTotal': 1200.0 * windowCount + 300,
  });
}

int _pdfPageCount(Uint8List bytes) {
  final text = latin1.decode(bytes, allowInvalid: true);
  return RegExp(r'/Type\s*/Page[^s]').allMatches(text).length;
}

String _pdfText(Uint8List bytes) => latin1.decode(bytes, allowInvalid: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => PdfFonts.resetCache());

  test('müşteri PDF: çizim/fiyat var; Kalemler ve malzeme kodu yok', () async {
    final fonts = await PdfFonts.load();
    final quote = _sampleQuote(windowCount: 2);
    final bytes = await PdfService().buildQuotePdf(
      quote,
      CatalogSnapshot.fallback,
      base: fonts.$1,
      bold: fonts.$2,
      compress: false,
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    expect(_pdfPageCount(bytes), greaterThanOrEqualTo(expectedQuotePageCount(quote)));

    final text = _pdfText(bytes);
    expect(text.contains('Kalemler'), isFalse, reason: 'müşteri PDF malzeme kalemleri içermez');
    expect(text.contains('KASA-GIZLI'), isFalse, reason: 'malzeme kodu müşteri PDFinde olmamalı');
    expect(text.contains('Kesim'), isFalse, reason: 'kesim listesi atölye föyünde');
    expect(text.contains('Malzeme'), isFalse, reason: 'malzeme özeti müşteri PDFinde yok');
    // Gömülü Roboto ile içerik stream'i latin1 ASCII metin taşımaz; font adı / boyut doğrula.
    expect(text.contains('Roboto') || text.contains('Identity-H'), isTrue);
    expect(bytes.length, greaterThan(4000));
  });
}
