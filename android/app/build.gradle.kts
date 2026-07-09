import java.util.Properties
import java.io.FileInputStream

// ---------------------------------------------------------------
// Android app module — Joker Street
// ---------------------------------------------------------------
// Bundle id and namespace both fixed to `com.joker.jokerstreet` per
// the client brief. They must stay in lockstep with:
//   • lib/setup/app_mask.dart → AppMask.packageName / marketRef
//   • lib/carnival/web_scene.dart → MethodChannel('joker/media_pick')
//   • android/app/src/main/kotlin/com/joker/jokerstreet/MainActivity.kt
//   • android/app/google-services.json → package_name (once supplied)
// ---------------------------------------------------------------

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and
    // Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Apply the Google Services plugin only once google-services.json is
// present. This lets the project build before Firebase credentials are
// supplied (the portal falls back to the native game on Firebase-fail).
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

// Release signing config loaded from android/key.properties if present.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasKeystoreProperties = keystorePropertiesFile.exists()
if (hasKeystoreProperties) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.joker.jokerstreet"

    // Gray flow TZ §6 pins targetSdk = 35 and minSdk = 30. compileSdk
    // stays at 36 to keep every plugin in-range (see
    // gray_part_pitfalls.md §2). Do NOT drop back to `flutter.compileSdkVersion`
    // — some plugins pull compileSdk 36 and R8 will fail the release build.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications 18+ (java.time.*).
        // See .cursor/rules/gray_part_pitfalls.md §5.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.joker.jokerstreet"
        minSdk = 30
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystoreProperties) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real keystore when key.properties is present, otherwise
            // debug key so local `flutter run --release` still works.
            signingConfig = if (hasKeystoreProperties) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Minification/shrinking intentionally off for the first
            // release to remove R8 stripping risk during store review.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

dependencies {
    // Backport of java.time.* to API 26/28 for the local notifications
    // plugin. Version pinned to the same tag as gray_part_flow to keep
    // the ABI predictable (see gray_part_pitfalls.md §5).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
