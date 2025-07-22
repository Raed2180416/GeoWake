@echo off
echo ===============================================================
echo          Project Environment Version Report
echo ===============================================================
echo.

:: Display Gradle version (using the Gradle wrapper)
echo -- Gradle Version --
gradlew --version
echo.

:: Display Java (JDK) version
echo -- Java Version --
java -version
echo.

:: Display Android Gradle Plugin version by searching your android/build.gradle.kts file.
echo -- Android Gradle Plugin Version (from android/build.gradle.kts) --
for /f "delims=" %%i in ('findstr /i "com.android.tools.build:gradle:" "android/build.gradle.kts"') do echo %%i
echo.

:: Display Kotlin Gradle Plugin version from the buildscript block.
echo -- Kotlin Gradle Plugin Version (from android/build.gradle.kts) --
for /f "delims=" %%i in ('findstr /i "org.jetbrains.kotlin:kotlin-gradle-plugin:" "android/build.gradle.kts"') do echo %%i
echo.

:: List all repositories used by the project (optional – adjust the file path as needed)
echo -- Repositories Configured (from android/build.gradle.kts) --
for /f "delims=" %%i in ('findstr /i "repositories {" "android/build.gradle.kts"') do echo %%i
echo.

:: Display project dependencies for the app module.
echo -- App Module Dependencies --
gradlew app:dependencies
echo.

:: Run the dependency updates task if using the Ben Manes Versions plugin.
echo -- Checking for Dependency Updates --
gradlew dependencyUpdates
echo.

pause
