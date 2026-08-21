import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/user_management/presentation/create_user_dialog.dart';
import 'package:moneytracker/user_management/presentation/user_management_screen.dart';

void main() {
  testWidgets('Renders UserManagementScreen with search and FAB', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: UserManagementScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kelola Pengguna'), findsOneWidget);
    expect(find.text('Tambah User'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Renders CreateUserDialog and validates empty input', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CreateUserDialog(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tambah Pengguna'), findsOneWidget);
    expect(find.text('Nama Lengkap'), findsOneWidget);
    expect(find.text('Email atau Username Awal'), findsOneWidget);
    expect(find.text('Password Awal'), findsOneWidget);

    final submitButton = find.widgetWithText(ElevatedButton, 'Buat Pengguna');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Nama lengkap wajib diisi'), findsOneWidget);
    expect(find.text('Email/Username wajib diisi'), findsOneWidget);
  });
}
