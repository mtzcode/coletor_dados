// This is a basic Flutter widget test for the Coletor de Dados app.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:coletor_dados/main.dart';
import 'package:coletor_dados/providers/config_provider.dart';

void main() {
  testWidgets('App loads splash screen smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (context) => ConfigProvider(),
        child: const MyApp(),
      ),
    );

    // Verify that the splash screen loads with the app title.
    expect(find.text('Coletor de Dados'), findsOneWidget);
    
    // Verify that we have a CircularProgressIndicator (loading indicator).
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
