import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/auth/presentation/onboarding_screen.dart';

void main() {
  Widget createWidgetUnderTest() {
    return const MaterialApp(
      home: OnboardingScreen(),
    );
  }

  testWidgets('Renders OnboardingScreen Step 1 and validates empty inputs', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Step 1 titles and fields
    expect(find.text('Lengkapi Data Diri'), findsOneWidget);
    expect(find.text('Tanggal Lahir'), findsOneWidget);
    expect(find.text('Alamat Tempat Tinggal'), findsOneWidget);
    expect(find.text('Selanjutnya'), findsOneWidget);

    // Tap next without filling
    final nextButton = find.text('Selanjutnya');
    await tester.tap(nextButton);
    await tester.pumpAndSettle();

    // Validation errors
    expect(find.text('Tanggal lahir wajib diisi'), findsOneWidget);
    expect(find.text('Alamat wajib diisi'), findsOneWidget);
  });
}
