# So Lock

A fast, minimal app locker for Android, built with Flutter.

## Features

- **App Lock** — lock any app with a 4/6-digit PIN or a password, plus fingerprint / face.
- **Decoy codes** — extra codes that look like a normal unlock but trigger an action instead:
  lock the phone screen, go home, show a fake crash, or open the app while silently taking a photo.
  Example: main code `1550` opens the app, decoy code `1050` locks the screen.
- **Smart Lock** — lock only on a schedule, never on trusted Wi‑Fi networks or at trusted places.
- **Intruder Alert** — front (and optionally back) camera photo after wrong attempts.
- **Custom lock screen** — accent colour, gradient or photo background with blur/dim, keypad styles, shuffled keys.
- **Biometric fallback** — falls back to PIN/password whenever biometrics fail or are unavailable.
- **Configurable vibration** and subtle animations.
- Brute-force lockout, salted hashes for all codes, lock screen hidden from screenshots and recents.

## How it works (Android)

- An Accessibility Service watches only window-state changes (which app is in front — no screen content).
- The lock UI runs in a pre-warmed Flutter engine (`lockMain`), so it appears instantly.
- Short hops to another screen and back (e.g. a gallery's private-album password prompt) don't re-lock the app;
  going to the home screen or turning the screen off does.

## Download

Latest signed APK: **[so-lock.apk](https://github.com/qaxxorovxd-mobile/so-lock/releases/latest/download/so-lock.apk)**
(or the smaller [arm64](https://github.com/qaxxorovxd-mobile/so-lock/releases/latest/download/so-lock-arm64.apk) build for most modern phones).
Website: https://qaxxorovxd-mobile.github.io/so-lock/

## Build

```sh
flutter pub get
flutter build apk --release
```

Release signing reads `android/key.properties` (not committed):

```properties
storePassword=...
keyPassword=...
keyAlias=solock
storeFile=../so-lock-release.jks
```

Without it, release builds fall back to the debug key.

On first launch, enable **So Lock** under *Settings → Accessibility*.

> iOS does not allow third-party apps to lock other apps; on iOS only So Lock's own lock is available.
