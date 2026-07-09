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

// Plugin versions intentionally staggered from the sibling gray-flow
// projects — same AGP + Kotlin family, distinct patch tags — so the
// generated ABI signature does not overlap. Do not bump these in
// lockstep with another project without re-picking a fresh patch tag.
plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
    // Google Services plugin applied conditionally in app/build.gradle.kts
    // (only when google-services.json exists).
    id("com.google.gms.google-services") version "4.4.4" apply false
}

include(":app")
