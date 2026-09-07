@echo off
REM build_hackathon.bat - Build script for iQOO Hackathon 2026 (Windows)

echo 🏗️  Building AI For ALL for iQOO Hackathon 2026 - Chennai
echo =============================================================

REM Check Flutter version
echo 📋 Flutter version:
flutter --version

REM Clean previous builds
echo 🧹 Cleaning...
flutter clean

REM Get dependencies
echo 📦 Getting dependencies...
flutter pub get

REM Generate JSON serialization code
echo 🔧 Generating code...
flutter pub run build_runner build --delete-conflicting-outputs

REM Verify assets exist
echo 🔍 Verifying assets...
if not exist "assets\config\app_config.json" (
    echo ❌ Missing assets\config\app_config.json
    exit /b 1
)

if not exist "assets\config\prompts.json" (
    echo ❌ Missing assets\config\prompts.json
    exit /b 1
)

if not exist "assets\l10n\en.json" (
    echo ❌ Missing assets\l10n\en.json
    exit /b 1
)

echo ✅ Assets verified

REM Build release APK for Android ARM64 (iQOO 15)
echo 🏗️  Building release APK (ARM64)...
flutter build apk --release --target-platform android-arm64

REM Also build app bundle for Play Store (optional)
echo 🏗️  Building app bundle...
flutter build appbundle --release --target-platform android-arm64

REM Output locations
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
set BUNDLE_PATH=build\app\outputs\bundle\release\app-release.aab

echo.
echo ✅ Build complete!
echo.
echo 📱 Release APK: %APK_PATH%
echo 📦 App Bundle:  %BUNDLE_PATH%
echo.

REM Get APK size
for %%I in (%APK_PATH%) do set APK_SIZE=%%~zI
set /a APK_SIZE_MB=%APK_SIZE% / 1024 / 1024
echo 📏 APK size: %APK_SIZE_MB% MB
echo.

echo 🚀 Next steps:
echo 1. Copy APK to laptop for Office Kit transfer
echo 2. Install Office Kit on laptop: https://pc.vivoglobal.com/
echo 3. Connect iQOO 15 via USB-C or WiFi
echo 4. Drag APK to Office Kit → Install on phone
echo 5. Test all 4 modes + GPS + Offline
echo.
echo 🎯 Hackathon ready!

REM Verify APK can be installed
where adb >nul 2>nul
if %ERRORLEVEL% equ 0 (
    echo.
    echo 📲 ADB detected. To install directly:
    echo    adb install -r %APK_PATH%
)