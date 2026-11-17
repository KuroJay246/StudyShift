# StudyShift project status

**Updated:** 2026-11-17
**Repository:** `main`
**Current app version:** `0.1.0+20353` (personal debug build; not a release)

This report distinguishes implementation and emulator evidence from physical-device and release acceptance. Percentages below are planning estimates, not pass rates or a claim that the app is production-ready.

## Phase checklist

| Phase | Estimate | Implemented and locally verified | Remaining acceptance |
| --- | ---: | --- | --- |
| 1. Offline alpha foundation | 100% | Flutter Android app, local schedule storage, approved five-destination navigation, theme support, and Android integration are implemented. Source checks and the personal emulator build pass. | Galaxy installation and device-specific checks are still outstanding. |
| 2. Today, calendar and planning | 93% | Today weather/location card supports whole-hero horizontal location swipes; local-day greeting and weather presentation are time-zone aware; Week and Month views, selected-day agenda, overlap grouping, and destination swipe navigation are implemented. | Measure gesture smoothness on Galaxy and review live schedule rendering, accessibility, and screen scaling. |
| 3. Work and study workflows | 88% | Work summary and filters, distinct Study empty states, grouped event forms, saved shift-code references, and searchable legend details are implemented. The main Add sheet now offers Work shift, Class, Assignment, and Examination. Regression tests cover core scheduling and navigation behavior. | Review forms and real saved roster rendering on Galaxy. Verify code-to-flight details only from owner-provided definitions; do not infer missing assignments. |
| 4. Import and backup | 92% | ICS/CSV/XLSX import paths, export, offline PDF OCR flow, import history, and validated local backup/restore are implemented. Roster-table OCR recognizes numbered and full ISO-date headings and pre-fills the first date for review. | Complete Galaxy document-picker and restore acceptance plus broader malformed/large-file edge review. |
| 5. Android integrations and widgets | 90% | Local reminder, persistence and widget bridges are implemented; five widget families and resize behavior have emulator coverage; Work widget destination routing is covered. | Review One UI widget sizing/refresh, notification and battery behavior, accessibility, and the configured Samsung Calendar handoff. |
| 6. Readiness and distribution | 84% | Dependency review, Gradle distribution checksum pin, release-signing preflight, and merged-manifest permission guard are in place. | Resolve OCR telemetry against the no-telemetry requirement; complete owner-controlled signing and signed-update review. No release artifact is approved by this report. |

## Verification evidence

- Flutter suite: **424 passed** before this Add-sheet change; the Add-event and shell-navigation suites passed **20/20** after it. `flutter analyze --no-pub`: **no issues**.
- Android native unit suite: **55 passed**, with no failures or errors.
- Navigation profile: **3/3 integration tests passed**, including 24 warmed page swipes across three rounds. UI-build p90 stayed under the 16.67 ms frame budget. Emulator raster timings were noisy, so this is not proof of physical-device smoothness.
- Android permission-manifest guard passed the current release manifest and rejected a temporary manifest with an unauthorized contacts permission.
- Current emulator package: Android 16 / API 36, personal debug build `0.1.0+20353`. It installed on `emulator-5554`; the Add sheet and Examination editor were opened successfully. No phone was connected and no schedule entries were added or changed. Phone acceptance is paused while the Galaxy is disconnected.
- OCR import notice: the current build requires an explicit one-time confirmation before opening either OCR picker. The focused import-screen suite passed **13/13**, including cancel-before-picker and confirmed OCR import paths; `flutter analyze --no-pub` reported no issues.
- Roster-date OCR: parser and import-screen regression suites passed **34/34**, including explicit ISO dates across a month boundary, merged weekday/date headers in either order (`Mon 16`, `16 Mon`), and automatic first-date prefill. No owner roster data was copied into fixtures.
- Startup: splash tests passed **11/11**. The branded intro now matches its **1.2 s** animation; slow local startup then shows a clear loading state until schedule data is ready. Cold personal debug launches on `emulator-5554` reported **5.38–9.51 s** to Android's displayed-activity marker, with Today visible in the following capture; this does not establish the design spec's three-second maximum on release hardware.
- Public source snapshot is on `origin/main`. Private device notes, owner schedule data, signing material, generated APKs, and runtime screenshots are excluded.

## Open gates

1. **Galaxy acceptance:** The physical Galaxy is disconnected. Reconnect it before device acceptance. The owner's existing roster must remain unchanged.
2. **OCR privacy:** The current on-device ML Kit path reports performance/utilization metrics. That behavior has not been shown to meet the project's no-telemetry rule. An offline alternative also needs a current, security-reviewed Android build and model review.
3. **Signing and update:** Release key custody remains owner-controlled. A signed APK and retained-data update test are not available until that gate is completed.

## Completion statement

The local implementation and emulator work are substantially complete, but the project is **not at 100% acceptance**. Physical Samsung acceptance and the two release-readiness gates above remain open. No release, store publication, cloud service, or production integration is claimed.
