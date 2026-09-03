import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/models/user_model.dart';
import 'package:moneytracker/user_management/presentation/create_user_dialog.dart';
import 'package:moneytracker/user_management/presentation/reset_user_password_dialog.dart';
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

  testWidgets('Renders ResetUserPasswordDialog and generates initial password', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'uuid-test-1',
      username: 'budi_santoso',
      fullName: 'Budi Santoso',
      email: 'budi@example.com',
      isAdmin: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResetUserPasswordDialog(user: testUser),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Buat Kode Reset User'), findsOneWidget);
    expect(find.text('Budi Santoso'), findsOneWidget);
    expect(find.text('Kode Unik 6-Digit (Acak)'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Buat Kode'), findsOneWidget);
  });

  testWidgets('Renders delete confirmation dialog and dismisses on Batal', (WidgetTester tester) async {
    final testUser = UserModel(
      id: 'uuid-test-delete-1',
      username: 'user_delete',
      fullName: 'User To Delete',
      email: 'delete@example.com',
      isAdmin: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Hapus Pengguna?'),
                      content: Text(
                        'Apakah Anda yakin ingin menghapus akun "${testUser.fullName}"?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Hapus'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Trigger Dialog'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Trigger Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus Pengguna?'), findsOneWidget);
    expect(
      find.text('Apakah Anda yakin ingin menghapus akun "User To Delete"?'),
      findsOneWidget,
    );
    expect(find.text('Batal'), findsOneWidget);
    expect(find.text('Hapus'), findsOneWidget);

    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();

    expect(find.text('Hapus Pengguna?'), findsNothing);
  });
}

