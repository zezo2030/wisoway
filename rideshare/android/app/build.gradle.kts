import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    val rawText = keystorePropertiesFile.readText(Charsets.UTF_8)
    val text = rawText.removePrefix("\uFEFF").trimStart()
    text.reader().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.abdelaziz.visionway"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.abdelaziz.visionway"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            val keyAlias = keystoreProperties.getProperty("keyAlias")
                ?: error("key.properties: missing keyAlias")
            val keyPassword = keystoreProperties.getProperty("keyPassword")
                ?: error("key.properties: missing keyPassword")
            val storePassword = keystoreProperties.getProperty("storePassword")
                ?: error("key.properties: missing storePassword")
            val storeFileProp = keystoreProperties.getProperty("storeFile")
                ?: error("key.properties: missing storeFile")
            create("release") {
                this.keyAlias = keyAlias
                this.keyPassword = keyPassword
                this.storePassword = storePassword
                storeFile = rootProject.file(storeFileProp)
                storeType = "pkcs12"
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (keystorePropertiesFile.exists()) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))
    implementation("com.google.firebase:firebase-messaging")
}

flutter {
    source = "../.."
}
