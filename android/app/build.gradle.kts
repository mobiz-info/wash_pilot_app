plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mobiz.carwash"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        val rawCountry = (project.findProperty("selectedCountryName") as? String ?: "India")
        val countryLower = rawCountry.toLowerCase().replace(" ", "")
        applicationId = "com.mobiz.carwash.$countryLower"
        manifestPlaceholders["appName"] = "Car wash $rawCountry"
        
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

    applicationVariants.all {
        outputs.forEach { output ->
            val apkOutput = output as? com.android.build.gradle.internal.api.ApkVariantOutputImpl
            if (apkOutput != null) {
                val country = project.findProperty("selectedCountryName") as? String ?: "India"
                val version = versionName ?: "1.3.4"
                apkOutput.outputFileName = "Car wash $country V $version.apk"
            }
        }
    }
}

flutter {
    source = "../.."
}
