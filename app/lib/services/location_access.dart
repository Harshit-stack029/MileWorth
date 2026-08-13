import 'package:geolocator/geolocator.dart';

/// Why a location request succeeded or failed.
///
/// The tracker used to answer this with a plain `bool`, which collapsed four
/// very different situations — GPS switched off, "not now", "never ask again",
/// and "while using the app" when we need "always" — into one useless "no".
/// The UI could then only say "location permission needed", which is a dead end
/// for the one case the user cannot fix from the app: a permanent denial.
enum LocationAccess {
  /// Permission held. Tracking can start.
  granted,

  /// Device location services (GPS) are switched off system-wide.
  serviceDisabled,

  /// Declined this time, but the OS will ask again — retrying is meaningful.
  denied,

  /// Declined permanently ("Don't ask again"). Only Settings can undo it.
  deniedForever,

  /// Foreground permission held, but background auto-detection needs "Allow all
  /// the time". Android 11+ never grants this from a prompt — it must be chosen
  /// in Settings — so this is separate from [denied].
  backgroundDenied,
}

extension LocationAccessMessage on LocationAccess {
  bool get isGranted => this == LocationAccess.granted;

  /// Sentence to show the user. Empty when access was granted.
  String get message {
    switch (this) {
      case LocationAccess.granted:
        return '';
      case LocationAccess.serviceDisabled:
        return 'Location services are off. Turn on GPS to record drives.';
      case LocationAccess.denied:
        return 'MileWorth needs location access to record your drives.';
      case LocationAccess.deniedForever:
        return 'Location is blocked for MileWorth. Enable it in Settings to '
            'record drives.';
      case LocationAccess.backgroundDenied:
        return 'Auto-tracking needs "Allow all the time" location so drives are '
            'caught while the app is closed. Choose it in Settings.';
    }
  }

  /// Label for the recovery button, or null when there is nothing useful to
  /// offer (a plain [denied] just means "press Start again").
  String? get actionLabel {
    switch (this) {
      case LocationAccess.granted:
      case LocationAccess.denied:
        return null;
      case LocationAccess.serviceDisabled:
        return 'Turn on';
      case LocationAccess.deniedForever:
      case LocationAccess.backgroundDenied:
        return 'Open settings';
    }
  }
}

/// Location permission checks, kept out of the tracker so the same logic backs
/// manual tracking, background auto-detection, and the map's my-location dot.
class LocationAccessService {
  const LocationAccessService();

  /// Permission needed to record a drive while the app is open.
  Future<LocationAccess> requestForeground() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return _classify(permission, wantBackground: false);
  }

  /// Stricter permission for background auto-detection: requires "always".
  Future<LocationAccess> requestBackground() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    // Re-requesting prompts the upgrade from while-in-use to always on Android.
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.whileInUse) {
      permission = await Geolocator.requestPermission();
    }
    return _classify(permission, wantBackground: true);
  }

  /// Current state without prompting — used to decide whether the map may show
  /// the blue my-location dot, which throws if drawn without permission.
  Future<LocationAccess> check() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return LocationAccess.serviceDisabled;
    }
    return _classify(await Geolocator.checkPermission(), wantBackground: false);
  }

  static LocationAccess _classify(
    LocationPermission permission, {
    required bool wantBackground,
  }) {
    switch (permission) {
      case LocationPermission.always:
        return LocationAccess.granted;
      case LocationPermission.whileInUse:
        return wantBackground
            ? LocationAccess.backgroundDenied
            : LocationAccess.granted;
      case LocationPermission.deniedForever:
        return LocationAccess.deniedForever;
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return LocationAccess.denied;
    }
  }

  /// Send the user wherever they can actually fix [access].
  Future<void> openRecoverySettings(LocationAccess access) async {
    if (access == LocationAccess.serviceDisabled) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}
