import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/presentation/reset_password_screen.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: ResetPasswordScreen(),
    );
  }

  testWidgets('Renders ResetPasswordScreen and validates empty inputs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify header and fields exist
    expect(find.text('ATUR PASSWORD BARU'), findsOneWidget);
    expect(find.text('Password Baru'), findsOneWidget);
    expect(find.text('Konfirmasi Password Baru'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Simpan & Lanjutkan'), findsOneWidget);

    // Tap submit button without filling form
    final submitButton = find.widgetWithText(ElevatedButton, 'Simpan & Lanjutkan');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Validation errors should show
    expect(find.text('Password baru wajib diisi'), findsOneWidget);
    expect(find.text('Konfirmasi password wajib diisi'), findsOneWidget);
  });
}
