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

    // ---------------------------------------------------------------
    // Force every Android *library* subproject to compile against the
    // same compileSdk our app uses (36+). Some plugins still ship with
    // compileSdk 34 baked in, but their transitive AndroidX deps require
    // 36 → Gradle aborts with `CheckAarMetadata` unless we override.
    // See .cursor/rules/gray_part_pitfalls.md §2.
    //
    // MUST be registered BEFORE the evaluationDependsOn(":app") block
    // below — otherwise the target projects have already been evaluated
    // and Gradle refuses to attach afterEvaluate callbacks (§7).
    // ---------------------------------------------------------------
    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
