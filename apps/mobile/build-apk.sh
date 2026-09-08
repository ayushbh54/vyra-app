#!/usr/bin/env bash
# ==============================================================================
# VYRA — 1-Click Release APK Build Script
# Connects directly to live Render backend
# ==============================================================================
set -e

RENDER_URL="https://vyra-api.onrender.com"

echo "===================================================="
echo " Building VYRA Release APK"
echo " Backend URL: $RENDER_URL"
echo "===================================================="

flutter pub get

echo "--> Compiling release APK..."
flutter build apk --release \
  --dart-define=VYRA_API_URL="$RENDER_URL"

echo ""
echo "===================================================="
echo "✅ BUILD COMPLETE!"
echo "APK Location: build/app/outputs/flutter-apk/app-release.apk"
echo "===================================================="
