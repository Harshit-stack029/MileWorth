import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is configured via android/key.properties (kept out of git).
// The CI workflow materialises this file from secrets. When absent, the release
// build falls back to debug signing so `flutter run --release` works locally.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}
// True only when a real keystore is configured — not merely when the file
// exists. key.properties may hold only mapsApiKey (no signing creds), in which
// case release builds must still fall back to debug signing.
val hasReleaseKeystore = keystoreProperties["storeFile"] != null

android {
    // Internal namespace (R class / Kotlin package). Distinct from applicationId.
    namespace = "com.mileworth.mileworth"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Permanent published bundle ID (see requirements §1).
        applicationId = "com.mileworth.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Google Maps API key injected into AndroidManifest as ${MAPS_API_KEY}.
        // Sourced from the MAPS_API_KEY env var (CI) or mapsApiKey in the
        // gitignored key.properties (local). Defaults to empty so builds never
        // break when unset — the map tiles simply won't load. See
        // docs/MAPS_SETUP.md.
        manifestPlaceholders["MAPS_API_KEY"] =
            System.getenv("MAPS_API_KEY")
                ?: (keystoreProperties["mapsApiKey"] as String?)
                ?: ""
    }

    signingConfigs {
        create("release") {
            if (hasReleaseKeystore) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
