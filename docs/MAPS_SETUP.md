# Google Maps setup

MileWorth records each drive's GPS route, stores it as an encoded polyline
(`Trip.routePolyline`), and renders it on a map on the **Trip detail** screen
via the `google_maps_flutter` plugin.

The map needs a Google Maps API key. Builds succeed **without** one — the route
and markers just won't render (you'll see grey tiles / a blank map). Wire a key
before shipping.

## 1. Create the key

1. In the [Google Cloud console](https://console.cloud.google.com/), create (or
   reuse) a project and enable **Maps SDK for Android** and **Maps SDK for iOS**.
2. Create an API key under **APIs & Services → Credentials**.
3. Restrict it: lock the Android key to the app's package name
   (`com.mileworth.app`) + signing-cert SHA-1, and the iOS key to the bundle ID.

## 2. Android

The manifest reads the key from the `MAPS_API_KEY` manifest placeholder
(`android/app/build.gradle.kts` → `AndroidManifest.xml`). Provide it either way:

- **Local:** add a line to the gitignored `android/key.properties`:

  ```properties
  mapsApiKey=AIza...your-key...
  ```

- **CI / shell:** export an env var (takes precedence over `key.properties`):

  ```sh
  export MAPS_API_KEY=AIza...your-key...
  ```

Never commit the key — `key.properties` is already gitignored.

## 3. iOS

`AppDelegate.swift` calls `GMSServices.provideAPIKey(...)` with the value of the
`MapsApiKey` Info.plist entry, which is backed by the `MAPS_API_KEY` build
setting. Supply it via an xcconfig (do **not** hardcode it in `Info.plist`):

```
// ios/Flutter/Maps.xcconfig (gitignored), included from Debug/Release.xcconfig
MAPS_API_KEY = AIza...your-key...
```

Then run `cd ios && pod install` so the GoogleMaps pod is fetched.

## Notes

- The detail map uses **lite mode** (a static, non-interactive snapshot) — it's
  cheaper and avoids per-interaction map loads.
- Routes are downsampled to ≤1000 points before encoding to keep the stored
  polyline bounded on long drives.
