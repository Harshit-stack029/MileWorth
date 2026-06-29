// Smoke tests for the onboarding gate (no login — the app is local-only).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mileworth/main.dart';
import 'package:mileworth/state/app_state.dart';
import 'package:mileworth/services/trip_tracker.dart';
import 'package:mileworth/screens/home_shell.dart';
import 'package:mileworth/screens/onboarding_screen.dart';

void main() {
  Widget app(AppState state) => MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider(create: (_) => TripTracker()),
        ],
        child: const MileWorthApp(),
      );

  testWidgets('Opens straight into the app once onboarding is seen',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    final state = AppState();
    await tester.pumpWidget(app(state));
    await state.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('Shows onboarding on first launch', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(app(state));
    await state.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
