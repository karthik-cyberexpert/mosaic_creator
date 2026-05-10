import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:number_name_image/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MosaicApp());
    expect(find.text('Mosaic Maker'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
