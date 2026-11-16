// Этот блок указывает Gradle, где искать библиотеки для ВСЕХ модулей проекта.
allprojects {
    repositories {
        google()       // Репозиторий Google (для Android SDK и библиотек поддержки)
        mavenCentral() // Центральный репозиторий Maven (отсюда качается большинство зависимостей, включая RuStore Pay SDK)
        // Для RuStore Pay дополнительные URL здесь не нужны!
    }
}

// Настройка пути для сохранения временных файлов сборки (build)
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

// Применяем эту же папку build для всех подпроектов (включая плагины вроде file_picker и flutter_rustore_pay)
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Указывает Gradle, что сначала нужно настроить основной модуль 'app', а потом плагины
subprojects {
    project.evaluationDependsOn(":app")
}

// Стандартная задача очистки проекта (команда flutter clean вызывает её)
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}