import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// key.properties dosyasını oku
val keystorePropertiesFile = file("../key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    println("key.properties loaded from: ${keystorePropertiesFile.absolutePath}")
    println("Properties: ${keystoreProperties}")
}

android {
    namespace = "com.onbir.kavaid"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.onbir.kavaid"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 34
        versionCode = 2027
        versionName = "2.1.0"
        
        // Multidex desteği
        multiDexEnabled = true
        
        // Native kod optimizasyonu
        ndk {
            abiFilters.addAll(listOf("armeabi-v7a", "arm64-v8a", "x86_64"))
        }
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            // Release build için signing config
            val releaseSigningConfig = signingConfigs.findByName("release")
            signingConfig = if (releaseSigningConfig != null && releaseSigningConfig.storeFile?.exists() == true) {
                releaseSigningConfig
            } else {
                signingConfigs.getByName("debug")
            }
            
            // Performans optimizasyonları
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Daha iyi performans için optimizasyonlar
            isDebuggable = false
            isJniDebuggable = false
            isRenderscriptDebuggable = false
            
            // APK boyutunu küçültmek için
            resValue("string", "app_name", "Kavaid")
        }
        
        debug {
            // Debug için suffix kaldırıldı - google-services.json uyumu için
            // applicationIdSuffix = ".debug"
            isDebuggable = true
            resValue("string", "app_name", "Kavaid Debug")
        }
    }
    
    // Bundle optimizasyonları
    bundle {
        language {
            // Sadece kullanılan dilleri dahil et
            enableSplit = true
        }
        density {
            // Ekran yoğunluklarını optimize et
            enableSplit = true
        }
        abi {
            // ABI'leri optimize et
            enableSplit = true
        }
    }
    
    // Lint kontrollerini geçici olarak devre dışı bırak
    lint {
        abortOnError = false
        checkReleaseBuilds = false
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}

// Google Services plugin'i apply et
apply(plugin = "com.google.gms.google-services")
