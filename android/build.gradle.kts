buildscript {
    val kotlinVersion by extra("1.9.0") // ✅ Moved here where it’s guaranteed to work

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
    classpath("com.android.tools.build:gradle:8.3.0")
    classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlinVersion")
    classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    // ✅ Force correct Guava version to avoid InternalFutureFailureAccess error
    configurations.all {
        resolutionStrategy {
            force("com.google.guava:guava:31.1-jre")
        }
    }
}

rootProject.buildDir = File("../build")

subprojects {
    buildDir = File(rootProject.buildDir, name)
    evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.buildDir)
}
