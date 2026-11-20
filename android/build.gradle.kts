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

// AGP 8+ requires every Android library module (e.g. legacy `soundpool`) to declare a namespace.
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android")
        if (androidExt != null) {
            val getNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val setNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            }
            if (getNamespace != null && setNamespace != null && getNamespace.invoke(androidExt) == null) {
                val fallback = project.group.toString().ifBlank { "com.stradio.plugin.${project.name}" }
                setNamespace.invoke(androidExt, fallback)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
