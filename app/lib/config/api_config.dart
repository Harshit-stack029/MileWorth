/// Base URL of the MileWorth backend.
///
/// Override at run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
///
/// Defaults to the Android-emulator loopback alias (10.0.2.2 -> host machine).
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:4000',
  );
}
