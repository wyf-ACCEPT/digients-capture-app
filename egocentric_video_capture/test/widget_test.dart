// This is a basic Flutter widget test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:egocentric_video_capture/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EgocentricVideoCaptureApp());

    // Verify that the app launches and contains the expected elements
    expect(find.text('Egocentric Video Capture'), findsOneWidget);
  });
}