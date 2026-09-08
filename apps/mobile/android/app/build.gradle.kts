import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Keystore config (reads from key.properties if present) ─────────────────────
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace     = "com.vyra.app"
    compileSdk    = flutter.compileSdkVersion
    ndkVersion    = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId  = "com.vyra.app"
        minSdk         = 26       // Health Connect requires API 26+
        targetSdk      = flutter.targetSdkVersion
        versionCode    = flutter.versionCode
        versionName    = flutter.versionName

        // Health Connect — declare intent so the OS shows the permission
        manifestPlaceholders["healthConnectPermissions"] = ""
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias       = keystoreProperties["keyAlias"] as String
                keyPassword    = keystoreProperties["keyPassword"] as String
                storeFile      = file(keystoreProperties["storeFile"] as String)
                storePassword  = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")   // demo build — debug key

            isMinifyEnabled   = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
            isDebuggable  = true
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
