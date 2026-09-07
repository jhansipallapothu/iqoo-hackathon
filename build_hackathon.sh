#!/bin/bash
# build_hackathon.sh - Build script for iQOO Hackathon 2026

set -e

echo "🏗️  Building AI For ALL for iQOO Hackathon 2026 - Chennai"
echo "============================================================="

# Check Flutter version
echo "📋 Flutter version:"
flutter --version

# Clean previous builds
echo "🧹 Cleaning..."
flutter clean

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Generate JSON serialization code
echo "🔧 Generating code..."
flutter pub run build_runner build --delete-conflicting-outputs

# Verify assets exist
echo "🔍 Verifying assets..."
if [ ! -f "assets/config/app_config.json" ]; then
    echo "❌ Missing assets/config/app_config.json"
    exit 1
fi

if [ ! -f "assets/config/prompts.json" ]; then
    echo "❌ Missing assets/config/prompts.json"
    exit 1
fi

if [ ! -f "assets/l10n/en.json" ]; then
    echo "❌ Missing assets/l10n/en.json"
    exit 1
fi

echo "✅ Assets verified"

# Build release APK for Android ARM64 (iQOO 15)
echo "🏗️  Building release APK (ARM64)..."
flutter build apk --release --target-platform android-arm64

# Also build app bundle for Play Store (optional)
echo "🏗️  Building app bundle..."
flutter build appbundle --release --target-platform android-arm64

# Output locations
APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
BUNDLE_PATH="build/app/outputs/bundle/release/app-release.aab"

echo ""
echo "✅ Build complete!"
echo ""
echo "📱 Release APK: $APK_PATH"
echo "📦 App Bundle:  $BUNDLE_PATH"
echo ""
echo "📏 APK size: $(du -h $APK_PATH | cut -f1)"
echo ""
echo "🚀 Next steps:"
echo "1. Copy APK to laptop for Office Kit transfer"
echo "2. Install Office Kit on laptop: https://pc.vivoglobal.com/"
echo "3. Connect iQOO 15 via USB-C or WiFi"
echo "4. Drag APK to Office Kit → Install on phone"
echo "5. Test all 4 modes + GPS + Offline"
echo ""
echo "🎯 Hackathon ready!"

# Verify APK can be installed
if command -v adb &> /dev/null; then
    echo ""
    echo "📲 ADB detected. To install directly:"
    echo "   adb install -r $APK_PATH"
fi