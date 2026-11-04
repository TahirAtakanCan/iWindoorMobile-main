import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/screens/register_screen.dart';

void main() {
  testWidgets('boş formla kayıt zorunlu alan hataları gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Ad soyad gerekli.'), findsOneWidget);
    expect(find.text('E-posta gerekli.'), findsOneWidget);
    expect(find.text('Şifre gerekli.'), findsOneWidget);
    expect(find.text('Şifre tekrarı gerekli.'), findsOneWidget);
  });

  testWidgets('geçersiz e-posta hatası gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad Soyad *'), 'Ali Veli');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta *'), 'gecersiz');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre *'), 'secret1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre tekrar *'), 'secret1');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Geçerli bir e-posta girin.'), findsOneWidget);
  });

  testWidgets('şifreler farklıysa eşleşme hatası gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));

    await tester.enterText(find.widgetWithText(TextFormField, 'Ad Soyad *'), 'Ali Veli');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-posta *'), 'ali@test.com');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre *'), 'secret1');
    await tester.enterText(find.widgetWithText(TextFormField, 'Şifre tekrar *'), 'secret2');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
    await tester.pumpAndSettle();

    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
  });
}
