import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/core/constants/app_constants.dart';
import 'package:moneytracker/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders welcome message and logout button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.textContaining('Selamat Datang'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });
}

