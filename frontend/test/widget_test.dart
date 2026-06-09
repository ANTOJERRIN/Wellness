import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MedGenieApp());

    // Basic assertion
    expect(find.byType(MedGenieApp), findsOneWidget);
  });
}
