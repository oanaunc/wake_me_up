# Wake Me Up for Android

The Android app carries over the Apple app's original clay artwork, apricot/plum/cream palette, rounded typography, complete mission copy, all thirteen challenges, five-step routes, presets, flexible alarms, six original sounds, local audio import, naps, bedside clock, rest planning, reminders, journal/export, optional sensors and Plus plans.

The packaged screen implementation is local HTML/CSS/JavaScript in an Android WebView. It does not load a hosted website. An HTTPS asset loader serves bundled files, a restrictive CSP blocks remote resources, file/content access is disabled and external navigation opens only the app's support domain, Google Play or email. Native Java implements alarms, ringing, audio, local persistence, sharing, camera, movement estimates, shortcuts and Play Billing.

## Build and checks

```sh
export JAVA_HOME='/Applications/Android Studio.app/Contents/jbr/Contents/Home'
export ANDROID_HOME="$HOME/Library/Android/sdk"
node android/tests/core.cjs
./android/gradlew -p android :app:testDebugUnitTest :app:lintDebug :app:assembleDebug :app:assembleDebugAndroidTest
```

Install both debug APKs on a dedicated test emulator and run:

```sh
adb -s emulator-5562 install -r android/app/build/outputs/apk/debug/app-debug.apk
adb -s emulator-5562 install -r android/app/build/outputs/apk/androidTest/debug/app-debug-androidTest.apk
adb -s emulator-5562 shell am instrument -w com.oanarinaldi.wakemeup.test/androidx.test.runner.AndroidJUnitRunner
```

These device tests clear the test app's local data. Never run them against a user's working installation. They verify actual AlarmManager delivery and persistent snooze, route/journal/follow-up behavior, challenge validation, bounded import and audio decoding, bundled pose inference and QR decoding, and screen overflow. Screenshots are genuine emulator captures; fixtures are development data, not customer history or beta feedback.

`python3 android/scripts/sync-apple-content.py` refreshes the complete mission copy and original artwork/audio from the Apple source. It requires ffmpeg for CAF-to-AAC alarm conversion. [Asset provenance](../GooglePlay/apple-asset-map.json) and [third-party notices](../GooglePlay/third-party.json) record those inputs.

## Signed artifacts

`python3 android/scripts/create-upload-key.py` creates a private app-specific RSA upload key once, outside Git, under `~/.local/share/wake-me-up/android-upload/`. Preserve this folder securely for future app updates. `signing.json` contains `keystore`, `storePassword`, `keyPassword` and `alias`. Add the app-specific Google Play licensing public key as `playPublicKey` after the Console app is created. The key is public, but the signing secrets must stay private.

`python3 android/scripts/build-release.py` runs JVM checks, release lint and minified signed APK/AAB builds. It refuses a submission build without the licensing key. `--candidate` explicitly produces preview artifacts with purchases disabled until the key and store products are configured. No debug or fake entitlement can unlock release Plus. The output report includes the package, version and SHA-256.

## Android equivalents

- `AlarmManager.setAlarmClock` schedules the next occurrence. When it fires, the receiver registers its successor, including exceptions and work/rest cycles. Boot, app replacement, time and timezone changes restore schedules. Android therefore has no Apple fourteen-date planning horizon. Snooze timestamps persist across refresh and process restart.
- Exact alarms and full-screen intents are used solely for user-created alarms and follow-up checks. Android retains system controls. Force-stopping or powering off prevents alarms; the readiness screen explains this. Notifications and full-screen display must be enabled. Bedtime reminders use separate inexact local notifications.
- Ringing uses an alarm audio stream in a foreground media-playback service, with wake lock, vibration, stop and optional snooze. Original alarm clips are AAC conversions of Apple's PCM clips. Music during routes has a separate media volume.
- Camera push-up estimates run a bundled MoveNet model with the standalone LiteRT Interpreter; ZXing decodes destination codes. No camera frame, pose output or barcode payload is uploaded. Code payloads are discarded after SHA-256 matching. Sensor input is transient. No downloaded inference model or developer analytics is used. Google Play performs its own billing operations and related diagnostics.
- The Android app disables cloud backup and device transfer. Journal export uses the system share sheet. Users can remove alarms, codes, presets, unused imports and journal entries.
- Three app-icon shortcuts replace Siri/Shortcuts. Google Play Billing replaces StoreKit; local signed receipts, fresh purchase queries, pending-state checks, acknowledgement and a one-hour offline cache determine entitlement. Declines, cancellation and store unavailability leave standard features usable.
- Apple system fonts and SF Symbols are not redistributable Android assets. The Android app uses licensed Nunito headings and local vector equivalents. Status bars, pickers, camera previews and lock-screen alarm controls follow Android. Pixel-identical platform chrome is not claimed.

## Store preparation and limits

Package `com.oanarinaldi.wakemeup`, version 1.0 (1), Android 10+ / target API 36. Free: two saved alarms plus one nap; all thirteen standard challenges; five-step routes; schedules; sounds/import; checks; journal/export and standard practice. Plus: twenty saved alarms, custom targets and longer practice. Monthly and yearly products provide the same entitlement and show actual Google Play regional prices.

[Play preparation state](../GooglePlay/submission-status.json) records what is done and pending. Do not describe candidate artifacts as submitted or approved. Real Google Play purchase lifecycle tests require this app's products, licensing key and test-track configuration. Emulator checks do not verify a physical phone's locked-screen sound routing, OEM restrictions, camera counting accuracy or movement sensing.
