#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adb="/home/dff/Android/Sdk/platform-tools/adb"
emulator="/home/dff/Android/Sdk/emulator/emulator"
avd_name="Reggina_Review"
avd_home="/home/dff/.config/.android/avd"

if [[ ! -x "$adb" || ! -x "$emulator" ]]; then
  echo "Android SDK emulator tools were not found at the configured project paths." >&2
  exit 1
fi

if ! "$adb" devices | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ {found=1} END {exit !found}'; then
  if [[ ! -f "$avd_home/$avd_name.ini" ]]; then
    echo "The existing $avd_name virtual device is missing." >&2
    exit 1
  fi
  ANDROID_AVD_HOME="$avd_home" nohup "$emulator" -avd "$avd_name" -no-snapshot \
    >/tmp/amaranto-feed-emulator.log 2>&1 </dev/null &
fi

echo "Waiting for the Android emulator to finish booting..."
"$adb" wait-for-device
for _ in $(seq 1 180); do
  if [[ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    break
  fi
  sleep 1
done
if [[ "$("$adb" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; then
  echo "The emulator did not finish booting within 3 minutes. See /tmp/amaranto-feed-emulator.log." >&2
  exit 1
fi

"$project_root/tool/dev.sh" install "$@"
"$adb" shell monkey -p com.example.rgn_news 1
