#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
adb="/home/dff/Android/Sdk/platform-tools/adb"
emulator="/home/dff/Android/Sdk/emulator/emulator"
avd_name="Reggina_Review"
avd_home="/home/dff/.config/.android/avd"

find_emulator() {
  "$adb" devices | awk 'NR > 1 && $2 == "device" && $1 ~ /^emulator-/ {print $1; exit}'
}

if [[ ! -x "$adb" || ! -x "$emulator" ]]; then
  echo "Android SDK emulator tools were not found at the configured project paths." >&2
  exit 1
fi

emulator_id="$(find_emulator)"
if [[ -z "$emulator_id" ]]; then
  if [[ ! -f "$avd_home/$avd_name.ini" ]]; then
    echo "The existing $avd_name virtual device is missing." >&2
    exit 1
  fi
  ANDROID_AVD_HOME="$avd_home" nohup "$emulator" -avd "$avd_name" -no-snapshot \
    >/tmp/amaranto-feed-emulator.log 2>&1 </dev/null &
  for _ in $(seq 1 180); do
    emulator_id="$(find_emulator)"
    [[ -n "$emulator_id" ]] && break
    sleep 1
  done
fi
if [[ -z "$emulator_id" ]]; then
  echo "No Android emulator became available. See /tmp/amaranto-feed-emulator.log." >&2
  exit 1
fi

echo "Waiting for the Android emulator to finish booting..."
"$adb" -s "$emulator_id" wait-for-device
for _ in $(seq 1 180); do
  if [[ "$("$adb" -s "$emulator_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" == "1" ]]; then
    break
  fi
  sleep 1
done
if [[ "$("$adb" -s "$emulator_id" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]]; then
  echo "The emulator did not finish booting within 3 minutes. See /tmp/amaranto-feed-emulator.log." >&2
  exit 1
fi

"$project_root/tool/dev.sh" install "$@"
"$adb" -s "$emulator_id" shell monkey -p it.davideferrara.amarantofeed 1
