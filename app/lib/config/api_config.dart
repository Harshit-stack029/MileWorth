/// Base URL of the MileWorth backend.
///
/// Override at run time with:
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:4000
///
/// Defaults to the live Render deployment so a fresh install works on a real
/// device with no manual server configuration. A user can still point the app
/// at a local backend from the login screen's "Server" field.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mileworth-api.onrender.com',
  );
}
