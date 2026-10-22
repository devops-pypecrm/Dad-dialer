plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.pypecrm.dialer"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.pypecrm.dialer"
        // RoleManager.ROLE_DIALER (the actual mechanism this whole app is
        // built around) is API 29+ only — see DefaultDialerRoleManager's
        // UnsupportedSdk case. No pre-29 ACTION_CHANGE_DEFAULT_DIALER
        // fallback is implemented in Phase 1 (prompt.md §3: "modern Android
        // versions"), so pin minSdk here rather than trusting whatever
        // Flutter's own template default happens to be.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add a real release signing config before shipping to Play.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
            // Flutter's Gradle plugin defaults release builds to R8
            // minify+shrink unless overridden here. With no
            // proguard-rules.pro / Room-Work Manager keep rules in this
            // project, that stripped/renamed the class WorkManager's Room
            // database needs via reflection, crashing the app at process
            // start with "Failed to create an instance of class
            // androidx.work.impl.WorkDatabase" -- before MainActivity or
            // any app code ever runs. Disabled for now so the app is
            // actually testable; re-enable with proper Room/WorkManager
            // keep rules in proguard-rules.pro before a real Play
            // submission build.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    // Native-side CRM sync (DialerSyncWorker/BackendApi) — same choice as
    // Dad-call-recorder's packages/call_recording_engine.
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    implementation("androidx.work:work-runtime-ktx:2.9.1")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

flutter {
    source = "../.."
}
