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
        targetSdk = 35
        versionCode = 2055
        versionName = "2.1.2"
        
        // Multidex desteği
        multiDexEnabled = true
        
        // 🚀 PERFORMANCE MOD: Native optimizasyonlar
        ndk {
            // Sadece gerekli ABI'ları ekle (daha küçük APK)
            abiFilters += listOf("armeabi-v7a", "arm64-v8a")
        }
        
        // 🚀 PERFORMANCE MOD: Render optimizasyonları
        renderscriptTargetApi = 19
        renderscriptSupportModeEnabled = true
        
        // 🚀 PERFORMANCE MOD: Vector drawable desteği
        vectorDrawables.useSupportLibrary = true
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
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
            
            // 🚀 PERFORMANCE MOD: Release optimizasyonları - Debug symbol stripping devre dışı
            // ndk {
            //     debugSymbolLevel = "NONE"
            // }
            
            // 🚀 PERFORMANCE MOD: Optimize edilmiş build flags
            packagingOptions {
                // Gereksiz dosyaları çıkar
                resources.excludes += listOf(
                    "META-INF/DEPENDENCIES",
                    "META-INF/LICENSE",
                    "META-INF/LICENSE.txt",
                    "META-INF/NOTICE",
                    "META-INF/NOTICE.txt"
                )
            }
            
            // APK boyutunu küçültmek için
            resValue("string", "app_name", "Kavaid")
        }
        
        debug {
            // Debug için suffix kaldırıldı - google-services.json uyumu için
            versionNameSuffix = "-debug"
            isDebuggable = true
            
            // 🚀 PERFORMANCE MOD: Debug'da da performans testleri için optimizasyonlar
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
            
            resValue("string", "app_name", "Kavaid Debug")
        }
        
        // 🚀 PERFORMANCE MOD: Mevcut profile build type'ını optimize et
        getByName("profile") {
            initWith(getByName("release"))
            versionNameSuffix = "-profile"
            // Profiling için debug bilgileri koru
            isDebuggable = false
            isProfileable = true
            
            // 🚀 PERFORMANCE MOD: Profile için özel optimizasyonlar
            ndk {
                debugSymbolLevel = "SYMBOL_TABLE"
            }
        }
    }
    

    
    // 🚀 PERFORMANCE MOD: Bundle optimizasyonları
    bundle {
        language {
            // Sadece gerekli dilleri ekle
            enableSplit = true
        }
        density {
            // Ekran yoğunluğu bazlı split
            enableSplit = true
        }
        abi {
            // ABI bazlı split
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

// 🚀 PERFORMANCE MOD: Build optimizasyonları
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile> {
    kotlinOptions {
        freeCompilerArgs += listOf(
            "-opt-in=kotlin.RequiresOptIn",
            "-Xjvm-default=all",
            "-Xlambdas=indy"
        )
    }
}
