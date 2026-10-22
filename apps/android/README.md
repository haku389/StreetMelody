# StreetMelody Android

Jetpack Compose UI with the same pastel palette and generated art as the Web and iOS apps.

## Build

Requires JDK 17 and Android SDK 35. Set `ANDROID_HOME` or create a local (ignored) `local.properties` with `sdk.dir`.

```sh
cd apps/android
./gradlew :app:assembleDebug
```

Debug APK: `app/build/outputs/apk/debug/app-debug.apk`.

The Gradle wrapper pins 8.14.3; `gradle/libs.versions.toml` pins dependencies. BLE uses the existing Android permissions and implementation.

## Implemented UI

- Home: greeting, generated hero, daily track and real progress, collection totals, daily mission, recent tracks, playlist artwork.
- Puzzle: existing 6×4 piece display and progress inside shared pastel cards.
- Shared palette, card, button, progress bar, navigation and launch theme.
- First-use guide: three steps, skip and replay, with completion saved on the device.
- Almost-finished recommendations: at most two incomplete puzzles, ordered by completion ratio; collect shortcuts only for available, unowned candidate pieces.
- Exchange: candidates from the API, owned/unowned status, confirmation, single-flight receipt and result detail.
- Artist: grouped completion totals and a per-artist track list.
- Playlist: the API's daily playlist and per-track detail routes.
- Collection: every catalog track links to the selected puzzle or mystery detail. Mystery supports API hints and title unlock.
- Loading, partial-data errors and retry. HTTP failures no longer look like successful mutations.

The debug app uses the local Go API at `http://10.0.2.2:3001/api`. Debug-only cleartext access is limited to emulator host / loopback addresses; release networking remains unchanged. Android hint actions currently use the prototype API directly; reward ads and real-device BLE exchange are not implemented by these screens.

Artwork: `app/src/main/res/drawable-nodpi/pastel_hero.png` and `pastel_cozy_room.png`, reused from the approved Web prototype. The current bird hero prompt is in `../web/assets/pastel/hero-generation.md`; the room prompt is in `../web/prototype/README.md`.

## Verification (2026-10-15)

`./gradlew :app:assembleDebug` succeeded, including Kotlin compilation, resources, dex and APK packaging. The emulator can now start after host free space increased. Home and first-use guide were visually inspected, and the full receive-piece → detail → artist → playlist → collection → home flow passed an instrumentation test against an isolated local API. Six unit tests and one instrumentation test passed.


## Tests

```sh
./gradlew :app:testDebugUnitTest
# Requires a running emulator and an isolated local API on host port 3001:
./gradlew :app:connectedDebugAndroidTest
```

Unit tests cover recommendation filtering, completion ratios, deterministic ordering, locked-title masking, collectable candidate matching, and variable puzzle grid sizes. The instrumentation smoke test receives a piece and navigates artist / playlist / collection screens against the local API. Do not run the integration smoke test against production data.
