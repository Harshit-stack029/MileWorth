// Smoke tests for the auth/onboarding gate.
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mileworth/main.dart';
import 'package:mileworth/state/app_state.dart';
import 'package:mileworth/services/trip_tracker.dart';
import 'package:mileworth/screens/login_screen.dart';
import 'package:mileworth/screens/onboarding_screen.dart';

void main() {
  testWidgets('Shows login when signed out and onboarding already seen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    FlutterSecureStorage.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const MileWorthApp()),
    );
    await state.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('Shows onboarding on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider(create: (_) => TripTracker()),
        ],
        child: const MileWorthApp(),
      ),
    );
    await state.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
