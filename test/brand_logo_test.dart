import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iwindoor_mobil/theme/app_theme.dart';
import 'package:iwindoor_mobil/widgets/brand_logo.dart';

void main() {
  testWidgets('BrandLogo adı ve sloganı gösterir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: Center(child: BrandLogo(size: 80, direction: Axis.vertical, showTagline: true))),
    ));
    expect(find.text('Pervaz'), findsOneWidget);
    expect(find.text(Brand.tagline), findsOneWidget);
  });

  testWidgets('BrandLogo.mark yalnızca işareti gösterir', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: BrandLogo.mark(size: 32))));
    expect(find.text('Pervaz'), findsNothing);
  });

  test('Tema marka renklerini kullanır', () {
    final t = AppTheme.light();
    expect(t.colorScheme.primary, Brand.petrol);
    expect(t.colorScheme.secondary, Brand.amber);
  });
}
