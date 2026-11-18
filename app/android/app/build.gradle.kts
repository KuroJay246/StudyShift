plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeyPath = providers.environmentVariable("SHIFT_STUDY_KEYSTORE").orNull
val releaseStorePassword = providers.environmentVariable("SHIFT_STUDY_KEYSTORE_PASSWORD").orNull
val releaseKeyAlias = providers.environmentVariable("SHIFT_STUDY_KEY_ALIAS").orNull
val releaseKeyPassword = providers.environmentVariable("SHIFT_STUDY_KEY_PASSWORD").orNull
val releaseSigningValues = listOf(releaseKeyPath, releaseStorePassword, releaseKeyAlias, releaseKeyPassword)
val releaseSigningConfigured = releaseSigningValues.all { !it.isNullOrBlank() }
val projectSourceRoot = rootProject.projectDir.parentFile.parentFile.canonicalFile
val releaseKeyFile = releaseKeyPath?.takeIf { it.isNotBlank() }?.let { file(it).canonicalFile }
require(releaseSigningValues.all { it.isNullOrBlank() } || releaseSigningConfigured) {
    "Private release signing requires all SHIFT_STUDY_KEYSTORE and SHIFT_STUDY_*_PASSWORD/ALIAS environment variables."
}

android {
    namespace = "app.shiftstudy.mobile"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    signingConfigs {
        // Keep debug APK updates stable across the project-local toolchain and
        // avoid depending on the machine-wide Android debug key.
        getByName("debug") {
            storeFile = file("${projectSourceRoot.path}/.devtools/android-user/debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
        if (releaseSigningConfigured) {
            create("privateRelease") {
                storeFile = file(releaseKeyPath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.shiftstudy.mobile"
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The personal flavor keeps the stable install ID; review flavors remain
    // side-by-side packages for screenshots and QA.
    flavorDimensions += "qa"
    productFlavors {
        create("personal") {
            dimension = "qa"
        }
        create("review") {
            dimension = "qa"
            applicationIdSuffix = ".review"
            versionNameSuffix = "-review"
        }
        create("visualReview") {
            dimension = "qa"
            applicationIdSuffix = ".visualreview"
            versionNameSuffix = "-visual-review"
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            signingConfig = if (releaseSigningConfigured) signingConfigs.getByName("privateRelease") else null
        }
    }
}

fun verifyPrivateReleaseSigningConfiguration() {
    check(releaseSigningConfigured) {
        "Private release signing is not configured. Set SHIFT_STUDY_KEYSTORE, SHIFT_STUDY_KEYSTORE_PASSWORD, SHIFT_STUDY_KEY_ALIAS, and SHIFT_STUDY_KEY_PASSWORD before building a release."
    }
    val keystore = checkNotNull(releaseKeyFile)
    check(!keystore.toPath().startsWith(projectSourceRoot.toPath())) {
        "Keep the private release keystore outside the project repository."
    }
}

// Fail before release dependencies run, including in dry-run guard checks.
gradle.taskGraph.whenReady {
    val hasReleasePackagingTask = allTasks.any { task ->
        task.name.contains("Release", ignoreCase = true) &&
            (task.name.startsWith("package") ||
                task.name.startsWith("bundle") ||
                task.name.startsWith("sign"))
    }
    if (hasReleasePackagingTask) verifyPrivateReleaseSigningConfiguration()
}

val verifyPersonalReleaseManifest = tasks.register<org.gradle.api.tasks.Exec>(
    "verifyPersonalReleaseManifest",
) {
    group = "verification"
    description = "Checks the merged personal-release manifest against the security allowlist."

    val mergedManifest = layout.buildDirectory.file(
        "intermediates/merged_manifest/personalRelease/processPersonalReleaseMainManifest/AndroidManifest.xml",
    )
    dependsOn("processPersonalReleaseMainManifest")
    commandLine(
        "powershell.exe",
        "-NoProfile",
        "-ExecutionPolicy",
        "Bypass",
        "-File",
        file("../../tool/verify_merged_release_manifest.ps1").absolutePath,
        "-ManifestPath",
        mergedManifest.get().asFile.absolutePath,
    )
}

tasks.configureEach {
    if (name.equals("packagePersonalRelease", ignoreCase = true) ||
        name.equals("bundlePersonalRelease", ignoreCase = true)
    ) {
        dependsOn(verifyPersonalReleaseManifest)
    }
}

tasks.configureEach {
    if (
        name.contains("Release", ignoreCase = true) &&
            (name.startsWith("package") ||
                name.startsWith("bundle") ||
                name.startsWith("sign"))
    ) {
        doFirst {
            verifyPrivateReleaseSigningConfiguration()
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Bundled Latin OCR model keeps selected schedules on-device and usable offline.
    implementation("com.google.mlkit:text-recognition:16.0.1")
    testImplementation("junit:junit:4.13.2")
}

flutter {
    source = "../.."
}
