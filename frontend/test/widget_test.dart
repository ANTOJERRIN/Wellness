import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/wellness_app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const WellnessApp());

    // Basic assertion
    expect(find.byType(WellnessApp), findsOneWidget);
  });
}
