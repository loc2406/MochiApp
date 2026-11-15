# MOCHI 1.2.7 (2023) — acceptance evidence

## Installed and published
- Honor Android device: ADB 100.78.225.100:36163, package com.mochi.study.mochi_app. Install Success; package manager confirms versionCode2023, versionName1.2.7; POST_NOTIFICATIONS granted.
- APK: /home/ben/mochi_delivery/mochi-1.2.7-2023-arm64.apk
- APK SHA256: ecde26a283fa1c8656c3319bd9aa294fb7acdf37d09cd5aaea68dd2261b3ec51
- Website: https://bendocs.tailc1f51b.ts.net/mochi/
- Download: https://bendocs.tailc1f51b.ts.net/slide/mochi-app.apk
- Published JS SHA256 matches local: dc1089d11ecbd9d1664f7148c067971248099f34855f2e5c76d31e00533d8d3e

## Requested fixes and evidence
| Area | Implementation and verification |
| --- | --- |
| Permission | Actual Android permission sheet appears automatically on first launch if not granted. Verified on phone by revoking then launching, allowing using visible native button, and checking OS grant. One prompt per install; denied users have a settings recovery action. No permission request can run before first launch at APK install time. |
| Client privacy | Removed test-now, test-background, FCM-copy, Firebase status and reconnect UI. Internal transport remains operational. Widget assertions verify no developer strings. Real phone settings screenshot retained. |
| Floating bar | Restores after scroll idle/tab change. Body reserves clearance while bar visible. Planner FAB previously overlapped navigation; real phone now shows FAB y2176–2372 above nav y2389–2619, center tap opens add dialog. |
| Today checkbox | Physical tap on disposable task updated UI and real database, including expected +1star/+30XP. Test task and its rewards were removed afterward; canonical profile and totals preserved. |
| Timer | Native OS alarm scheduled before starting countdown, errors are surfaced. Countdown uses a deadline, freestyle elapsed uses wall time; custom1–180 minute input always visible. Completion duration is no longer derived from background callback count. Native completion tested previously; final2023 retest recorded separately. |
| Flashcards | Concept/conditions/meaning/examples prompt + LaTeX rendering tests. Previous live Groq Pythagoras response evidence retained in evidence-2019/live-flashcards.json. |
| Sync | Canonical Thành Lộc / Unicorn :vv loaded from DB, not auth metadata. Phone-created task appeared on web; web-created task appeared on phone through automatic refresh. Per-account replicas, durable offline journal, disjoint three-way merge, serialized writes and CAS. New accounts start empty, not another user's cache. |
| AI schedule notifications | Exact OS alarms and actual deliveries for two temporary tasks at01:57 and01:58, respectively +29ms/+20ms from target in notification timestamps. Independent due-task appointments are not suppressed by engagement reminder limits. Tests used explicit temporary appointments, not claimed as AI-generated. |
| Routine and AI plan | Weekday availability/busy windows and date overrides persist in account state. Scheduler checks availability, existing tasks, daily budget and deadlines. Real AI planner preview on2023 showed dated tasks Nov2/3/4/5 at19:30 with45min allocations; repeated clock time belongs to different dates, not overlapping tasks. Preview dismissed without modifying user's plan. |
| Calendar | Scheduled dates remain purple even with activity. Historical streak counts come from activity ending on that day, not the current streak. Existing flame artwork remains a vector icon; no claim of new ChatGPT-rendered raster assets. |
| Web | Verified browser render at1920/1366/768/390/320px, sidebar >=768, mobile navigation below. No captured pageerror events. No frame-rate guarantee inferred from screenshots. |

## Tests
- Full final default run:91 passed,2 live-only tests skipped.
- Separate enabled live tutor acceptance:3 real Groq responses, HTTP200, completed output, ~1502/945/873ms.
- Analyzer:0 errors;47 warnings/info remain. Not a clean analyzer claim.
- Evidence directory: /home/ben/mochi_delivery/evidence-2023 (prior device-step artifacts retained in evidence-2020/2021/2022).

## Limits, not completion claims
- Debug was ADB/UIAutomator/AlarmManager, not Gemini Agent Mode/Artemis.
- Conflicting edits to the same scalar field are retained and reported rather than silently choosing a winner. Offline recovery/disjoint edits tested; no claim of universally automatic semantic conflict resolution.
- HOME/background notifications tested. Android force-stop semantics and every manufacturer power-management mode are not guaranteed.
- SQL migration already applied and live DB CAS verified. No current server is used as a personal database backend.
- Temporary acceptance tasks and their reward side effects were removed; cleanup revision8 confirmed7 original tasks and unchanged canonical identity/reward totals.

## Final build2023 timer retest
Custom1min countdown confirmed00:54 on phone, then HOME. Native receiver posted id9999 at epoch1793559893022 with title 'Hết giờ học tập trung!' and correct task text. Final-build background delivery passed. Resumed and dismissed completion without saving test study rewards. App-only log retained as evidence-2023/timer-background-app-only.txt.
