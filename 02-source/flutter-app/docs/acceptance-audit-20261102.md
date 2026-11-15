# MOCHI audit — 2026-11-02 (Asia/Ho_Chi_Minh)
Not a completed release acceptance.

- Floating bar: Center was unconstrained vertically inside bottomNavigationBar. Added heightFactor:1. Device retest pending.
- Today checkbox: card InkWell exists. Bar geometry may have intercepted touches. Device retest pending.
- Timer: native scheduled notification exists with exact/inexact fallback. Countdown now derives remaining time from deadline rather than counting callbacks. No force-stop guarantee; reboot session recovery still missing.
- Freestyle: fixed rendering to display remaining time; added custom 1–180 minute input; presets wrap on small screens.
- Flashcards: prompt previously still formula-only. Replaced with conceptual questions, conditions, worked examples and common errors. No live AI output acceptance yet.
- Cloud: SQL migration not applied. Do not claim cross-device sync works. Metadata writes disabled in new source; recovery backups retained.
- AI schedule: pure scheduling validator enforces sequential starts, daily budget, free-window end and next-day overflow. 3 tests pass. Existing-task collision detection and per-weekday routines NOT implemented.
- Weekly/monthly routine: NOT implemented. Current profile UI still uses a single evening interval and hardcoded daytime label.
- Schedule alarms: task identity/cancellation and scheduling after edit/sync still need reconciliation. NOT accepted.

Automated: 9 tests passed (3 scheduler + 6 core). Analyzer: no errors, remaining warnings/info. Device: Honor connected at 100.78.225.100:36163; installed original package versionCode 2015 before upgrade.

## Device run, build 2016
- ADB pm install returned Success; dumpsys confirmed versionCode=2016.
- UI hierarchy confirmed navigation bounds at y=2403..2619 on 1264x2736 (old build was y=1221..1437).
- Custom freestyle 1-minute countdown was configured through native screen and started; AlarmManager registered RTC_WAKEUP with requested +58 seconds.
- Background notification acceptance FAILED: Honor moved effective alarm delivery ~3 days out (policy --unknown(4)--). No notification id 9999 at 65 seconds. Standby bucket reported 40. Do not claim background timer delivery is reliable on this device.
- Test timer cleaned up by force-stopping and reopening app; no learning session was saved.
- Added isolated widget hit test: Today checkbox accepts taps and bottom navigation center is below y=700 at 390x844. Test initially found Today text overflow; header/subtitle wrapping fixed and retest passed.
- Total automated checks now 10 passed (9 logic + 1 widget).
- No Gemini Agent Mode session used; runtime evidence here is from ADB/UIAutomator/AlarmManager, not Artemis.

Build 2017 installed successfully via ADB; dumpsys versionName=1.2.1, versionCode=2017. Contains final wrapping fixes.

## Superseding update: build 2019 / migration applied
The items marked NOT implemented above describe the earlier audit, not current source.
- User applied 20261102_account_state.sql. Live authenticated DB reads and CAS writes succeeded; stale revision rejected. Two independently authenticated API sessions returned identical canonical state.
- Canonical profile recovered from existing metadata to database: Thành Lộc / Unicorn :vv, 105 XP, 7 stars, 1 goal, 7 tasks, 7 flashcards. No local reward totals were summed into this record.
- Build 2019 installed on Honor. Screenshot evidence: /home/ben/mochi_delivery/evidence-2019/canonical-profile-today.png.
- Weekly free/busy windows and date-specific overrides implemented in RoutineScreen. Scheduler checks busy windows, occupied task intervals, budget, deadline and future time. Four additional constraints tests pass.
- Live Groq flashcard call succeeded with conceptual explanations, conditions and formulas; evidence live-flashcards.json. Three AI prompt/response tests pass.
- Combined targeted automated checks: 17 passed. Analyzer has warnings/info, no errors.
- Background timer delivery is NOT accepted yet. Earlier build2016 alarm was delayed by Honor; subsequent attempts on2019 did not reliably start a countdown and cannot establish success. Exact-alarm switch was enabled during investigation. A count-up timer produces no completion alarm by design.
- Remaining: end-to-end phone+browser simultaneous edits, offline durable outbox/conflict recovery and full killed-process timer restoration have not passed acceptance. Do not claim the overall release is complete.
- No Gemini Agent Mode/Artemis session used; device operations were ADB/UIAutomator.

## Custom duration discoverability correction (candidate 2020)
User reports no custom input button even while stopped. Previous branch limited the control to stopped freestyle only. Replaced hidden inline action with an always-present, outlined 48dp 'Đặt thời lượng' button in both modes, including while running. Dialog validates 1–180 minutes, supports keyboard submission and Cancel. Applying stops/cancels the prior alarm and resets remaining time; it does not secretly resume. Header pills wrap and timer content scrolls on short/narrow screens. Three widget tests pass at 390×844, 320×568 and 844×390; existing 17 targeted regression checks pass. Device installation/screenshot pending until release build completes.

## Build 2020 real-device acceptance
- ADB streamed install Success, dumpsys package confirms versionName 1.2.4/versionCode 2020.
- UIAutomator confirms visible action 'Đặt thời lượng · 20 phút' at [187,548][1077,716] before start; tapping opens editable numeric dialog with Hủy/Áp dụng.
- Entered 1 minute via device keyboard; display changed to 01:00. Started countdown and observed 00:54.
- AlarmManager: requested 2026-11-02 01:36:27 device-local, window=0, exactAllowReason=permission, effective +52s (no Honor deferral this run).
- Sent HOME. Scheduled receiver posted id9999 at epoch1793558187022 (22ms after target). Notification shade shows 'Hết giờ học tập trung!' and the tested task title. Thus background notification delivery passed this run; audible sound/vibration and force-stop behavior are not established by screenshots/logs.
- Evidence: /home/ben/mochi_delivery/evidence-2020/duration-button-device.png, duration-input-device.png, alarm-start.txt, timer-notification.txt, timer-notification-device.png.
- 3 duration widget checks + 17 targeted regressions pass. Analyzer: zero errors, 46 warnings/info. Broader sync conflict/recovery acceptance still outstanding.

## Build 2022 — notification privacy, sync reliability and overlap correction
- Installed 1.2.6+2022 on Honor; published web build2022 (public main.dart.js SHA256 equals local 7577ad623baadacfbebc275c55b6a7168bd795e1a2cb5b18fbff7799df962bac).
- First-launch permission: revocation/relaunch path on build2021 showed the actual Android POST_NOTIFICATIONS dialog automatically. Permission granted via visible system button, verified granted=true. Runtime prompt is once per installation; denied users can recover in settings, not an endless permission loop. Android cannot request at APK install time before app launch.
- Client UI no longer contains test-now/test-background/FCM-copy/Firebase status/token reconnect controls. Internal push initialization remains. Removed nonfunctional sound/haptic switches; real sound/vibration customization uses OS settings.
- Navigation now restores after scroll idle and reserves space while visible. Real-device audit found Planner FAB underneath bar (old y2484..2680, overlapping nav2389..2619). Build2022 FAB y2176..2372, above nav. Tapped its actual center and opened add dialog successfully; screenshot retained.
- Sync now uses per-account caches only as offline replicas, durable unsent journal, sequential write/coalescing, optimistic CAS retries and three-way merge for disjoint field/entity changes. Offline restart and concurrent local edits tests pass. Incompatible same-field edits are kept as a visible conflict rather than silently overwritten; automatic resolution of incompatible edits is intentionally not asserted.
- Real two-way proof on phone/web: phone UI created SYNC_CHECK_2022, independent authenticated DB read found revision4 and browser UI rendered it. Browser UI created WEB_SYNC_CHECK_2022, DB revision5 and phone auto-poll rendered it. These are temporary acceptance tasks, not pre-seeded product content; cleanup required after notification test.
- Due-task reminders no longer share the 2/day, 3-hour anti-nag cap. Explicit appointments use their actual selected time (including night schedules); only optional engagement nudges obey quiet hours/caps. Both test appointments, 01:57 and 01:58, registered exact native alarms on build2022. Delivery awaiting verification.
- Calendar purple schedule indication preserved even on completed days. Flame level now calculated from that historical day's consecutive activity, not today's global streak. Existing flame visual is still a vector icon; no claim of ChatGPT-generated new raster assets.
- Full default test run: 85 passed, 2 live tests skipped. Separate enabled LIVE_AI tutor test passed with 3 actual Groq responses (1502/945/873ms). Analyzer has no errors and 46 warnings/info.
- Browser rendered verified at 1920,1366,768,390,320px; sidebar present >=768 and absent below. No pageerror events; does not establish a 60–120Hz frame-rate guarantee.
- Evidence directory: /home/ben/mochi_delivery/evidence-2022. ADB/UIAutomator used, not Gemini Agent Mode/Artemis.
