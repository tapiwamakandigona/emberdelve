import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Firebase Analytics config (consent-gated; see docs/telemetry-events.md).
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (NEVER committed; see docs/release.md
// for where the permanent upload keystore + passwords live and how CI injects
// them from GitHub Actions secrets).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.tsorostudios.emberdelve"
    // Play policy: target API 36 required by 2026-08-30 (Policy Centre issue,
    // warning recorded 2026-07-25). Pinned explicitly instead of Flutter 3.32's
    // default 35; compile and target move together.
    compileSdk = 36
    // Pinned above flutter.ndkVersion: firebase_core, path_provider_android
    // and shared_preferences_android all require r27, and Flutter's default is
    // older (build-time warning today, hard failure later).
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.tsorostudios.emberdelve"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Pinned to 24 deliberately, to state the real floor instead of inheriting it.
        //
        // 0.4.0 (24) shipped minSdk 21 (Flutter 3.32.7). The Play Billing 8 upgrade
        // needs in_app_purchase 3.3.0 -> Flutter >= 3.44, and Flutter's own embedding
        // manifest declares <uses-sdk android:minSdkVersion="24">, so the manifest
        // merger raises the app to 24 no matter what is written here. Setting 21 here
        // is silently ignored (verified: an AAB built with minSdk = 21 still reported
        // minSdkVersion 24). Billing itself is not the cause - both billing 8.0.0 and
        // 7.1.1 AARs declare minSdkVersion 21.
        //
        // Consequence, accepted in 0.4.1 (26): ~1,972 device models that 0.4.0
        // supported (API 21-23, Android 5.0-6.0) no longer get the app or updates.
        // The only alternative was staying on Billing 7, which Play rejects for
        // updates after 31 Aug 2026.
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    buildTypes {
        release {
            // Permanent upload key when key.properties exists (local dev or CI);
            // debug keys otherwise so `flutter run --release` still works.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
