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
    project.evaluationDependsOn(":app")
}

fun Project.forceCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    android.javaClass.methods
        .firstOrNull { it.name == "setCompileSdk" && it.parameterCount == 1 }
        ?.invoke(android, 36)
}

subprojects {
    if (name == "app") return@subprojects
    afterEvaluate { forceCompileSdk36() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
