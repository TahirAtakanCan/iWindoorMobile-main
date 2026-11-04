import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/models/project.dart';

void main() {
  test('Project.fromJson müşteri alanlarını okur', () {
    final p = Project.fromJson({
      'id': 1,
      'name': 'Villa',
      'description': 'Salon',
      'totalPrice': 10,
      'windowUnits': [],
      'customerName': 'Ali',
      'customerPhone': '0555',
      'customerEmail': 'a@b.com',
      'customerAddress': 'Ankara',
    });
    expect(p.customerName, 'Ali');
    expect(p.customerPhone, '0555');
    expect(p.customerEmail, 'a@b.com');
    expect(p.customerAddress, 'Ankara');
  });

  test('Project.fromJson müşteri alanları yoksa null', () {
    final p = Project.fromJson({
      'id': 2,
      'name': 'Boş',
      'description': '',
      'totalPrice': 0,
      'windowUnits': [],
    });
    expect(p.customerName, isNull);
    expect(p.customerPhone, isNull);
    expect(p.customerEmail, isNull);
    expect(p.customerAddress, isNull);
  });
}
