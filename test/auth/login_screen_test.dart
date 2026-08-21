import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/presentation/login_screen.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: LoginScreen(),
    );
  }

  testWidgets('Renders LoginScreen and validates empty inputs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Verify fields exist
    expect(find.text('Username atau Email'), findsAtLeastNWidgets(1));
    expect(find.text('Password'), findsAtLeastNWidgets(1));
    expect(find.widgetWithText(ElevatedButton, 'Masuk'), findsOneWidget);

    // Tap submit button without filling form
    final submitButton = find.widgetWithText(ElevatedButton, 'Masuk');
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Validation errors should show
    expect(find.text('Username atau email tidak boleh kosong'), findsOneWidget);
    expect(find.text('Password tidak boleh kosong'), findsOneWidget);
  });
}


