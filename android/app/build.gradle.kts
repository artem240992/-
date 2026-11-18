plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.exam_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.example.exam_app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        manifestPlaceholders = mutableMapOf(
            "YANDEX_CLIENT_ID" to "8df59a2c1ad74db893f9c290fd2d3e53"
        )
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
}

flutter {
    source = "../.."
}

// ВАЖНО: Добавьте зависимости для Flutter
dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlin_version")
    implementation(project(":flutter"))  // Эта строка ОБЯЗАТЕЛЬНА
}
