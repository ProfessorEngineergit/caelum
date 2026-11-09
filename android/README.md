# Caelum for Android

A native Android version of Caelum: Kotlin, Jetpack Compose and **Material 3 Expressive**.
The same ten sources as the desktop apps, NASA APOD first.

- **The UI wears the cosmos.** The colour scheme is generated from the picture on screen
  (its most vibrant colour, as an expressive *Vibrant* scheme) and glides to each new one.
  Material You colours from the system wallpaper are an option on Android 12 and later.
- **Expressive throughout.** The theme uses `MaterialExpressiveTheme` and the spring-based
  `MotionScheme.expressive()`, with `LoadingIndicator`s, `MaterialShapes` for each source,
  a multi-browse carousel and segmented lists.
- **Set as wallpaper** on the home screen, the lock screen or both. Huge originals are
  decoded no larger than the display needs.
- **Daily wallpaper.** WorkManager checks the chosen source every few hours and sets the
  newest picture, only when it changed. It can wait for Wi-Fi.
- English and German.

## Build

Open the `android/` folder in Android Studio and run the `app` configuration, or:

```bash
cd android
./gradlew :app:installDebug
```

`./gradlew :core:test` runs the source tests. They are plain JVM tests, so no emulator
is needed.

## Layout

| Module | What's in it |
|--------|--------------|
| `core` | Plain Kotlin/JVM: the image sources (APOD, Djangoplicity feeds, curated galleries) and their parsers. Ports `desktop/src/main/sources.js`, and the tests are the same as `desktop/test/sources.test.js`. |
| `app`  | The Android app: Compose UI, theme, settings (DataStore), setting the wallpaper and the daily job. |

The curated galleries come from `desktop/src/main/galleries.json`, which is copied in at
build time, so all three apps share one list.

## Release builds

`assembleRelease` is minified and, for now, signed with the debug key so the APK
installs straight away. Set up a real signing config before you publish it anywhere.
