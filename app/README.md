# MileWorth app

Flutter client for MileWorth. It is **local-only**: no login, no API calls.
Trips, expenses and preferences are stored on the device
(`lib/services/local_store.dart`) and every summary and report is computed
on-device.

## Run

```bash
flutter pub get
flutter run          # connected Android device or emulator
```

Requires Flutter 3.44 (stable), the same version CI uses. Route maps on the
trip-detail screen need a Google Maps API key (see `../docs/MAPS_SETUP.md`);
without one the map is hidden.

## Check

```bash
flutter analyze
flutter test
```

## Regenerate brand assets

```bash
dart run flutter_launcher_icons     # launcher icons from assets/brand/
dart run flutter_native_splash:create
```

Release builds and signing run in GitHub Actions; see the root `README.md`.
