pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
    // Reads app/google-services.json and generates the Firebase config the FCM
    // SDK reads at runtime. Without it `Firebase.initializeApp()` throws on
    // Android and no handset ever gets a token.
    //
    // It also FAILS THE BUILD when the applicationId does not match a client in
    // that file, which is how the scaffold's `app.sahra.sahra_customer_app` was
    // caught against the registered `app.sahra.customer`.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
