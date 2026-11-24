// Mock tests for region-based currency, distance unit and mileage rate.
// A fake RegionDetector stands in for the phone's network/SIM country.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mileworth/main.dart';
import 'package:mileworth/screens/home_shell.dart';
import 'package:mileworth/services/region_detector.dart';
import 'package:mileworth/services/trip_tracker.dart';
import 'package:mileworth/state/app_state.dart';
import 'package:mileworth/utils/format.dart';
import 'package:mileworth/utils/regions.dart';

class FakeRegionDetector extends RegionDetector {
  FakeRegionDetector(this.country);
  String? country;
  @override
  Future<String?> detectCountry() async => country;
}

Map<String, dynamic> businessTrip(double miles) => {
      'startTime': DateTime.utc(2026, 11, 2, 9).toIso8601String(), // a Monday
      'endTime': DateTime.utc(2026, 11, 2, 10).toIso8601String(),
      'distance': miles,
      'category': 'business',
    };

Future<AppState> boot(String? country, [Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues({'onboarding_seen': true, ...prefs});
  final state = AppState(regionDetector: FakeRegionDetector(country));
  await state.bootstrap();
  return state;
}

void main() {
  group('region table', () {
    test('lookup is case-insensitive and rejects unknown codes', () {
      expect(regionFor('in')!.currency, 'INR');
      expect(regionFor(' gb ')!.unit, DistanceUnit.mi);
      expect(regionFor('XX'), isNull);
      expect(regionFor(null), isNull);
    });

    test('every region has a 3-letter currency and a sane rate', () {
      for (final r in allRegions) {
        expect(r.code.length, 2, reason: r.name);
        expect(r.currency.length, 3, reason: r.name);
        expect(r.rate, inInclusiveRange(0, 5), reason: r.name);
        if (r.hasOfficialRate) expect(r.rateSource, isNotNull, reason: r.name);
      }
    });

    test('mile/km conversion round-trips', () {
      expect(milesTo(DistanceUnit.km, 10), closeTo(16.09344, 1e-9));
      expect(toMiles(DistanceUnit.km, 16.09344), closeTo(10, 1e-9));
      expect(milesTo(DistanceUnit.mi, 10), 10);
    });
  });

  group('formatting', () {
    test('uses the right currency symbol', () {
      expect(formatMoney(6.7, 'USD'), r'$6.70');
      expect(formatMoney(6.7, 'INR'), '₹6.70');
      expect(formatMoney(6.7, 'GBP'), '£6.70');
      expect(formatMoney(6.7, 'EUR'), '€6.70');
    });

    test('shows stored miles in the chosen unit', () {
      expect(formatDistance(10, DistanceUnit.mi), '10.0 mi');
      expect(formatDistance(10, DistanceUnit.km), '16.1 km');
    });
  });

  group('auto-detection', () {
    test('India: INR, km, no official rate', () async {
      final s = await boot('IN');
      expect(s.user!.currency, 'INR');
      expect(s.user!.distanceUnit, DistanceUnit.km);
      expect(s.user!.mileageRate, 0);
      expect(s.user!.regionCountry, 'IN');
      expect(s.user!.regionAuto, isTrue);
    });

    test('US: USD, miles, IRS rate, deduction math', () async {
      final s = await boot('US');
      expect(s.user!.currency, 'USD');
      expect(s.user!.distanceUnit, DistanceUnit.mi);
      expect(s.user!.mileageRate, 0.725);
      await s.addTrip(businessTrip(10));
      expect(s.summary.totalDeductions, closeTo(7.25, 1e-9));
    });

    test('Canada: rate is per km, so stored miles are converted', () async {
      final s = await boot('CA');
      await s.addTrip(businessTrip(10)); // 16.09344 km × 0.73
      expect(s.summary.totalDeductions, closeTo(16.09344 * 0.73, 1e-9));
    });

    test('unknown country keeps the current settings', () async {
      final s = await boot('XX', {'currency': 'GBP', 'mileage_rate': 0.5});
      expect(s.user!.currency, 'GBP');
      expect(s.user!.mileageRate, 0.5);
    });

    test('no detection at all keeps the US defaults', () async {
      final s = await boot(null);
      expect(s.user!.currency, 'USD');
      expect(s.user!.mileageRate, 0.725);
    });

    test('a custom rate survives restarts in the same country', () async {
      final s = await boot('IN');
      await s.updateSettings(mileageRate: 12);
      await s.syncRegion(); // e.g. app resumed, still in India
      expect(s.user!.mileageRate, 12);
    });

    test('crossing a border switches currency, unit and rate', () async {
      final detector = FakeRegionDetector('IN');
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final s = AppState(regionDetector: detector);
      await s.bootstrap();
      await s.updateSettings(mileageRate: 12);
      await s.addTrip(businessTrip(10));

      detector.country = 'GB';
      await s.syncRegion();
      expect(s.user!.currency, 'GBP');
      expect(s.user!.distanceUnit, DistanceUnit.mi);
      expect(s.user!.mileageRate, 0.55);
      expect(s.summary.totalDeductions, closeTo(5.5, 1e-9));
    });

    test('a custom rate comes back after visiting another region', () async {
      final detector = FakeRegionDetector('IN');
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final s = AppState(regionDetector: detector);
      await s.bootstrap();
      await s.updateSettings(mileageRate: 10);

      await s.chooseRegion('GB');
      expect(s.user!.mileageRate, 0.55);
      await s.useAutomaticRegion(); // back to India
      expect(s.user!.currency, 'INR');
      expect(s.user!.mileageRate, 10);
    });

    test('a detection error is harmless', () async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final s = AppState(regionDetector: _ThrowingDetector());
      await s.bootstrap();
      expect(s.status, AppStatus.ready);
      expect(s.user!.currency, 'USD');
    });
  });

  group('manual choice', () {
    test('a chosen region is not overridden by detection', () async {
      final detector = FakeRegionDetector('IN');
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final s = AppState(regionDetector: detector);
      await s.bootstrap();

      await s.chooseRegion('AU');
      detector.country = 'US';
      await s.syncRegion();
      expect(s.user!.currency, 'AUD');
      expect(s.user!.regionAuto, isFalse);

      await s.useAutomaticRegion();
      expect(s.user!.currency, 'USD');
      expect(s.user!.regionAuto, isTrue);
    });
  });

  group('CSV report', () {
    test('uses the user unit and currency in headers and values', () async {
      final s = await boot('IN');
      await s.updateSettings(mileageRate: 10);
      await s.addTrip(businessTrip(10));
      final csv = String.fromCharCodes(await s.downloadReport(
        format: 'csv',
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 30),
      ));
      expect(csv, contains('Distance (km)'));
      expect(csv, contains('Amount/Deduction (INR)'));
      expect(csv, contains('16.09'));
      expect(csv, contains('160.93'));
    });
  });

  group('screens', () {
    Widget app(AppState state) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider(create: (_) => TripTracker()),
          ],
          child: const MileWorthApp(),
        );

    testWidgets('dashboard shows rupees and kilometres in India',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_seen': true});
      final s = AppState(regionDetector: FakeRegionDetector('IN'));
      await tester.pumpWidget(app(s));
      await tester.runAsync(() async {
        await s.bootstrap();
        await s.updateSettings(mileageRate: 10);
        await s.addTrip(businessTrip(10));
      });
      await tester.pumpAndSettle();
      expect(find.byType(HomeShell), findsOneWidget);
      expect(find.text('₹160.93'), findsOneWidget);
      expect(find.text('16.1 km'), findsOneWidget);
      expect(find.text('Kilometres tracked'), findsOneWidget);
    });
  });
}

class _ThrowingDetector extends RegionDetector {
  @override
  Future<String?> detectCountry() async => throw Exception('no telephony');
}
