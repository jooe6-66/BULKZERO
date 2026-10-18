import com.android.build.gradle.BaseExtension
import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    plugins.withId("com.android.library") {
        configure<LibraryExtension> {
            val pkg = (project.group as? String)?.takeIf { it.isNotEmpty() }
                ?: "dev.isar.${project.name.replace('-', '_')}"
            namespace = pkg
        }
    }

    val configureAndroid = {
        val android = project.extensions.findByName("android")
        if (android is BaseExtension) {
            android.compileSdkVersion(35)
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
