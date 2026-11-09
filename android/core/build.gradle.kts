// Plain Kotlin/JVM: the image sources, with no Android dependency, so they can be
// unit-tested quickly anywhere (`./gradlew :core:test`).
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(libs.plugins.kotlin.serialization)
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

kotlin {
    compilerOptions { jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17) }
}

dependencies {
    api(libs.kotlinx.coroutines.core)
    implementation(libs.kotlinx.serialization.json)
    implementation(libs.okhttp)

    testImplementation(libs.kotlin.test)
    testImplementation(libs.junit)
}

// The curated galleries have one source of truth, shared with the desktop app
// (which generates it from the macOS sources).
tasks.processResources {
    from(rootProject.file("../desktop/src/main/galleries.json"))
}
