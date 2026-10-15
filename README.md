# RGN News

Flutter client for RGN News, with the FastAPI service in `backend/`.

## Stable alpha scope

- The feed aggregates RSS headlines and opens the original article in an in-app browser.
- The next-match card opens a match detail page. Standings and matchdays come from the LND-backed REST API; completed match scores are shown in the calendar.
- Main tabs support horizontal swiping. The feed is the initial and centered tab.
- The app follows the system light/dark appearance by default; the profile page can override it.
- Chat and sign-in remain placeholders in this alpha.

The Android emulator needs the local API running. See `backend/README.md` for setup and API details.

## Local Android development

Flutter is pinned in `.fvmrc`. Install the pinned SDK and resolve Dart packages once with `./tool/dev.sh setup`, then use:

```sh
./tool/dev.sh format
./tool/dev.sh analyze
./tool/dev.sh test
./tool/dev.sh devices
./tool/dev.sh run
./tool/dev.sh install
```

The development script resolves Android SDK and selects the connected emulator automatically. Set `ANDROID_SERIAL` if more than one Android target is connected. The emulator uses `http://10.0.2.2:8000` for the local API by default; set `RGN_API_BASE_URL` to override it.
