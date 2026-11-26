import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.isFile) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}
val releaseKeyStore = keyProperties.getProperty("storeFile")
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
val debugKeyStore = android.signingConfigs.getByName("debug").storeFile

android {
    namespace = "com.ronalgaldamez.torogo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // DESUGARING: lo exige flutter_local_notifications (las notificaciones
        // del restaurante). Traduce APIs modernas de Java a Android viejos, y
        // SIN esto el plugin directamente no compila.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.ronalgaldamez.torogo"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = releaseKeyStore
            storePassword = keyProperties.getProperty("storePassword")
            keyAlias = keyProperties.getProperty("keyAlias")
            keyPassword = keyProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

val checkReleaseConfig by tasks.registering(Exec::class) {
    val localProperties = Properties().apply {
        rootProject.file("local.properties").inputStream().use { load(it) }
    }
    val flutterSdk = localProperties.getProperty("flutter.sdk")
    val dart = if (System.getProperty("os.name").startsWith("Windows")) "dart.exe" else "dart"
    commandLine(
        File(flutterSdk, "bin/cache/dart-sdk/bin/$dart"),
        rootProject.file("../tool/check_release_config.dart"),
    )
    environment("DART_DEFINES", providers.gradleProperty("dart-defines").getOrElse(""))
    doFirst {
        val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        if (required.any { keyProperties.getProperty(it).isNullOrBlank() } || releaseKeyStore?.isFile != true) {
            throw GradleException("Configurá android/key.properties con el almacén y las credenciales de firma de publicación.")
        }
        if (releaseKeyStore.canonicalFile == debugKeyStore?.canonicalFile) {
            throw GradleException("Elegí una clave de publicación distinta de la clave de depuración.")
        }
    }
}

tasks.matching { it.name == "preReleaseBuild" || it.name == "compileFlutterBuildRelease" }.configureEach {
    dependsOn(checkReleaseConfig)
}

flutter {
    source = "../.."
}

dependencies {
    // El paquete que hace posible el desugaring de arriba. La version la pide
    // flutter_local_notifications (ver su seccion "Gradle setup").
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
