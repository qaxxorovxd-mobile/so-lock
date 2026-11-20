# Device acceptance checks

Run on a physical Android phone with enrolled biometrics before publishing 1.2.0.

1. Open So Lock, unlock with a fingerprint, go home and reopen it five times. Each visit should show at most one prompt.
2. Protect a second app. Reopen it repeatedly, switch between two protected apps, and return after turning the screen off. Confirm the prompt belongs to the current app.
3. Cancel the prompt and enter the PIN. Retry biometrics using the fingerprint button. Verify both paths remain usable.
4. Leave during authentication, then return. A late success from the old request must not unlock the new session.
5. Enter five wrong PINs. Reopen the app during the countdown. PIN, password and biometrics must all respect the persisted lockout.
6. Try biometric lockout, no enrolled fingerprints and a temporarily unavailable sensor. The app code must remain available when the app's attempt guard permits it.
7. Test a password with the keyboard open, 6-digit PIN, shuffled keypad, custom background, decoy actions and camera permission denied.
8. Change settings rapidly and reopen. The last choice should be retained. Test Accessibility disabled, enabled and interrupted by the OS.
9. Install the signed ARM64 build over the previous signed ARM64 release and confirm settings are retained.

Automated checks cover the Dart lifecycle and layouts; they do not emulate vendor biometric hardware or prove every Android background-service behavior. The debug build was installed and launched on the available API 37 emulator without an AndroidRuntime or Flutter error in the inspected log.

Android themes follow the [local_auth_android integration requirements](https://pub.dev/packages/local_auth_android). Prompts deliberately cancel across backgrounding; each visible session owns its own retry.
