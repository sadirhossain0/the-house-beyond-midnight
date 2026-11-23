#!/usr/bin/env bash
# Builds every desktop and Android release into build/.
# Android: needs the Android SDK (export/android/android_sdk_path in Godot's editor settings) and a
# keystore. A debug-signed APK is produced unless HBM_KEYSTORE, HBM_KEY_USER and HBM_KEY_PASS are set.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=${GODOT:-godot}
$GODOT --headless --path . --import
for p in Windows Linux macOS; do
  case $p in
    Windows) out=build/windows/HouseBeyondMidnight.exe ;;
    Linux) out=build/linux/HouseBeyondMidnight.x86_64 ;;
    macOS) out=build/macos/HouseBeyondMidnight.zip ;;
  esac
  mkdir -p "$(dirname "$out")"
  echo "== $p"
  $GODOT --headless --path . --export-release "$p" "$out"
done
mkdir -p build/android
if [[ -n "${HBM_KEYSTORE:-}" ]]; then
  GODOT_ANDROID_KEYSTORE_RELEASE_PATH=$HBM_KEYSTORE GODOT_ANDROID_KEYSTORE_RELEASE_USER=$HBM_KEY_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=$HBM_KEY_PASS \
    $GODOT --headless --path . --export-release Android build/android/HouseBeyondMidnight.apk
else
  $GODOT --headless --path . --export-debug Android build/android/HouseBeyondMidnight.apk
fi
ls -la build/*/
