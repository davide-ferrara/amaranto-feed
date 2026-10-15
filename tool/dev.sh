#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"

usage() {
  cat <<'EOF'
Usage: ./tool/dev.sh <command>

Commands:
  setup     Install the Flutter version pinned in .fvmrc
  format    Format Dart sources
  analyze   Run Flutter static analysis
  test      Run Flutter tests
  devices   List connected Android devices/emulators
  run       Build and run on the selected Android device
  install   Install the current Flutter build on the selected Android device
EOF
}

flutter() {
  if ! command -v fvm >/dev/null 2>&1; then
    echo "FVM is required. Install FVM once, then run: ./tool/dev.sh setup" >&2
    exit 1
  fi
  fvm flutter "$@"
}

resolve_adb() {
  if [[ -n "${ADB:-}" && -x "$ADB" ]]; then
    printf '%s\n' "$ADB"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" && -x "$ANDROID_SDK_ROOT/platform-tools/adb" ]]; then
    printf '%s\n' "$ANDROID_SDK_ROOT/platform-tools/adb"
  elif [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    printf '%s\n' "$HOME/Android/Sdk/platform-tools/adb"
  elif command -v adb >/dev/null 2>&1; then
    command -v adb
  else
    echo "ADB not found. Set ANDROID_SDK_ROOT to your Android SDK." >&2
    exit 1
  fi
}

select_device() {
  local adb="$1" devices
  if [[ -n "${ANDROID_SERIAL:-}" ]]; then
    printf '%s\n' "$ANDROID_SERIAL"
    return
  fi

  devices="$("$adb" devices | awk 'NR > 1 && $2 == "device" {print $1}')"
  if [[ -z "$devices" ]]; then
    echo "No connected Android device. Start the emulator, then run: ./tool/dev.sh devices" >&2
    exit 1
  fi

  if [[ "$(printf '%s\n' "$devices" | wc -l)" -eq 1 ]]; then
    printf '%s\n' "$devices"
    return
  fi

  local emulators
  emulators="$(printf '%s\n' "$devices" | awk '/^emulator-/')"
  if [[ "$(printf '%s\n' "$emulators" | sed '/^$/d' | wc -l)" -eq 1 ]]; then
    printf '%s\n' "$emulators"
    return
  fi

  echo "More than one Android target is connected. Set ANDROID_SERIAL to the target ID." >&2
  "$adb" devices -l >&2
  exit 1
}

command_name="${1:-help}"
case "$command_name" in
  setup)
    fvm install
    flutter pub get
    ;;
  format)
    fvm dart format lib test
    ;;
  analyze)
    flutter analyze
    ;;
  test)
    flutter test
    ;;
  devices)
    adb_path="$(resolve_adb)"
    "$adb_path" devices -l
    ;;
  run|install)
    adb_path="$(resolve_adb)"
    device_id="$(select_device "$adb_path")"
    if [[ "$adb_path" == */platform-tools/adb ]]; then
      android_sdk="${adb_path%/platform-tools/adb}"
    else
      android_sdk="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Android/Sdk}}"
    fi
    export ANDROID_SDK_ROOT="$android_sdk"
    export ANDROID_HOME="$android_sdk"
    api_base="${RGN_API_BASE_URL:-http://10.0.2.2:8000}"
    if [[ "$command_name" == "run" ]]; then
      flutter run -d "$device_id" --dart-define="RGN_API_BASE_URL=$api_base" "${@:2}"
    else
      flutter build apk --debug --dart-define="RGN_API_BASE_URL=$api_base" "${@:2}"
      flutter install -d "$device_id" --debug \
        --use-application-binary=build/app/outputs/flutter-apk/app-debug.apk
    fi
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $command_name" >&2
    usage >&2
    exit 2
    ;;
esac
