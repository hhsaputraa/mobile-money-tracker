import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/core/constants/app_constants.dart';
import 'package:moneytracker/dashboard/presentation/dashboard_screen.dart';

void main() {
  testWidgets('DashboardScreen renders welcome message and logout button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.textContaining('Selamat Datang'), findsOneWidget);
    expect(find.byIcon(Icons.logout_rounded), findsOneWidget);
  });

  testWidgets('Customer Dashboard renders savings balance card and toggle', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: DashboardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('TOTAL SALDO TABUNGAN'), findsOneWidget);
    expect(find.text('Riwayat Setoran Tabungan'), findsOneWidget);
    expect(find.text('Sembunyikan'), findsOneWidget);

    // Tap toggle hide/show balance
    await tester.tap(find.text('Sembunyikan'));
    await tester.pumpAndSettle();

    expect(find.text('Tampilkan'), findsOneWidget);
    expect(find.text('Rp •••••••••'), findsOneWidget);
  });
}
