# StudyShift project status

**Updated:** 2026-11-17
**Repository:** `main`
**Current app version:** `0.1.0+20357` (personal debug build; not a release)

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

- Flutter suite: **431 passed** after the Calendar swipe, roster-date parser and narrow event-form improvements. Focused navigation, roster parsing, Work filters, and schedule-query suites passed; `flutter analyze --no-pub`: **no issues**.
- Android native unit suite: **55 passed**, with no failures or errors.
- Navigation profile: **3/3 integration tests passed**, including 24 warmed page swipes across three rounds. UI-build p90 stayed under the 16.67 ms frame budget. Emulator raster p90 was about **100–125 ms** for swipes, while the solid-page control baseline was **109 ms**; the shared raster cost makes these measurements inconclusive for app-specific smoothness, and they do not establish physical-device smoothness.
- Android permission-manifest guard passed the current release manifest and rejected a temporary manifest with an unauthorized contacts permission.
- Current emulator package: Android 16 / API 36, personal debug build `0.1.0+20357`, installed on `emulator-5554`. Today opened, and the Add Shift form rendered at the emulator's large text scale with readable Start/End dates and less bulky time controls. The form was opened and left unsaved; no schedule entries were added or changed. Calendar-to-Work swipe and active-shift behavior remain supported by the earlier `0.1.0+20354` runtime checks. Phone acceptance is paused while the Galaxy is disconnected.
- OCR import notice: the current build requires an explicit one-time confirmation before opening either OCR picker. The focused import-screen suite passed **13/13**, including cancel-before-picker and confirmed OCR import paths; `flutter analyze --no-pub` reported no issues.
- Event form refinement: narrow layouts show Start/End dates vertically with up to two readable lines instead of truncating the selected dates. Empty saved shift-code and supervisor lists now show a direct route to manage those references; loading and error states are visible. The time inputs no longer sit inside an extra nested card, reducing bulk while retaining labels and separate split intervals. Event-editor suite passed **26/26**.
- Roster-date OCR: parser suite passed **26/26** and import-screen suite passed **13/13**, including ISO dates, month-name headers, separated month/year context, invalid-date rejection, and manual confirmation of the first date. No owner roster data was copied into fixtures.
- Offline OCR investigation: a disposable Tesseract **5.5.4** prototype built an **8.2 MB** AAR for `arm64-v8a` and `x86_64`, with an embedded English model and no permissions in the library manifest. On API 36 x86_64, the fully ruled synthetic roster baseline recovered **0/10** day/date headers and **0/20** code cells. One threshold and long-gridline-removal pass recovered **10/10** headers and **16/20** exact code cells, with no false code-like words, at **1.24 s/page**. The unruled baseline also read 16/20 codes (**1.40 s/page**). Remaining `A1` cells were misread as `Al`; a focused PSM 8 uppercase/digit whitelist read only `A`, so it did not improve recognition. The candidate is **not integrated or accepted** until roster accuracy, dependency security, and privacy review pass.
- Startup: splash tests passed **11/11**. The branded intro now matches its **1.2 s** animation; slow local startup then shows a clear loading state until schedule data is ready. Cold personal debug launches on `emulator-5554` previously reported **5.38–9.51 s**. A profile-build run reported **4.00 s** from `am start -W` and Android logged the activity as displayed at **4.276 s**; a debug-build run reported **9.576 s**. After installing `0.1.0+20357`, the first debug launch reported **17.138 s** from `am start -W` and Android logged display at **18.071 s**; a subsequent force-stop launch reported **6.113 s**. All measured cold launches remain above the three-second specification target and vary substantially. No crash was logged and Today rendered, but the measurements do not yet identify a safe source-level bottleneck or establish timing on release hardware; startup performance remains open.
- Public source snapshot is on `origin/main`. Private device notes, owner schedule data, signing material, generated APKs, and runtime screenshots are excluded.

## Open gates

1. **Galaxy acceptance:** The physical Galaxy is disconnected. Reconnect it before device acceptance. The owner's existing roster must remain unchanged.
2. **OCR privacy:** Google confirms ML Kit processes the image and recognized text on-device, but its Android SDK sends technical diagnostics and usage metrics. StudyShift requires a one-time, per-import disclosure and confirmation before opening an OCR picker; schedule content and recognition output are not sent. Confirm the final product disclosure/data-safety treatment against the project's no-telemetry-by-default policy. The offline alternative still needs a current, security-reviewed Android build and model review.
3. **Signing and update:** Release key custody remains owner-controlled. A signed APK and retained-data update test are not available until that gate is completed.

## Completion statement

The local implementation and emulator work are substantially complete, but the project is **not at 100% acceptance**. Physical Samsung acceptance and the two release-readiness gates above remain open. No release, store publication, cloud service, or production integration is claimed.
