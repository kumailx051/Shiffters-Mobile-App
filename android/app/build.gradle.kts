plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin") // Flutter plugin must come after Kotlin
}

android {
    namespace = "com.example.shiffters"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.shiffters"
        minSdk = 23 // ✅ Updated from flutter.minSdkVersion to 23
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ Fix for Guava-related crash (InternalFutureFailureAccess error)
configurations.all {
    resolutionStrategy {
        force("com.google.guava:guava:31.1-jre")
    }
}

dependencies {
    implementation(platform("org.jetbrains.kotlin:kotlin-bom:1.8.0"))
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:${rootProject.extra["kotlinVersion"]}")
    implementation("com.google.guava:guava:31.1-jre")
}
