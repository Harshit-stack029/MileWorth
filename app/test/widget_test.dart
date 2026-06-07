// Smoke test: with no saved token the app renders the login screen.
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mileworth/main.dart';
import 'package:mileworth/state/app_state.dart';
import 'package:mileworth/screens/login_screen.dart';

void main() {
  testWidgets('Shows login when signed out', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(value: state, child: const MileWorthApp()),
    );
    await state.bootstrap();
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
