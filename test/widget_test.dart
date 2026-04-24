// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:digients_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DigientsApp());

    // Verify that the app launches and contains the expected elements
    expect(find.text('Digients App'), findsOneWidget);
  });
}