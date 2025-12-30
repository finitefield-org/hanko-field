plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.firebase-perf")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "org.finitefield.hanko"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "org.finitefield.hanko"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resValue("string", "app_name", "Hanko Field")
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    flavorDimensions += "env"

    productFlavors {
        create("dev") {
            dimension = "env"
            // NOTE: `google-services.json` currently only contains a client for
            // `org.finitefield.hanko`, so dev must use the same applicationId unless
            // we add a separate Firebase Android app (and google-services.json)
            // for `org.finitefield.hanko.dev`.
            //
            // Without this explicit override, a stale local config (e.g. an
            // `applicationIdSuffix` added during experimentation) can make the
            // Google Services plugin fail with:
            //   "No matching client found for package name 'org.finitefield.hanko.dev'".
            applicationId = "org.finitefield.hanko"
            resValue("string", "app_name", "Hanko Field Dev")
        }
        create("prod") {
            dimension = "env"
            applicationId = "org.finitefield.hanko"
            resValue("string", "app_name", "Hanko Field")
        }
    }
}

flutter {
    source = "../.."
}
