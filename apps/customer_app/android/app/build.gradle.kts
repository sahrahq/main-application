import java.util.Properties

// ── RELEASE SIGNING, READ FROM A FILE THAT IS NEVER COMMITTED ─────────────
//
// `key.properties` sits beside this file and is gitignored (android/.gitignore
// line 12, verified with `git check-ignore -v`, not by reading the pattern).
// It names an ABSOLUTE path to a keystore that lives OUTSIDE the repository
// entirely, and holds the two passwords. Neither the keystore nor the
// passwords are ever written into a committed file, a log or an error message.
//
// ABSENT IS A FIRST-CLASS CASE. CI has no keystore, and neither does a
// contributor running `flutter run --release` to check a build. Those fall
// back to debug signing and must keep working — so this is a null, not a
// throw. What must NOT happen is a release built with debug keys being
// mistaken for a shippable one, and that is `signing_config_test.dart`'s job:
// it treats MISSING, EMPTY and MALFORMED identically as unsigned.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    // `f.length() > 0` on purpose: an empty file parses to zero properties and
    // would otherwise look like a valid-but-blank config, which is exactly how
    // a release gets debug-signed while every step reports success.
    if (f.exists() && f.length() > 0) f.inputStream().use { load(it) }
}

val hasReleaseSigning: Boolean = listOf("storeFile", "storePassword", "keyPassword", "keyAlias")
    .all { !keystoreProperties.getProperty(it).isNullOrBlank() } &&
    file(keystoreProperties.getProperty("storeFile") ?: "").exists()

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

    signingConfigs {
        // Declared only when the file is present AND complete AND the keystore
        // it names actually exists on disk. A half-filled `key.properties`
        // would otherwise produce a config that fails deep inside the signing
        // task with a message about a password, long after it looked fine.
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Debug keys are the FALLBACK, and the fallback is loud: the
            // warning below is printed at configuration time, and
            // `signing_config_test.dart` fails a build that produces a
            // debug-signed release artefact. An unsignable release that builds
            // successfully is the "looks fine, cannot ship" shape.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "SAHRA: no usable android/key.properties — the release build will be " +
                        "signed with DEBUG KEYS and cannot be uploaded to Play. " +
                        "Expected storeFile/storePassword/keyPassword/keyAlias, and the " +
                        "keystore file to exist at the path given."
                )
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
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
