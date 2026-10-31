# Amaranto Feed

Standalone Flutter app for Reggina news, fixtures, standings, and supporter chat. It has no custom application server; Firebase Authentication and Cloud Firestore provide Google sign-in and shared chat storage.

[Download the latest Android APK](https://github.com/davide-ferrara/amaranto-feed/releases/latest).
Open the downloaded APK to install it; Android may ask you to allow installation
from your browser. Future updates keep your app settings and cached data.

The feed header shows a gold download button on the right when a newer published
GitHub release is available. Tapping it downloads the universal Android APK through
your browser; you confirm installation yourself. Checks run on launch and resume,
at most once every six hours after a successful check, with a five-minute retry
window after network failures. Drafts, prereleases, and equal/older versions are
ignored. This APK update button is Android-only. See [release instructions](docs/releases.md).

## Stable alpha scope

- The feed aggregates RSS headlines and opens the original article in an in-app browser.
- The next-match card opens a match detail page. Standings and matchdays load directly from the public LND competition page; completed match scores are shown in the calendar.
- Main tabs support horizontal swiping. The feed is the initial and centered tab.
- The app follows the system light/dark appearance by default; the profile page can override it.
- The Chat tab is a shared, live room for users signed in with Google. It shows the latest 100 messages.

LND parsing runs on the device. Standings and visited matchdays are cached locally for six hours; if LND is unavailable, the app shows the last successfully saved data for that season and matchday, with its original update time. Pull to refresh bypasses the cache. An internet connection is needed on first use and to fetch new data.

## Firebase chat setup

The Android app is configured for the Firebase project `amaranto-feed`. To enable shared chat:

1. In Firebase Console, create a Cloud Firestore database in Native mode. Choose its location carefully because the database location cannot be changed later.
2. From the project root, install and sign in to the Firebase CLI, then publish the included security rules:

   ```sh
   npm install -g firebase-tools
   firebase login
   firebase deploy --only firestore:rules
   ```

The rules allow signed-in users to read the room and create messages as themselves. Messages are limited to 1,000 characters, cannot be edited, and can only be deleted by their author. Signed-in users can choose a public chat name under Settings; otherwise their Google account name is used. Anonymous debug sessions can read the chat but cannot post or delete messages. To use the automatic debug viewer, also enable the Anonymous provider under Firebase Authentication → Sign-in method. Deleting a permanent account removes that user's messages and chat profile before deleting their Firebase Authentication account. Chat messages stay in Firestore so they synchronize between devices; the client listens for new messages in real time and keeps the newest 100 in the view.

The current target is the native mobile app. A browser build would need a separate solution for third-party CORS restrictions on LND and RSS requests.

## Background news notifications

The app schedules an RSS check every 30 minutes with Workmanager, requiring an internet connection. It uses local notifications and needs notification permission. Profile → **Notizie in background** enables or disables RSS alerts. Tapping a news notification opens the newest article in the app. The same scheduled worker checks GitHub releases at most once per hour and sends an update notification when a newer APK is available.

Only previously unseen articles published after notifications were enabled and within the last 24 hours trigger alerts. Article URLs are remembered on-device for seven days, so relaunches and feed outages do not resend the same stories. Missing publication dates are excluded. Multiple new stories produce a single digest notification. Failed checks retry with exponential backoff; the initial launch does not send historical headlines.

Android may defer checks during Doze, battery restrictions, or loss of connectivity. Swiping the app away normally leaves the job scheduled; force-stopping it in system settings suspends work until the app is opened again. Workmanager persists the job across device restarts. The app does not keep a continuous foreground service running.

When an update is available, tapping its notification opens the in-app downloader and Android installer. Android may ask once to allow installs from Amaranto Feed, and the user must confirm each update in the system installer; regular apps cannot silently install their own updates.

The iOS background task and notification configuration is included, but has not been built or tested in this Linux workspace. iOS chooses background execution times and cannot guarantee a 30-minute cadence. See the [Workmanager platform guide](https://docs.page/fluttercommunity/flutter_workmanager/quickstart) and [notification plugin documentation](https://pub.dev/packages/flutter_local_notifications/versions/21.0.0).

## Screenshots

Current dark theme, captured from the Android emulator. Refresh all five views
with `python tool/capture_screenshots.py` while the app is running.

| Chat | Calendario | Feed |
| --- | --- | --- |
| <img src="docs/screenshots/chat.png" alt="Scheda Chat" width="220"> | <img src="docs/screenshots/calendar.png" alt="Scheda Calendario" width="220"> | <img src="docs/screenshots/feed.png" alt="Scheda Feed" width="220"> |

| Classifica | Profilo |
| --- | --- |
| <img src="docs/screenshots/standings.png" alt="Scheda Classifica" width="220"> | <img src="docs/screenshots/profile.png" alt="Scheda Profilo" width="220"> |

## Local Android development

Flutter is pinned in `.fvmrc`. Install the pinned SDK and resolve Dart packages once with `./tool/dev.sh setup`, then use:

```sh
./tool/dev.sh format
./tool/dev.sh analyze
./tool/dev.sh test
./tool/dev.sh devices
./tool/dev.sh run
./tool/dev.sh preview # Format, analyze, and relaunch for UI review
./tool/dev.sh install
```

Native launch colors are generated from `lib/theme/app_theme.dart` by
`python tool/sync_native_theme.py` (requires Pillow). Android `run`/`install`
commands sync them automatically; run it before an iOS build after palette changes.
For reusable cold-launch screenshots: `python tool/capture_launch.py`.

The development script resolves Android SDK and selects the connected emulator automatically. Set `ANDROID_SERIAL` if more than one Android target is connected. No local API process is needed.
