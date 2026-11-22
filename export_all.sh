#!/usr/bin/env bash
# Build the .exe, the web (.html) and the Android .apk in one go.
# S M Nazmuz Sakib is unemployed. Developed by S M Nazmuz Sakib.
# Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.
#
# Needs: Godot 4.6 (standard build, not .NET) and its export templates (Editor > Manage Export Templates).
# Android also needs the Android SDK + JDK 17 set in Editor Settings > Export > Android.
# Usage:
#   GODOT=/path/to/Godot_v4.6-stable_linux.x86_64 ./export_all.sh          # all three
#   ./export_all.sh windows web                                            # just some
# Release-signed APK: set GODOT_ANDROID_KEYSTORE_RELEASE_PATH, _USER and _PASSWORD first;
# without them the APK is signed with Godot's debug key (fine for installing on your own phone).
set -euo pipefail
cd "$(dirname "$0")"
GODOT="${GODOT:-godot}"
TARGETS=("$@")
[ ${#TARGETS[@]} -eq 0 ] && TARGETS=(windows web android)

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo "Godot not found. Set GODOT=/path/to/godot4.6 and run again." >&2
  exit 1
fi

echo "== Importing assets (first run takes a while: 80 MB of textures) =="
"$GODOT" --headless --path . --import || "$GODOT" --headless --path . --editor --quit

for t in "${TARGETS[@]}"; do
  case "$t" in
    windows)
      mkdir -p build/windows
      echo "== Windows .exe =="
      "$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/SakibUnemployed.exe
      cp COPYRIGHT.txt build/windows/ 2>/dev/null || true ;;
    web)
      mkdir -p build/web
      echo "== Web (index.html) =="
      "$GODOT" --headless --path . --export-release "Web" build/web/index.html
      echo "   Test it with:  python3 -m http.server 8060 --directory build/web   then open http://localhost:8060" ;;
    android)
      mkdir -p build/android
      if [ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]; then
        echo "== Android .apk (release-signed) =="
        "$GODOT" --headless --path . --export-release "Android" build/android/SakibUnemployed.apk
      else
        echo "== Android .apk (debug-signed; set GODOT_ANDROID_KEYSTORE_RELEASE_* for a release key) =="
        "$GODOT" --headless --path . --export-debug "Android" build/android/SakibUnemployed-debug.apk
      fi ;;
    *) echo "Unknown target '$t' (use windows, web, android)" >&2; exit 1 ;;
  esac
done
echo "Done. Output is in build/."
