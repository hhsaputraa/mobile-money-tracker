import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracker/main.dart';

void main() {
  testWidgets('App renders Mobile LoginScreen smoke test', (
    WidgetTester tester,
  ) async {
    // Build app and trigger frame.
    await tester.pumpWidget(const MoneyTrackerApp());
    await tester.pumpAndSettle();

    // Verify that Login Screen elements are rendered cleanly.
    expect(find.text('ARUS KAS'), findsAtLeastNWidgets(1));
    expect(find.textContaining('Money Tracker'), findsOneWidget);
    expect(find.text('Masuk'), findsAtLeastNWidgets(1));
  });
}


