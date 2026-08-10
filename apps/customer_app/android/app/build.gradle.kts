plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // FCM (NOTIFY-1 Stage 2). Consumes app/google-services.json, which is
    // gitignored and supplied per environment.
    id("com.google.gms.google-services")
}

android {
    namespace = "app.sahra.sahra_customer_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // `app.sahra.customer`, matching the Android app registered in Firebase
        // project `sahra-4881d` and the id named in the handover doc.
        //
        // IT HAD TO CHANGE, AND THIS WAS THE LAST FREE MOMENT TO DO IT. The
        // value here was `app.sahra.sahra_customer_app` — the Flutter scaffold
        // default, with the "specify your own unique Application ID" TODO still
        // beside it. `google-services.json` names `app.sahra.customer`, and the
        // Google Services Gradle plugin fails the build outright on a mismatch:
        // "No matching client found for package name".
        //
        // An applicationId can NEVER change once an app is on the Play Store —
        // it is the store identity, and a new one is a new listing with no
        // reviews and no installs. Nothing is published, so this is free today
        // and impossible later.
        //
        // `namespace` above stays `app.sahra.sahra_customer_app` deliberately.
        // It is the R-class/BuildConfig package, it must match the Kotlin source
        // directory, and it is invisible to Firebase, the Play Store and users.
        // Renaming it too would mean moving MainActivity.kt for no benefit.
        applicationId = "app.sahra.customer"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
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
