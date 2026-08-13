import 'package:flutter_test/flutter_test.dart';
import 'package:mileworth/services/location_access.dart';

void main() {
  test('only granted counts as access', () {
    expect(LocationAccess.granted.isGranted, isTrue);
    for (final access in LocationAccess.values.where(
      (a) => a != LocationAccess.granted,
    )) {
      expect(access.isGranted, isFalse, reason: '$access must not pass');
    }
  });

  test('every failure state explains itself', () {
    for (final access in LocationAccess.values.where(
      (a) => a != LocationAccess.granted,
    )) {
      expect(access.message, isNotEmpty, reason: '$access needs a message');
    }
    expect(LocationAccess.granted.message, isEmpty);
  });

  test('unrecoverable states offer a way into settings', () {
    // These two cannot be resolved by prompting again — the user has to change
    // something in Settings — so they must carry an action button.
    expect(LocationAccess.deniedForever.actionLabel, isNotNull);
    expect(LocationAccess.backgroundDenied.actionLabel, isNotNull);
    expect(LocationAccess.serviceDisabled.actionLabel, isNotNull);
  });

  test('a plain denial offers no button, since retrying is the fix', () {
    expect(LocationAccess.denied.actionLabel, isNull);
    expect(LocationAccess.granted.actionLabel, isNull);
  });

  test('background denial is distinct from a flat denial', () {
    // Collapsing these was the original bug: "while using the app" is granted
    // for manual tracking but insufficient for auto-detection, and the two need
    // different advice.
    expect(
      LocationAccess.backgroundDenied.message,
      isNot(LocationAccess.denied.message),
    );
  });
}
