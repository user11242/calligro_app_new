import com.android.build.gradle.internal.cxx.configure.gradleLocalProperties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.calligro_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    // New syntax to resolve deprecation warning
    kotlin {
        jvmToolchain(11)
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_11)
        }
    }

    defaultConfig {
        applicationId = "com.example.calligro_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // FIX: The error "cannot be reassigned" is solved by adding to the existing map.
        manifestPlaceholders["appAuthRedirectScheme"] = "com.example.calligro_app"
    }

    signingConfigs {
        create("release") {
            // Replace with your actual keystore path and credentials
            storeFile = file("path/to/your/release/keystore")
            storePassword = "your_store_password"
            keyAlias = "your_key_alias"
            keyPassword = "your_key_password"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    // Correctly adding the dependency for Google Identity Services SDK
    implementation("com.google.android.gms:play-services-auth:20.0.1")
}

flutter {
    source = "../.."
}
