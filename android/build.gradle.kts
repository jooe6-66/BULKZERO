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
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.library") {
        configure<LibraryExtension> {
            if (namespace == null) {
                val pkg = (project.group as? String)?.takeIf { it.isNotEmpty() }
                    ?: "dev.isar.${project.name.replace('-', '_')}"
                namespace = pkg
            }
        }
    }
    if (project.name == "isar_flutter_libs") {
        project.afterEvaluate {
            configure<LibraryExtension> {
                compileSdk = 36
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
