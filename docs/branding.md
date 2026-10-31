# Amaranto Feed

The mark combines a geometric capital R on the left with an overlapping news-feed card on the right. The selected revision removes the football, ball-shaped letter contours, and diagonal motion lines from the earlier concept. It is a visual redesign, not a legal clearance or a claim that no third-party rights exist. The app uses amaranto `#841230`, opaque white details, and a warm launch/icon background `#F5F1F0`.

## Assets

- Generated master: `assets/branding/amaranto_feed_mark_source.png` (transparent PNG).
- App/logo export: `assets/branding/amaranto_feed_mark.png` (1024 × 1024, transparent).
- Standalone icon export: `assets/branding/amaranto_feed_icon.png` (1024 × 1024, opaque).
- Android exports: density-specific legacy launcher, adaptive foreground, legacy splash, and Android 12 splash PNGs under `android/app/src/main/res/`.
- iOS exports: all AppIcon and LaunchImage asset sizes under `ios/Runner/Assets.xcassets/`.

The platform images are packaged from the same master with transparent trimming, proportional resizing, and safe padding. Run `python tool/build_brand_assets.py` from the repository root (requires Pillow) to regenerate them. The generated source artwork remains untouched.

The display name is Amaranto Feed. The existing package identifier and Dart package name remain stable so installed app data and background jobs continue to work.

## Generation

Created with the built-in imagegen tool. The earlier concept was supplied as an edit target to retain the feed card; the R was redrawn and the football and speed lines removed. Exact final prompt:

> Edit this Amaranto Feed logo. Preserve ONLY its concept of an amaranto letter R on the LEFT and overlapping white news-feed card on the RIGHT. Keep the feed card's rounded thick amaranto outline, small square thumbnail block and 3 horizontal news lines, and roughly its current scale and placement. Completely REMOVE the football, every black football patch, all diagonal motion stripes and all ball contours. Replace the current vintage-derived R with a DISTINCT NEW GEOMETRIC CAPITAL R: a complete straight vertical left stem, a compact squared-off upper bowl with softly rounded corners and a clear rectangular transparent counter, and a clean short diagonal right leg. The R must read as an ordinary complete letter, no circular football-shaped left edge, no cropped or missing left stem, no resemblance to a historic club crest. Make the silhouette substantially different from the reference's original R while keeping a strong compact R+news-card emblem. Use solid flat deep amaranto #841230 and opaque white only; no black, gradients, shadows, ball imagery, motion strokes, badge, words or extra symbols. Crisp professional vector-like logo, near-square composition, generous transparent margins, designed to stay legible as a mobile icon. Background transparent; white card stays opaque.

## Launch screens

Native splash colors are generated from `AppPalette` by `tool/sync_native_theme.py`, automatically invoked by Android run/install commands. The light launch stays warm white; dark launches use the same vertical amaranto gradient as the app (lighter top, darker bottom), preserving the original mark. Android 12+ requires a solid OS-controlled entry frame, so it uses the gradient's top color, then the native exit transition uses the full gradient. Older Android versions use a gradient launch drawable directly. iOS uses a full-screen appearance-aware gradient image behind the existing logo and wordmark; it requires visual verification on Apple tooling. There is no additional Flutter splash page or startup timer. `tool/capture_launch.py` saves cold-launch frames for repeatable Android visual checks. Launcher icon backgrounds are independent of the new splash colors.

## Dark appearance

Both appearances use the exact same original amaranto R and white feed-card artwork from `assets/branding/amaranto_feed_mark_source.png`. There is no recoloring or separately generated dark logo. The dark icon export, `assets/branding/amaranto_feed_icon_dark.png`, simply omits the day icon’s light background and preserves transparency. The discarded pink variant is no longer used or packaged.

All dark-theme tabs share the same continuous amaranto background, running vertically from lighter `#841230` at the top to darker `#3F091B` at the bottom. News, calendar, standings, and profile panels use this gradient with white text and gold borders, matching the next-match banner. Standings retain green/orange rank markers for promotion/playoffs and a gold Reggina highlight, rather than separate colored row backgrounds. The original logo sits on a small light tile for contrast. Shared Flutter colors, gradients, light/dark themes, and panel styling are defined in `lib/theme/app_theme.dart`; screens use `AppPalette`, `AppTheme.panel`, and the active `ColorScheme`. Native launch backgrounds match the system appearance. Android has light/dark adaptive and legacy icon resources; iOS has a transparent dark icon appearance and appearance-aware launch colors. The Flutter header always uses the original transparent mark, including with a Profile theme override. System/launcher themed-icon settings can still apply their own styling.

The built-in imagegen prompt above created the shared mark. The dark exports are only resized and padded versions of that same artwork; no new image-generation prompt is used.
