# Apple to Android parity record

Baseline: Apple build 2, commit 2e60caf. The original artwork and music files are reused; the complete mission copy is generated directly from `Sources/Models.swift` with the device-name wording adapted. The Apple application code is unchanged.

| Area | Android implementation |
| --- | --- |
| Welcome, Morning, Move, Sunrises, Settings | Same headings, artwork, content order, cream background, pastel cards and rounded visual language |
| Thirteen challenges | Push-ups, squats, dance, march, stretch, breathing, sun taps, typed maths, memory, intentions, matching destination, daylight, drink |
| Morning routes | Up to five steps, reorder/remove, ready-made and saved presets, per-step configuration, practice, completion checkpoints |
| Alarms | Weekdays, once, dated, work/rest cycle, skip, day off, pause, next-time override, enable/delete; native exact delivery and boot/timezone recovery |
| Snooze and follow-up | 3/5/10/15-minute choices; persisted snooze; follow-up after completed routes; three taps plus explicit awake confirmation updates the same entry |
| Audio | Six identical presets, changing sound across mornings, 15-second gentle ramp, first-25-second local import, previews, separate ritual volume and mute |
| Tools | One separate nap, days off, bedside clock/dim mode, readiness test, local destination library |
| Journal | Real alarm routes only, steps/modes, mood, elapsed time including pauses, 28-day grid, seven-day insights, optional streak hiding and CSV export |
| Optional sensors | Local MoveNet push-up estimate, accelerometer activity estimate, local ZXing barcode/QR matching, guided alternative and safe exits |
| Plus | Monthly/yearly Play subscriptions, regional prices, restore/manage, 20 saved alarms, custom goals, longer dance practice |
| Privacy | No app account, ads, developer server or developer analytics; local data and sensor processing; Android backup disabled; store handles billing |
| Platform services | Android alarm service/notifications, Play Billing, system share/audio chooser and app-icon shortcuts replace the respective Apple APIs |

Apple's proprietary font, SF Symbols and operating-system UI are replaced with licensed Android-compatible equivalents. These differences prevent a literal pixel-for-pixel match of platform chrome. Visual checks must compare app layout and content at equivalent logical viewport sizes, not claim identical OS rendering.
