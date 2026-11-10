import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/app/router.dart';
import 'package:frontend/features/auth/providers/auth_provider.dart';
import 'package:frontend/features/care/data/care_api.dart';
import 'package:frontend/features/care/presentation/care_dashboard_screen.dart';

class SignedInPatient extends AuthNotifier {
  @override
  AuthState build() => AuthState(isAuthenticated: true, userName: 'Patient');
}

void main() {
  testWidgets(
    'Patient review shows sample data and opens a sample consultation',
    (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: CareDashboardScreen(previewRole: 'user')),
        ),
      );
      expect(find.text('Patient dashboard'), findsOneWidget);
      expect(find.text('Review preview · Sample data'), findsOneWidget);
      expect(find.text('Health profile'), findsWidgets);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Dr. Alex (sample)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dr. Alex (sample)'));
      await tester.pumpAndSettle();
      expect(
        find.text('Sample conversation · Read-only review preview'),
        findsOneWidget,
      );
      expect(find.textContaining('Thank you for your request'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('Doctor review is accessible without login', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/review/doctor',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Doctor dashboard'), findsOneWidget);
    expect(find.text('New requests'), findsOneWidget);
    expect(find.text('Patient consultations'), findsOneWidget);
    expect(find.text('Request consultation'), findsNothing);
  });

  testWidgets('Live dashboard uses real summary and explains unavailable AI', (
    tester,
  ) async {
    final summary = <String, dynamic>{
      'role': 'user',
      'name': 'Real Patient',
      'activeConsultations': 0,
      'profileFieldsCompleted': 0,
      'chatSessions': 0,
      'consultations': <Map<String, dynamic>>[],
      'ai': {'configured': false},
    };
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(SignedInPatient.new),
          careDashboardProvider.overrideWith((ref) async => summary),
        ],
        child: const MaterialApp(home: CareDashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome, Real Patient'), findsOneWidget);
    expect(
      find.textContaining('provider has not been configured'),
      findsOneWidget,
    );
    expect(find.textContaining('No consultations yet'), findsOneWidget);
    expect(find.text('Review preview · Sample data'), findsNothing);
  });

  testWidgets('Private dashboard requires sign in', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CareDashboardScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Patient dashboard'), findsNothing);
  });
}
