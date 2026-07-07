// Basic smoke test making sure the app boots into the loading screen
// without throwing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jokerstreet/main.dart';

void main() {
  testWidgets('App boots to the loading screen', (WidgetTester tester) async {
    await tester.pumpWidget(const JokerStreetApp());
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
