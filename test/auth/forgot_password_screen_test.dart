import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/presentation/forgot_password_screen.dart';

void main() {
  testWidgets('Renders ForgotPasswordScreen Stage 1 with unique code input only',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForgotPasswordScreen(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lupa Password?'), findsOneWidget);
    expect(find.text('Kode Unik dari Admin'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verifikasi Kode'), findsOneWidget);

    // Form password baru tidak boleh muncul di awal
    expect(find.text('Password Baru'), findsNothing);
    expect(find.text('Konfirmasi Password Baru'), findsNothing);
  });

  testWidgets('Validates empty or invalid unique code on submit in Stage 1',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ForgotPasswordScreen(),
      ),
    );
    await tester.pumpAndSettle();

    final verifyBtn = find.widgetWithText(ElevatedButton, 'Verifikasi Kode');
    await tester.ensureVisible(verifyBtn);
    await tester.tap(verifyBtn);
    await tester.pumpAndSettle();

    expect(find.text('Kode unik wajib diisi'), findsOneWidget);

    // Ketik kode yang terlalu pendek
    await tester.enterText(
      find.byType(TextFormField),
      'AB',
    );
    await tester.tap(verifyBtn);
    await tester.pumpAndSettle();

    expect(find.text('Kode unik tidak valid'), findsOneWidget);

    // Password fields tetap tidak muncul jika kode belum lolos
    expect(find.text('Password Baru'), findsNothing);
  });
}
