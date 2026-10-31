# Project workflow

- The app's user-facing language must be Italian. Keep UI labels, messages, dialogs, and notifications in Italian.
- Flutter is pinned in `.fvmrc` (3.47.7). Use `./tool/dev.sh format`, `analyze`, `test`, `run`, or `install`; do not search for Flutter, Dart, Android SDK, or ADB paths on each task.
- FVM's SDK cache is `/home/dff/fvm/versions` in this environment. The project-local `.fvm/flutter_sdk` link is generated and ignored by Git.
- Android SDK and ADB are at `/home/dff/Android/Sdk` and `/home/dff/Android/Sdk/platform-tools/adb`. `./tool/dev.sh` resolves these and selects the sole connected device, preferring a sole emulator when multiple targets exist. Set `ANDROID_SERIAL` to override the selection.
- The Android emulator is normally already running. Check `./tool/dev.sh devices`; do not start another emulator if one is listed.
- Codex's default command sandbox cannot start the ADB daemon (permission denied). Run ADB/device install or Flutter deploy commands with command escalation when the sandbox reports that error; use the fixed project script/path instead of searching again.
- The app fetches LND and RSS data directly over HTTPS. No local API server or API base URL is needed.
