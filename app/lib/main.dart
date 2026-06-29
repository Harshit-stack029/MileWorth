import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/auto_trip_detector.dart';
import 'services/trip_tracker.dart';
import 'state/app_state.dart';
import 'theme.dart';

void main() {
  // Hold the native splash until the app has bootstrapped (see _AppGate).
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
          // Once the app is ready, salvage any drive interrupted by an app kill.
          update: (_, appState, _, detector) {
            if (appState.status == AppStatus.ready) detector!.maybeRecover();
            return detector!;
          },
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
      home: const _AppGate(),
    );
  }
}

/// Shows first-run onboarding, then the main app. There is no login — the app
/// is local-only and always usable.
class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    // Once bootstrap is resolved, hand off from the native splash to the UI.
    if (state.status != AppStatus.unknown) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => FlutterNativeSplash.remove());
    }
    switch (state.status) {
      case AppStatus.unknown:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AppStatus.ready:
        // First launch: show onboarding (incl. location priming) before the app.
        return state.onboardingSeen
            ? const HomeShell()
            : const OnboardingScreen();
    }
  }
}
