import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileworth/widgets/background_location_disclosure.dart';

void main() {
  test('Disclosure carries the wording Play policy requires', () {
    // Names the data, says it runs when the app is closed, names the feature.
    expect(kBackgroundLocationDisclosure, contains('location data'));
    expect(kBackgroundLocationDisclosure,
        contains('even when the app is closed or not in use'));
    expect(kBackgroundLocationDisclosure, contains('record your drives'));
  });

  testWidgets('Dialog returns true only when the user continues',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await showBackgroundLocationDisclosure(context),
          child: const Text('open'),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text(kBackgroundLocationDisclosure), findsOneWidget);
    await tester.tap(find.text('No thanks'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });
}
