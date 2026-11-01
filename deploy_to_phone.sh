#!/usr/bin/env bash
set -e

ADB="$HOME/Library/Android/sdk/platform-tools/adb"
APK_PATH="$(cd "$(dirname "$0")" && pwd)/build/app/outputs/flutter-apk/app-debug.apk"

echo "📱 Checking for connected Android device..."
if ! "$ADB" devices | grep -q -E "[a-zA-Z0-9]+\s+device"; then
  echo "⚠️ No device in 'device' mode detected."
  echo "👉 Please connect your Android phone via USB and ensure 'USB Debugging' is enabled."
  echo "⏳ Waiting for device..."
  "$ADB" wait-for-device
fi

DEVICE_ID=$("$ADB" devices | grep -E "[a-zA-Z0-9]+\s+device" | head -n 1 | awk '{print $1}')
echo "✅ Device connected: $DEVICE_ID"

echo "🌐 Setting up network bridge (reverse port 8080)..."
"$ADB" reverse tcp:8080 tcp:8080

echo "📦 Installing updated edu_mobile APK with FCM support..."
"$ADB" install -r "$APK_PATH"

echo "🚀 Launching AugmentEd app..."
"$ADB" shell am start -n com.edu.platform.edu_mobile/.MainActivity

echo "📡 Streaming FCM logs from device (Ctrl+C to stop)..."
"$ADB" logcat -v time | grep --line-buffered -E "FCM|Firebase|flutter"
