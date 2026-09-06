// Imported rather than written as `java.util.Properties`: inside `android { }`
// the name `java` resolves to Gradle's own java extension, not the package, so
// the qualified form does not compile.
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "pk.humsukhan.humsukhan"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "pk.humsukhan.humsukhan"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // flutter_foreground_task with a typed microphone service and the
        // sherpa-onnx native libraries both need a modern floor.
        minSdk = maxOf(flutter.minSdkVersion, 24)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Release signing comes from android/key.properties when it exists, which
    // CI writes from secrets. Without it the release build falls back to the
    // debug key so `flutter run --release` still works locally, and the release
    // workflow fails loudly rather than shipping a debug-signed APK.
    signingConfigs {
        create("release") {
            val keystore = Properties()
            // Not named `file`: that would shadow Gradle's `file()` below, and
            // the store path has to stay relative to this project so
            // `../upload-keystore.jks` lands in android/ as the workflows write
            // it.
            val keystoreFile = rootProject.file("key.properties")
            if (keystoreFile.exists()) {
                keystoreFile.inputStream().use { keystore.load(it) }
                storeFile = keystore.getProperty("storeFile")?.let { file(it) }
                storePassword = keystore.getProperty("storePassword")
                keyAlias = keystore.getProperty("keyAlias")
                keyPassword = keystore.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (rootProject.file("key.properties").exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
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

flutter {
    source = "../.."
}
