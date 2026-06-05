// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:link_saver/main.dart';
import 'package:link_saver/providers/link_provider.dart';

void main() {
  testWidgets('App builds and shows home screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => LinkProvider(),
        child: const LinkSaverApp(),
      ),
    );

    // Verify that the app title is shown.
    expect(find.text('Link Saver'), findsOneWidget);

    // Verify that the empty state message is shown when no links are saved.
    expect(find.text('No links saved yet'), findsOneWidget);
  });
}
