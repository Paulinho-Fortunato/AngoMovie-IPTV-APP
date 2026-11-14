import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("org.jetbrains.kotlin.kapt")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load signing config
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.angomovie.angomovie_iptv"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // =========================================================================
    // CORREÇÃO CRÍTICA 1: Força o empacotamento tradicional de binários .so (C++)
    // Isso evita o erro de UnsatisfiedLinkError e destrava o VLC no Gradle 8.x+
    // =========================================================================
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keyProperties["keyAlias"] as String? ?: "release"
            keyPassword = keyProperties["keyPassword"] as String? ?: ""
            storeFile = keyProperties["storeFile"]?.let { file(it) }
            storePassword = keyProperties["storePassword"] as String? ?: ""
        }
    }

    defaultConfig {
        applicationId = "com.angomovie.angomovie_iptv"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        
        // CORREÇÃO CRÍTICA 2: Garante suporte mínimo ao VLC (Requer Android 5.0+)
        minSdk = 21 
        
        targetSdk = flutter.targetSdkVersion
        versionCode = 3
        versionName = "1.2.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
        debug {
            isMinifyEnabled = false
        }
    }

}

dependencies {
    // Room 2.6.x supports the existing Android 5+ baseline (including API 25).
    implementation("androidx.room:room-runtime:2.6.1")
    kapt("androidx.room:room-compiler:2.6.1")

    androidTestImplementation("androidx.test:runner:1.6.2")
    androidTestImplementation("androidx.test:core:1.6.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.room:room-testing:2.6.1")
}

kapt {
    correctErrorTypes = true
}

flutter {
    source = "../.."
}
