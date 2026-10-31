# Android releases and updates

Public releases live at https://github.com/davide-ferrara/amaranto-feed/releases.
The app reads the public GitHub `releases/latest` endpoint without authentication.
Only a newer numeric `vMAJOR.MINOR.PATCH` release with an uploaded asset named
`amaranto-feed-MAJOR.MINOR.PATCH.apk` is offered in the feed header. The browser
handles downloading, and Android handles user-approved installation.

## Signing

The release build uses `android/app/amaranto-feed-release.jks` and
`android/key.properties`. Both are ignored by Git and must stay private. Back up
both files securely: future APKs must use the same key and application ID to
install as updates without losing data. Never regenerate an existing release key.
On a new machine, restore these files before building. `python
tool/create_release_key.py` is only for creating the very first key.

Debug builds have a different signature from published APKs. They cannot update
each other in place. Existing public release builds will update in place.

## Publishing the next version

1. Increase both the version name and build number in `pubspec.yaml`, for example
   from `1.0.0+2` to `1.0.1+3`. The button compares the three-part version name;
   Android also requires an increasing build number.
2. Run `./tool/dev.sh format`, `./tool/dev.sh analyze`, and `./tool/dev.sh test`.
3. Build with `./tool/dev.sh release`. It synchronizes native colors and signs a
   universal APK at `build/app/outputs/flutter-apk/app-release.apk`.
4. Copy the APK to `build/releases/amaranto-feed-1.0.1.apk` and create a SHA-256
   checksum file with `sha256sum`. Verify the APK signature with Android's
   `apksigner verify` tool. Keep signing files out of the release assets.
5. Commit and push the code to `main`, then publish a GitHub release tagged
   `v1.0.2` at that exact commit with the APK and checksum attached. Use
   `gh release create` with `--target` and `--notes-file` for the release notes.

Publish the public update channel as a normal release, not a draft or prerelease:
GitHub's latest-release endpoint excludes those. Users will see the button on a
later launch or resume once the six-hour check window expires. No GitHub token is
included in the app. Offline or rate-limited checks leave the app usable.

After publishing, `./tool/dev.sh check-release 0.9.0` should find the new APK;
`./tool/dev.sh check-release 1.0.0` should find none when `v1.0.0` is current.
This runs the same update service against the real public release endpoint.
