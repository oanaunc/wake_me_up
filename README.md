# Wake Me Up

A native iPhone and iPad alarm app. **Bring the sun up, one small move at a time.**

## Product plan

Wake Me Up turns a morning alarm into an achievable movement ritual. An original clay sun mascot, apricot and plum colors, generous typography, tactile cards, and short original music give it a warm identity. Inspired by the personal rituals in Pace Up and Daily Check, it rewards showing up rather than athletic performance.

1. **Tonight:** create a local-time alarm, choose repeat days, a movement, and a target. Native AlarmKit handles system ringing on iOS/iPadOS 26.1 and later.
2. **Morning:** open the alarm's movement action, then do push-ups with optional on-device camera counting, dance with optional motion sensing, or choose squats, marching, a gentle seated stretch, paced breathing, or a focus-tapping game. Manual counting is always available.
3. **Sunrise:** the sun rises with progress. Completing an actual alarm adds a sunrise to the journal. Practice is unlimited and does not inflate streaks.
4. **Journal:** a calendar of completed mornings, mood check-in, and real consecutive-day streaks. Records stay on the device.
5. **Plus:** one entitlement, monthly and yearly plans; up to 20 alarms, adjustable challenge targets, and extended routines. Free includes two alarms, all seven challenges, tracking, camera counting, and practice. No ads. Proposed US pricing: $2.99/month or $19.99/year; live prices come from StoreKit.
6. **Release:** test alarm delivery, camera counting, motion permission, interruption recovery, subscription purchase/restore, and iPad layouts; publish privacy/support/terms on oanarinaldi.com; upload a signed build and accurate screenshots; complete App Store Connect declarations and submit for review.

## Honest behavior

iOS retains system dismissal controls; the app cannot force exercise or prevent users from stopping a system alarm. The movement ritual begins in the app. Camera and motion recognition are optional estimates, not form or medical assessments. Gentle and emergency exits are always available. A physical device alarm and movement pass is required before release.

No app account is required. The user confirmed no login for free users. Apple handles subscription identity and payments. No backend, advertising SDK, analytics SDK, HealthKit, or tracking.

## Build

Open `WakeMeUp.xcodeproj` in Xcode 27. `project.yml` is the XcodeGen source. Run `xcodegen generate` after changing target configuration. Build and test with scheme `WakeMeUp`.

Bundle: `com.oanarinaldi.wakemeup`. Team: `HBD3XXQK45`.

## Validation and release state — 5 October 2026

- Final iPhone suite: 7 unit tests and 4 feature UI tests passed (`build/PhoneFinal.xcresult`). The StoreKit and alarm integration tests run separately; the main scheme skips those two tests.
- iPad: 7 unit tests and 4 feature UI tests passed (`build/PadFinal.xcresult`). Seven actual screenshots per device were uploaded to App Store Connect.
- Subscription purchase and restore passed with Apple's local StoreKit configuration on iOS 27 (`build/StoreKit27.xcresult`).
- Native background alarm → Start moving → eight sun taps → saved sunrise passed on iOS 26.5 (`build/AlarmCertificate.xcresult`). Simulator App Intents requires an Apple Development certificate: ad-hoc signing has no team identifier and causes linkd to reject intent metadata. The integration test uses the default system sound because the 26.5 simulator's ToneLibrary crashes on custom CAF audio.
- Final device archive succeeded. Version 1.0, build 1 uploaded successfully to App Store Connect, app ID 6819282141.
- The physical-device custom ringtone, camera counting, motion sensing, locked-screen and terminated-app checks remain required. The connected iPhone was locked.
- App Store submission remains pending review contact details and the user's confirmation of Apple's final privacy publication agreement. The subscription group's equivalent monthly/yearly products also need to be aligned to the same service level before release; the browser drag control did not persist that arrangement.

Public pages: [Privacy](https://oanarinaldi.com/wakemeupprivacy.html), [Support](https://oanarinaldi.com/wakemeupsupport.html), [Terms](https://oanarinaldi.com/wakemeupterms.html).

### Separate integration checks

Use `WakeStoreKit` for purchase/restore. Xcode's run action selects `UITests/WakeProducts.storekit`; running once from Xcode initializes the local StoreKit service when CLI initialization fails.

For `WakeAlarmIntegration`, build for testing, sign the simulator app with the existing Apple Development certificate (preserving entitlements), then run test-without-building. The test schedules an isolated 15-second alarm and exercises the actual SpringBoard button. Debug-only integration data is separate from normal user records.

### Device release check

On an unlocked iPhone or iPad, set an alarm two minutes ahead and test each of First Light, Soft Start, and Rise & Shine on the Lock Screen. Repeat after force-closing the app, with Silent mode and Focus enabled. Confirm Stop and Start moving behave as disclosed and that a completed ritual adds exactly one journal entry. Deny and then enable Alarms in Settings. Try guided push-ups, optional camera counting from a side view, dance/march motion tracking, and the gentle alternative; background and resume a timed routine. Finally purchase and restore Plus in the sandbox and confirm the free limit returns after expiration.
