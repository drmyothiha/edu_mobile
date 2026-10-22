#!/usr/bin/env bash
# Quick launcher for edu_mobile on connected Android device
DEVICE_ID=$(flutter devices 2>/dev/null | grep -E 'android-arm' | awk -F'•' '{print $2}' | tr -d ' ' | head -n 1)

if [ -n "$DEVICE_ID" ]; then
  echo "🚀 Launching on detected Android device: $DEVICE_ID"
  flutter run -d "$DEVICE_ID" "$@"
else
  echo "📱 No physical Android device detected, launching on default device..."
  flutter run "$@"
fi
