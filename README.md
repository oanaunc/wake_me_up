# Wake Me Up

A native iPhone and iPad alarm app. **Bring the sun up, one small move at a time.**

## Product plan

Wake Me Up turns a morning alarm into an achievable movement ritual. An original clay sun mascot, apricot and plum colors, generous typography, tactile cards, and short original music give it a warm identity. Inspired by the personal rituals in Pace Up and Daily Check, it rewards showing up rather than athletic performance.

1. **Tonight:** choose weekday repeats, a specific date, or a work/rest cycle. Skip one occurrence, change its time, add days off, or pause during time away. Ordinary weekly repeats use persistent AlarmKit schedules. Flexible plans save fourteen dates with a visible scheduled-through horizon and refill on app use or alarm interaction.
2. **Morning route:** order up to five steps, save presets, and practice complete routes. The thirteen challenges include movement, breathing, sun taps, typed maths, memory trails, typed intentions, code-matched destinations, letting in light, and preparing a drink. Physical actions can use explicit self-report; camera and motion are optional estimates. Completed route steps are checkpointed for recovery.
3. **Stay awake:** choose native snooze, or open your route immediately. An optional native follow-up alarm asks for three taps and explicit awake confirmation. Confirmation belongs to the existing sunrise; it never adds a second entry.
4. **Sounds and rest:** six presets use excerpts of the three licensed original tracks. Bundled gentle ramps, changing sounds across mornings, non-DRM local audio import, and separate ritual volume are available. A quick nap has its own slot. Optional bedside clock, bedtime reminder, rest planning goal, and three Siri shortcuts support setup.
5. **Journal:** actual completed mornings, step completion modes, mood, elapsed time including pauses, wake-up confirmation, and seven-day insights. Hide streaks or export a CSV to a destination you choose. Practice never creates credit. Data stays on device; local destinations, presets, unused imports and journal can be removed.
6. **Plus:** monthly/yearly plans grant the same entitlement: up to twenty saved alarms, adjustable challenge targets and longer practice. Free includes two saved alarms plus one nap, all thirteen standard challenges, five-step routes, flexible schedules, sounds and import, follow-up checks, optional sensors, journal/export and unlimited standard practice. No app login, ads or tracking. Proposed US pricing remains $2.99/month or $19.99/year; StoreKit supplies actual regional prices.
7. **Research:** public customer reviews and first-person discussions informed the revision. [Findings and source links](AppStore/Research/Findings.json) separate observed requests, anecdotal limitations and platform boundaries. Discovery research is not external beta feedback.

## Honest behavior

iOS retains system dismissal controls; the app cannot force exercise or prevent users from stopping a system alarm. The movement ritual begins in the app. Camera and motion recognition are optional estimates, not form or medical assessments. Gentle and emergency exits are always available. A physical device alarm and movement pass is required before release.

No app account is required. The user confirmed no login for free users. Apple handles subscription identity and payments. No backend, advertising SDK, analytics SDK, HealthKit, or tracking.

## Build

Open `WakeMeUp.xcodeproj` in Xcode 27. `project.yml` is the XcodeGen source. Run `xcodegen generate` after changing target configuration. Build and test with scheme `WakeMeUp`.

Bundle: `com.oanarinaldi.wakemeup`. Team: `HBD3XXQK45`.

## Validation and release state — 6 October 2026

- Build 1 was submitted on 5 October and rejected under 4.3 / 4.2.6. Apple's message describes insufficiently distinct functionality/content; it does not attribute rejection to simultaneous submissions. [Submission record](AppStore/Submission.json) preserves the original ID.
- Build 2 substantially expands the native application and uploaded successfully on 6 October (`build/research-release-upload.log`). TestFlight lists build 2 as Ready to Submit after processing. It has not been resubmitted. Genuine external TestFlight feedback has not been collected; automated tests must not be represented as beta feedback.
- Final revision checks: twenty-one unit tests passed (`build/ResearchVerifiedUnits.xcresult`), and nine phone UI flows passed (`build/ResearchFinalPhone.xcresult`). That full phone run initially exposed one audio-import unit failure: officially downloaded tracks used Opus in MP4. The app copies were converted to AAC, then all twenty-one unit tests passed. Every built-in preview is decode-tested and imports are bounded to twenty-five seconds.
- iPad: twenty-one unit tests and nine UI flows passed (`build/ResearchVerifiedPad.xcresult`); three separate integration tests were skipped in the standard scheme. Phone and iPad tests cover maths, memory, intentions, routes, navigation and fresh screenshots.
- Signed iOS 26.5 native integration: background alarm, Snooze without prematurely opening a route, completion, real follow-up alarm, three-tap confirmation and journal passed (`build/ResearchNative.xcresult`). The debug integration schedules alarms after fifteen seconds and uses default system sound. This does not verify physical custom tones.
- Build 1 subscription purchase/restore passed with Apple's local StoreKit configuration on iOS 27 (`build/StoreKit27.xcresult`); the underlying purchase implementation remains the same.
- Final device archive and signed IPA export succeeded (`build/WakeMeUp-Build2-Release.xcarchive`, `build/Build2ReleaseExport/WakeMeUp.ipa`). Both app and extension plists were verified as version 1.0, build 2. An initial upload attempt used an old plist build-number literal and was rejected before acceptance; explicit build-setting bindings now prevent that mismatch.
- Physical sound, locked-screen/terminated-app, barcode camera and movement sensing checks remain required. The connected iPhone still requires its passcode.
- The equivalent monthly/yearly Plus products remain at different App Store Connect service levels (1 and 2). The native browser drag did not persist a same-level arrangement. Align them and include the first group/products in the eventual review draft before public release; the app itself grants identical Plus access for both.

The privacy, support, and terms pages use the existing website header, shared stylesheet, photo banner, content layout, footer, and scripts. The 6 October privacy, support and terms changes retain that styling and were deployed successfully (website commit 4851c2a, FTP run 37443784528).

Public pages: [Privacy](https://oanarinaldi.com/wakemeupprivacy.html), [Support](https://oanarinaldi.com/wakemeupsupport.html), [Terms](https://oanarinaldi.com/wakemeupterms.html).

### Reviewer videos

`AppStore/Review/WakeMeUp-Build2-Demo.mp4` is the updated silent simulator recording. It shows a complete three-step practice route, tools/bedside clock/route editing, focus screens, native Snooze, an actual alarm ritual, a native follow-up, explicit awake confirmation and actual journal. It preserves recorded playback timing with a cut between two test runs. Native test schedules are accelerated to fifteen seconds and use simulator default sound; the Snooze countdown is not awaited. The video does not demonstrate hardware sensors or custom tone playback. Both recorded runs passed (`build/Build2ReviewerRoute.xcresult`, `build/Build2ReviewerAlarm.xcresult`). `Build2Recording.json` records cuts and limitations.

The earlier `AppStore/Review/WakeMeUp-Reviewer-Demo.mp4` and `Recording.json` remain as historical build 1 evidence. The updated 123.1-second recording is saved in App Review Information with revised reviewer notes; this does not itself resubmit the rejected version. The revised description, promotional text and keywords are saved as a listing draft, with build 2 selected. The original review submission remains Rejected; selecting the new candidate moved the version draft to Prepare for Submission. Update Review has not been submitted.

### Separate integration checks

Use `WakeStoreKit` for purchase/restore. Xcode's run action selects `UITests/WakeProducts.storekit`; running once from Xcode initializes the local StoreKit service when CLI initialization fails.

For `WakeAlarmIntegration`, build for testing, sign the simulator app with the existing Apple Development certificate (preserving entitlements), then run test-without-building. The test schedules an isolated 15-second alarm and exercises the actual SpringBoard button. Debug-only integration data is separate from normal user records.

### Device release check

On an unlocked iPhone or iPad, set an alarm two minutes ahead and test each of First Light, Soft Start, and Rise & Shine on the Lock Screen. Repeat after force-closing the app, with Silent mode and Focus enabled. Confirm Stop and Start moving behave as disclosed and that a completed ritual adds exactly one journal entry. Deny and then enable Alarms in Settings. Try guided push-ups, optional camera counting from a side view, dance/march motion tracking, and the gentle alternative; background and resume a timed routine. Finally purchase and restore Plus in the sandbox and confirm the free limit returns after expiration.
