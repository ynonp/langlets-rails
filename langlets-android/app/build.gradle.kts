import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // Bridge message payloads are decoded with KotlinXJsonConverter, which needs
    // @Serializable data classes.
    id("org.jetbrains.kotlin.plugin.serialization")
}

android {
    namespace = "com.ynonp.langlets"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.ynonp.langlets"
        // Hotwire Native Android requires 28+. Nothing here needs to go lower.
        minSdk = 28
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }

        getByName("debug") {
            isDebuggable = true
        }
    }

    buildFeatures {
        viewBinding = true
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        named("main") { java { srcDirs("src/main/java") } }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

dependencies {
    implementation("dev.hotwire:core:1.3.1")
    implementation("dev.hotwire:navigation-fragments:1.3.1")

    implementation("com.google.android.material:material:1.12.0")
    implementation("androidx.constraintlayout:constraintlayout:2.2.1")
    implementation("androidx.core:core-ktx:1.15.0")
    implementation("androidx.browser:browser:1.8.0")

    // Sign in with Google. Credential Manager is the API Google supports on
    // Android; `credentials-play-services-auth` is the provider that actually
    // serves Google accounts, and `googleid` parses the returned credential.
    implementation("androidx.credentials:credentials:1.3.0")
    implementation("androidx.credentials:credentials-play-services-auth:1.3.0")
    implementation("com.google.android.libraries.identity.googleid:googleid:1.1.1")

    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.8.1")
}

java {
    // 21, not 17, because that is the JDK Android Studio ships (its bundled JBR)
    // and therefore the one already on a developer's machine. The compiler still
    // targets 17 bytecode via `compileOptions` above, which is what the Android
    // toolchain expects; the toolchain version only decides which javac runs.
    //
    // Pinning this rather than inheriting the Gradle JVM keeps a machine with a
    // newer default JDK from producing class files D8 refuses. settings.gradle.kts
    // adds the foojay resolver so a machine without a 21 gets one provisioned
    // instead of failing.
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}
