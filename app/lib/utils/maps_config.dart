/// Whether this build has a Google Maps API key.
///
/// The key itself lives in AndroidManifest (injected by build.gradle.kts), which
/// Dart cannot read, so CI passes `--dart-define=MAPS_ENABLED=true` alongside it.
/// Without a key the map widgets would render as blank grey boxes, so screens
/// hide them when this is false. Local runs: add
/// `--dart-define=MAPS_ENABLED=true` when key.properties holds a mapsApiKey.
const bool kMapsEnabled = bool.fromEnvironment('MAPS_ENABLED');
