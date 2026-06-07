import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/auto_trip_detector.dart';
import 'services/subscription_service.dart';
import 'services/trip_tracker.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  // Hold the native splash until the app has bootstrapped (see _AuthGate).
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..bootstrap()),
        ChangeNotifierProvider(create: (_) => TripTracker()),
        // Auto-detector orchestrates the tracker and saves finished drives.
        ChangeNotifierProxyProvider2<AppState, TripTracker, AutoTripDetector>(
          create: (ctx) => AutoTripDetector(
            ctx.read<TripTracker>(),
            onTripComplete: (payload) => ctx.read<AppState>().addTrip(payload),
          )..load(),
          update: (_, _, _, detector) => detector!,
        ),
        // Billing: verifies purchases through AppState -> backend.
        ChangeNotifierProxyProvider<AppState, SubscriptionService>(
          create: (ctx) => SubscriptionService(
            onVerify: (token, productId) => ctx.read<AppState>().verifySubscription(
                  purchaseToken: token,
                  productId: productId,
                ),
          )..init(),
          update: (_, _, service) => service!,
        ),
      ],
      child: const MileWorthApp(),
    ),
  );
}

class MileWorthApp extends StatelessWidget {
  const MileWorthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MileWorth',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const _AuthGate(),
    );
  }
}

/// Routes between login and the main app based on auth status.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final status = state.status;
    // Once auth is resolved, hand off from the native splash to the UI.
    if (status != AuthStatus.unknown) {
      WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
    }
    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        // First launch: show onboarding (incl. location priming) before login.
        return state.onboardingSeen ? const LoginScreen() : const OnboardingScreen();
      case AuthStatus.signedIn:
        return const HomeShell();
    }
  }
}
