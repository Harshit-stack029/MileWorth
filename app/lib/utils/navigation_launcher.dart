import 'dart:io' show Platform;

import 'package:url_launcher/url_launcher.dart';

/// Builds the deep links that hand a destination to the phone's maps app.
///
/// MileWorth does not navigate on its own — doing that in-app would need a paid
/// Directions API and would send every route to a server. Instead we pass the
/// destination to the maps app the user already has, which does turn-by-turn
/// properly (traffic, voice, rerouting) for free.
///
/// Split out from [launchDirections] so the URL construction is unit-testable
/// without a platform channel.
class DirectionsLinks {
  /// Android: the `google.navigation:` scheme starts turn-by-turn immediately
  /// in Google Maps, which is what "navigate" should do.
  static Uri androidNavigation(double lat, double lng) =>
      Uri.parse('google.navigation:q=$lat,$lng&mode=d');

  /// iOS: Apple Maps is guaranteed to be present, so it is the safe default.
  /// `dirflg=d` selects driving directions.
  static Uri appleMaps(double lat, double lng) =>
      Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&dirflg=d');

  /// Cross-platform fallback. Opens the Google Maps app when installed and the
  /// browser otherwise, so this works even where the scheme above is unhandled.
  static Uri universal(double lat, double lng) => Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=$lat,$lng&travelmode=driving',
      );

  /// Links to try, most specific first, for the current platform.
  static List<Uri> candidates(double lat, double lng) {
    if (Platform.isAndroid) {
      return [androidNavigation(lat, lng), universal(lat, lng)];
    }
    if (Platform.isIOS) {
      return [appleMaps(lat, lng), universal(lat, lng)];
    }
    return [universal(lat, lng)];
  }
}

/// Opens turn-by-turn directions to (lat, lng) in the phone's maps app.
///
/// Returns false if no app could handle any of the candidate links, so the
/// caller can tell the user instead of appearing to do nothing.
Future<bool> launchDirections(double lat, double lng) async {
  for (final uri in DirectionsLinks.candidates(lat, lng)) {
    try {
      // canLaunchUrl can report false for a perfectly launchable scheme when the
      // Android <queries> manifest entry is missing, so we attempt the launch
      // and treat a throw as "not handled" rather than trusting the check alone.
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } catch (_) {
      // Try the next candidate.
    }
  }
  return false;
}
