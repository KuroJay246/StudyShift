# StudyShift Samsung Galaxy S23 FE compatibility report

## Latest acceptance checkpoint — 15 November 2026, v8240 update only

- **VERIFIED ON DEVICE — package update:** Galaxy S23 FE `SM-S711B` was connected and unlocked. The installed `app.shiftstudy.mobile` package upgraded in place from versionCode **10239** to **10240**, versionName `0.1.0`. The device previously verified as Android 16/API 36 with One UI 8.5; those OS values were not re-read in this check.
- **VERIFIED BY EMULATOR — Work legend:** on API 36 emulator `emulator-5554`, v0.1.0+8240/versionCode **12240** opened More → Work → Shift code legend. The code reference screen displayed the intended usual-time/flight-duty explanation and its “No shift codes saved” state. Work showed Shifts and Days Off as distinct filters.
- **BLOCKED ON DEVICE — visual acceptance:** after the in-place upgrade, StudyShift's launcher activity was resumed, but Android window focus reported WhatsApp and a floating WhatsApp bubble obscured the Today screen. To honor the owner’s boundary, no WhatsApp UI was opened, moved, or dismissed; phone interaction stopped. Galaxy v8240 Today layout, Work legend route and widget appearance therefore remain **NOT VERIFIED**. No schedule record was edited.
- **SOURCE CHECKS:** two focused Work legend widget tests passed; full Flutter suite **309 passed**; `flutter analyze --no-pub` clean; focused Kotlin widget tests and `git diff --check` passed.
- **BUILD IDENTITY:** ARM64 personal debug APK SHA-256 `D6F3C2A068D7B3C7BD4CF7508817E97D5D576B0C531A5937D487C47B03ADD0D9`, 110,247,940 bytes; x86_64 personal debug APK SHA-256 `98C476395AE510EFCC4AE67C62B46CD97BB17FB9731A50B345DC00F22C69448B`, 96,790,140 bytes. Neither is release-signed or distributed.
- **NEXT DEVICE STEP:** when the phone is clear of the WhatsApp overlay and StudyShift is visible, finish only the app acceptance: Today/Work/legend navigation and required Samsung widget/reminder checks. Avoid accessing other apps or device settings.

The v8239 and earlier records below are historical; they do not supersede this v8240 update-only result.

## Latest acceptance checkpoint — 15 November 2026, v8239

- **VERIFIED ON DEVICE:** Galaxy S23 FE `SM-S711B`, Android 16/API 36, One UI 8.5 (from the preceding verified device read). StudyShift `app.shiftstudy.mobile` was updated in place to v0.1.0+8239, versionCode **10239**. It was launched and left on Today.
- **PASS — compact class widget empty state:** the existing Next Class widget showed a concise “No classes yet” state with a short add hint, fitting the compact tile without the previous multi-line oversized copy. Tapping it opened the Study destination. This was an empty-state and tap-routing check; populated projection, refresh after an event edit/date rollover, resize behavior and Samsung appearance controls were not tested.
- **PARTIAL — widget appearance:** the text hierarchy now fits the observed Samsung tile, while the plain dark card still needs comparison/refinement against the approved branded concept. No widget setting or home-screen placement was changed.
- **VERIFIED BY SOURCE AND EMULATOR:** 309 Flutter tests passed, analysis was clean, and focused Kotlin widget family/layout tests passed. API 36 emulator `emulator-5554` reports versionCode **12239**; its portrait home screen also rendered the compact empty state. This does not substitute for Samsung evidence.
- **BUILD IDENTITY:** ARM64 personal debug APK SHA-256 `FB499929EF6E4862DB6A035CFF60AF9445415547E1D66FDB8E185CDA6D8FBF8B`; x86_64 APK SHA-256 `09D82AE43E8EC83FD27039587380E538897A3BAAC7064C9E529F32A7A5A35C08`. Neither is release-signed or distributed.
- **BOUNDARIES:** no schedule event was added, edited or deleted. No phone settings, routines, Gallery or WhatsApp were opened. The test Next Class widget remains on the home screen. StudyShift was left on Today. Temporary screenshots containing device UI were removed after inspection.

The v8238 and earlier records below are historical; they do not supersede this v8239 result.

## Latest acceptance checkpoint — 15 November 2026, v8238

- **VERIFIED ON DEVICE:** `RZCX521DWZF`, Galaxy S23 FE `SM-S711B`, remains connected as an Android 16/API 36 device; One UI 8.5 was established in the preceding device check. StudyShift `app.shiftstudy.mobile` was upgraded in place and reports versionCode **10238** (v0.1.0+8238). It launched and was left foregrounded after a cold relaunch. The destination after tapping the widget could not be confirmed from the available Android accessibility hierarchy.
- **WIDGET VISUAL CHECK — FAIL / FOLLOW-UP REQUIRED:** One UI Home showed a StudyShift class-focused widget with its empty class projection (“No upcoming classes” and “No upcoming events”). The fixed-family projection correction is included in this build. The empty content is rendered on a plain dark card with oversized copy relative to the approved design; the widget visual does not pass owner acceptance. This screenshot-only check does not establish populated class/deadline content, widget resizing, appearance/transparency controls, tap routing, or refresh after an edit/date rollover.
- **SOURCE/EMULATOR EVIDENCE:** Flutter suite **309 passed**; `flutter analyze --no-pub` clean; focused native `WidgetFamilyConfigurationTest` passed. Separate API 36 emulator `emulator-5554` reports versionCode **12238** and launched the same v8238 source build. Emulator behavior is not treated as Samsung acceptance.
- **BUILD IDENTITY:** ARM64 personal debug APK SHA-256 `A32CABE8E99941299057008315FE6783E2A5E076839F4FCFA87EEF4884DEF1C8`; x86_64 APK SHA-256 `DB544CD8806B6665C2E25EEF8B3C5ED1F2916C7B295FC5627BDFB9CDCF3874B6`. Neither is release-signed or published.
- **BOUNDARIES:** no event was added, edited, or deleted; no device settings, routines, Gallery, or WhatsApp were opened. The temporary Next Class test widget remains on the home screen for owner review; it was not moved or removed. StudyShift was left foregrounded after its cold relaunch.

The v8236 and v8235 sections below are historical checkpoints. They are not current-build evidence and do not supersede this v8238 result.

**Checked:** 15 November 2026
**Target:** Galaxy S23 FE (SM-S711B), One UI 8.5, Android 16
**Galaxy package currently installed:** `app.shiftstudy.mobile` 0.1.0+8236, Android versionCode 10236, target API 36, personal ARM64 debug APK, SHA-256 `0D204A137171A23DDDA534C42D2D23577CE509966BD8D02A313E0EF058E64924`
**Latest Galaxy acceptance:** v8236 installed in place; Today, Week, Work, Study and More tabs selected correctly; previously saved schedule remained present; existing Samsung-hosted widget configuration opened, scroll exposed the Classes and Deadlines filters, and Cancel exited without saving.
**Scope:** Current v8236 physical-device observations are recorded below. The detailed v8235 record remains historical. No phone settings/routines were changed, and Gallery and WhatsApp were not opened.

## Current Galaxy acceptance — 15 November 2026, v8236

- **VERIFIED ON DEVICE:** Galaxy S23 FE `SM-S711B`, Android 16/API 36, One UI property `80500` (8.5). StudyShift package `app.shiftstudy.mobile`, version `0.1.0`, versionCode `10236`, target API 36; `lastUpdateTime` advanced to `2026-11-14 23:48:47`. The APK was installed with `adb install -r`, preserving the package and its app data. The saved schedule remained present afterward; its personal details are intentionally omitted.
- **PASS — primary navigation:** Android accessibility hierarchy confirmed selected Today, Week, Work, Study and More tabs on the installed v8236 app. The app remained foregrounded during the checks.
- **PASS — native widget configuration:** Android AppWidgetManager identified the existing StudyShift `ScheduleWidgetProvider` hosted by One UI Home. StudyShift's own configuration Activity opened for its existing widget ID. The screen exposed Next Event 2×2, Today 4×2 and This Week 4×1 layouts; All, Work shifts, Study, Classes and Deadlines content filters; and System, Light, Dark, Glass and Transparent appearances. A horizontal swipe revealed the off-screen Deadlines chip. The selection was not saved; Cancel returned to Today. This proves configuration UI routing and available controls, not One UI rendered widget resizing, refresh, transparency behavior or appearance fidelity.
- **VERIFIED BY EMULATOR, NOT GALAXY:** on isolated review flavor `app.shiftstudy.mobile.review` / emulator `emulator-5554`, synthetic schedule persistence through SQLite and widget snapshot passed, as did Android delivery and removal of a synthetic local reminder. Galaxy reminder delivery remains untested.
- **REQUIRES TESTING ON GALAXY:** home-screen widget rendering and resize across sizes, saved-widget live refresh after schedule edits, Samsung alarm delivery and battery restrictions, landscape and large text, calendar handoff, launcher icon masking/size comparison, cold-start splash and theme changes. No Samsung-specific pass is claimed for these.
- **BUILD IDENTITY:** personal debug ARM64 APK SHA-256 `0D204A137171A23DDDA534C42D2D23577CE509966BD8D02A313E0EF058E64924`; the matching local x86_64 emulator APK is `77D6C586FF1B2E5C13943B4F6CBFD5784778B57475530B5A67AE699CC7127B0F`. Debug builds are not release-signed.
- **BOUNDARIES:** no schedule record was created, edited or deleted on the Galaxy; widget configuration was canceled. No phone settings, launcher layout, routines, Gallery or WhatsApp were accessed.

## Current Galaxy acceptance — 14 November 2026, v8235

- **VERIFIED ON DEVICE:** `SM-S711B`, Android 16/API 36, One UI property `80500` (8.5), firmware `BP4A.251205.006.S711BXXSJGZI6`, security patch `2026-10-05`, One UI Home `17.5.05.29`, display `1080×2340` at 450 dpi, font scale 1.0, gesture navigation. StudyShift installed in place as `app.shiftstudy.mobile` 0.1.0+8235 / versionCode 10235 / target SDK 36. `lastUpdateTime` advanced to `2026-11-14 22:44:21`; existing schedule content was still present after the update and app restart.
- **PASS — navigation and Today:** Today, Week, Work, Study and More opened and rendered. The app was returned to Today at the end. Work and Study exposed their relevant sections; schedule/event details remained readable and scrollable on this portrait device.
- **PASS — weather location switching:** Today began with the saved Grantley Adams International Airport location. A left swipe on the weather control changed it to Bridgetown; a right swipe restored the original airport location. After force-stop and relaunch, the airport location remained selected. The selection was intentionally restored; no location preference was left changed.
- **PASS — weather details:** tapping the weather summary opened the detail sheet with condition, temperature, feels-like, rain chance, wind, sunrise/sunset and hourly forecast, plus a refresh action. Approximate location permission is granted; fine location is ignored. No permission or device setting was changed.
- **PASS — non-destructive Work form smoke:** Add Shift opened, the form scrolled through time, split-interval, repeat and optional detail fields, and the blank form was canceled without saving. No schedule record was added or edited during acceptance.
- **PASS — event details:** opened an existing Work event's detail sheet to inspect its type, state, date/time, local timezone and optional roster details, then dismissed it. Edit, finish, delete and calendar actions were not invoked; its personal contents are not repeated here.
- **PASS — One UI widget configuration route:** read-only AppWidgetManager inspection found one existing `ScheduleWidgetProvider` instance hosted by `com.sec.android.app.launcher`, sized by One UI at about 4×2 cells (334×180 dp). The StudyShift-owned configuration activity opened for that instance and showed the live preview, Next event / Today / This week layouts, Next event / Work shifts / Study content options, and System / Light / Dark / Glass / Transparent appearance choices. Cancel was selected; the existing widget configuration and home-screen placement were left unchanged. Actual launcher-rendered content, resize, transparent-background readability and refresh remain unverified.
- **VERIFIED ON DEVICE:** notification permission is granted and the app's Notifications page reports notifications on. Exact reminder timing is off; the app reports exact timing disabled and Android may delay reminders. `SCHEDULE_EXACT_ALARM` had no recorded app-op and default mode. Real reminder delivery was not triggered on the owner's schedule. No battery exemption was requested or added.
- **NOT CONCLUSIVE — Galaxy launch/splash:** captures at 180 ms, 650 ms and 1.5 s showed only the Android native S-mark splash, before the Flutter surface was observed. Later Galaxy launch frames were not captured because the foreground returned to One UI Home, so these captures do not prove a Flutter composition defect. Emulator v12235 captures show the native splash at 2.4 and 2.95 s, the branded Flutter splash with wordmark/tagline at 3.5 s, then Today by 4.05 s. The Flutter composition is present; cold-start time is slower than the design target and needs profiling. Light-mode splash and Galaxy Flutter-splash timing remain unverified.
- **Galaxy UI acceptance stopped at foreground boundary:** a later direct launch attempt returned to One UI Home and the focused window became null; no additional app-screen evidence was collected. Five resulting screen captures were excluded and moved, without deletion, to `app/build/qa/_OWNER_DELETE_REVIEW_2026-11-14` with manifest entries. Continue device acceptance only when StudyShift is visibly foreground on the unlocked phone.
- **PASS — runtime stability for exercised flow:** app stayed foreground through navigation, weather location changes, form open/cancel and cold relaunch; Android crash buffer had no entries at check end.
- **PASS — current source regression checks:** `..\tool\dev.ps1 test --no-pub` completed with 307 tests passing; `..\tool\dev.ps1 analyze --no-pub` completed with no issues. These are source checks, not additional device acceptance. Drift emitted its existing multiple-test-database debug warning during tests.
- **REQUIRES TESTING ON GALAXY:** installed One UI widget rendering, resizing, configuration persistence and refresh; landscape/window resizing; large-font stress; real reminder delivery and Doze/Battery Saver; calendar handoff; Samsung Modes and Routines; launcher icon mask/size comparison; light-mode splash; Galaxy cold-start timing. The home-screen layout was not changed to add/remove widgets.

The current evidence is a focused physical-device acceptance smoke test, not full Galaxy release acceptance. Current screenshots and UI hierarchy dumps are local, ignored QA artifacts under `app/build/qa`; schedule text is not copied into this report.

## Historical read-only and app-screen follow-up — 8 November 2026, v79

- **VERIFIED ON DEVICE:** model `SM-S711B`, Android 16/API 36, One UI property `80500` (8.5), firmware incremental `S711BXXSJGZI6`, security patch `2026-10-05`, One UI Home `17.5.05.29`, physical display `1080×2340` at 450 dpi (derived logical size 384×832 dp), font scale 1.0, gesture-navigation mode.
- **VERIFIED ON DEVICE:** StudyShift v79 (`app.shiftstudy.mobile`, target API 36) is installed and launched. Today and all five navigation destinations were visible. The Add Class form showed the class name prompt, Study color control, local date, reminder, 10:00–11:30 defaults, weekly-repeat controls, optional course-code field, time-zone details and Save event action. The unsaved form was canceled and Today restored.
- **VERIFIED ON DEVICE:** `POST_NOTIFICATIONS` is granted. `SCHEDULE_EXACT_ALARM` app-op reports no recorded operation and default mode, so effective exact-alarm authorization remains UNKNOWN. The package is not listed in the device-idle whitelist; no battery exemption was added.
- **VERIFIED ON DEVICE:** One 4×2 `ScheduleWidgetProvider` instance is registered with `com.sec.android.app.launcher` (One UI Home). Opening the configuration Activity for that widget ID succeeded on One UI 8.5. Its selectable widget styles were Next event / Today / This week; content was All / Work shifts / Study; appearance was System / Light / Dark / Glass. The configuration was canceled without saving. The widget's launcher rendering, transparency controls, resize, taps and schedule refresh remain untested on Galaxy.
- **VERIFIED ON EMULATOR:** v79 renders Today and the empty Month view. In landscape it uses a navigation rail, keeps the Today composition and Week/Month controls visible, shows all seven weekday headers, and opens the Week grid around 6 AM. The emulator's original automatic rotation and portrait state were restored.
- **REQUIRES TESTING ON GALAXY:** One UI Home icon comparison and alias refresh; Samsung widget appearance/configuration/tap/refresh; real reminder delivery and battery behavior; landscape and large-text screens; calendar handoff; Modes and Routines. Emulator results do not substitute for these.

## Evidence labels

The current v8236 status and checks are recorded above. Detailed device observations and test rows farther below include earlier version checkpoints; those version-specific rows are historical and do not supersede the v8236 facts above.

- **VERIFIED ON DEVICE** — read from the connected Galaxy or exercised on its installed StudyShift build.
- **VERIFIED ON EMULATOR** — exercised on the separate StudyShift API 36 emulator, with synthetic data.
- **SUPPORTED BY DOCUMENTATION** — supported by the linked Samsung/Android primary source.
- **REQUIRES IMPLEMENTATION** — the platform allows it, but StudyShift does not yet provide it.
- **REQUIRES TESTING** — not yet established on this target.
- **UNKNOWN** — cannot be established from the available read-only evidence.

## 1. Device and software

| Item | Finding | Evidence |
|---|---|---|
| Model | Samsung Galaxy S23 FE, model `SM-S711B`, device `r11s` | VERIFIED ON DEVICE |
| Chipset | Samsung SoC identifier `s5e9925` (Exynos 2200 family); 7,469,728 kB total memory reported | VERIFIED ON DEVICE; Samsung also publishes Exynos 2200 for the international variant |
| Android | Android 16, API 36 | VERIFIED ON DEVICE (`ro.build.version.release`, `ro.build.version.sdk`) |
| One UI | 8.5; Samsung property `ro.build.version.oneui=80500` | VERIFIED ON DEVICE |
| Firmware build | `BP4A.251205.006.S711BXXSJGZI6` | VERIFIED ON DEVICE |
| Security patch | 2026-10-05 | VERIFIED ON DEVICE |
| One UI Home | 17.5.05.29 | VERIFIED ON DEVICE |
| Physical display mode | 1080 × 2340 px at 450 dpi; approximately 384 × 832 dp | VERIFIED ON DEVICE; derived logical size |
| Font scale | 1.0 | VERIFIED ON DEVICE |
| Navigation | Gesture navigation is indicated by the device's navigation mode and gesture bar | VERIFIED ON DEVICE |
| Current StudyShift package | `app.shiftstudy.mobile`, version 0.1.0+8235, versionCode 10235, target API 36; app launches | VERIFIED ON DEVICE (14 Nov 2026; details above) |
| Notification permission | `POST_NOTIFICATIONS` granted | VERIFIED ON DEVICE; no setting changed |
| Exact-alarm access | Current Notifications page reports exact timing off; `SCHEDULE_EXACT_ALARM` app-op had no recorded operation and default mode | VERIFIED ON DEVICE (exact reminder timing disabled) |
| Battery exemption | Not listed in `dumpsys deviceidle whitelist`; no exemption was added | VERIFIED ON DEVICE (allowlist status) |
| Apps-screen grid | 5 × 5 (One UI Home labels it “by Home Up”) | VERIFIED ON DEVICE from One UI Home settings |
| Home/Apps layout | “Home and Apps screens” layout selected | VERIFIED ON DEVICE |
| App icon-size control | One UI Home's “App size on Home and Apps screens” slider reports value `2`; its scale bounds/physical icon size were not exposed by the read-only view | VERIFIED ON DEVICE (value); scale interpretation UNKNOWN |
| Existing StudyShift widget | One widget instance was already registered with One UI Home; host options report approximately 371 × 199 dp, spanning 4 columns × 2 rows. This instance predates the audit | VERIFIED ON DEVICE |
| Modes and Routines app | Installed as `com.samsung.android.app.routines`, version 5.0.04.1. Existing routine contents were not opened | VERIFIED ON DEVICE (package/version) |
| Home-screen grid, icon-shape preference, themed-icon preference, screen-zoom slider | Not obtained from the visible Home screen settings page; no launcher settings were changed | UNKNOWN |

Samsung's published Galaxy S23 FE specification lists Exynos 2200, FHD+ 1080 × 2340, adaptive 120 Hz, and 8 GB RAM for the international model family. Regional variants differ; this report uses the handset's observed `SM-S711B` identifier and does not assert that every variant shares its chipset. [Samsung Galaxy S23 FE specifications](https://www.samsung.com/uk/support/mobile-devices/specifications-for-the-new-galaxy-s23-fe/)

## 2. Launcher identity and icon audit

### Source findings

- The installed app label is **StudyShift** and the package uses `@mipmap/ic_launcher`.
- The Android 13+ adaptive icon is correctly declared with background, foreground and monochrome layers.
- The two inspected source layers are 1024 × 1024 PNGs. Their nontransparent artwork bounds are x=232…791 and y=205…818, or approximately 55% of canvas width by 60% of canvas height. The S artwork itself therefore stays inside Android's 66 dp safe zone on a 108 dp adaptive-icon canvas, with little spare vertical margin.
- Android's guidance specifies a 108 × 108 dp layer and a centered 66 × 66 dp area that must remain visible under OEM masks. A monochrome layer supports compatible themed-icon rendering. [Android adaptive-icon guidance](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
- The rounded blue backing is the adaptive background layer. Its appearance can read as a full, boxy tile depending on the launcher mask, icon-shape setting and the artwork's visible area; that is not evidence that the foreground exceeds Android's safe zone.

### Device comparison result

**REQUIRES TESTING:** A clean comparison of the StudyShift icon beside Samsung Calendar and Clock under the same One UI Home grid settings was not obtained. I observed the currently selected app-icon-size slider value (`2`) and Apps-screen grid (`5 × 5`, by Home Up) in the launcher settings without changing them. An attempted launcher capture exposed unrelated personal home-screen content, so that exact capture was removed from the phone and working folder and is not retained in this report. No personal content was included here.

### Recommendation

Preserve the approved blue S. Do not redraw or shrink it based only on the emulator splash image or on its source dimensions. On the Galaxy, compare the installed app in the Apps screen beside Samsung Calendar and Clock with the current grid/icon settings unchanged. If it is visibly larger, measure the actual masked art and compare icon bounds under the same launcher layout before changing the foreground PNG. Acceptance should require consistent apparent size at home and Apps screen, no mask clipping across Samsung's available shapes, correct light/dark appearance, and a legible themed icon.

## 3. Widgets and One UI controls

### What Samsung/Android support

Samsung documents that, for widgets exposing those options, One UI can offer resizing, a background color, transparency, and widget-specific settings. Availability varies by widget; these are launcher controls and do not automatically imply that an app can configure arbitrary widget content. Samsung also documents widget stacks. [Samsung Galaxy widget guide](https://www.samsung.com/ca/support/mobile-devices/use-widgets-on-your-galaxy-phone/)

Android app widgets use `AppWidgetProviderInfo`, a provider and `RemoteViews`. A configuration activity is the supported route for per-instance content/preferences, and Android 12+ supports responsive layouts for reported sizes. Periodic `updatePeriodMillis` delivery cannot be more frequent than every 30 minutes; user-triggered and system broadcasts are separate update paths. [App widgets](https://developer.android.com/develop/ui/views/appwidgets), [responsive layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts), [widget update limits](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo)

### Current StudyShift implementation

- **VERIFIED IN SOURCE:** One native `AppWidgetProvider` (`ScheduleWidgetProvider`) renders from StudyShift's locally saved schedule projection; it does not call a cloud service.
- **VERIFIED IN SOURCE:** The provider handles date, time and time-zone changes; schedule edits trigger projection updates. It uses `RemoteViews` for responsive layouts from host-provided size options and has compact/short-wide thresholds.
- **VERIFIED IN SOURCE:** Metadata allows horizontal and vertical resizing, starts at 110 dp, targets 2 × 2 cells, and requests a 30-minute update interval.
- **VERIFIED IN SOURCE:** The widget opens StudyShift's main activity. It has stale/unavailable/empty states. It does not fetch fresh data while in the launcher; it refreshes from the saved local projection.
- **VERIFIED IN SOURCE:** The v79 configuration stores widget style (Next Event, Today, This week), content filter (All, Work shifts, Study), and appearance (System, Light, Dark, Glass) independently by widget ID. The provider supports Android size options and requests the platform's minimum 30-minute periodic update interval; schedule changes and date/time/time-zone broadcasts also trigger refreshes.
- **VERIFIED ON DEVICE:** One existing StudyShift instance is hosted by One UI Home at about 371 × 199 dp (4 × 2 cells). Its configuration Activity opened for that actual widget and displayed all three style choices, all three content choices and all four appearance choices. The configuration was canceled without saving. Its schedule content was not read.
- **REQUIRES IMPLEMENTATION:** The current content choices are StudyShift's local work/study events, not selection of external Samsung/Google calendars. Independent Work/Study layout styles, assignments/deadlines-only filters, and user-selected solid/transparent background controls are not implemented in StudyShift's configuration.
- **REQUIRES TESTING:** Samsung rendering, resize behavior, host-applied background/transparency, widget stacking, populated/empty refresh, restart/date rollover and tap destination. No settings were saved and no launcher widget was moved or resized in this check.

### Recommended widget sequence

1. Keep the existing native provider and per-widget configuration. Extend only after Samsung runtime checks identify a real gap; do not duplicate system calendar access or place schedule titles in shared external storage.
2. The current provider offers Next Event, Today and Week styles with All, Work and Study filters. Verify each on the Galaxy before adding more widget modes.
3. Keep host color/transparency behavior a Samsung-provided enhancement, not a cross-device guarantee. Add user-controlled solid/transparent options only if Samsung's host controls do not meet the product requirement and accessibility contrast can be maintained.
4. Verify 2×2, 4×2 and larger sizes in the emulator, then check Galaxy resizing and appearance while preserving the existing widget placement.

## 4. Notifications and reminders

- Android 13+ requires runtime notification permission for ordinary notifications. `POST_NOTIFICATIONS` is currently granted on this Galaxy; actual v79 reminder delivery was not tested. [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- StudyShift declares `SCHEDULE_EXACT_ALARM`; Android treats it as special access that the user/system can revoke. The app's form already warns that Android may delay reminders when exact alarms are not allowed. Request this access only when the user chooses a reminder that requires it, explain the reason, and retain an inexact/fallback behavior where acceptable. [Android alarms](https://developer.android.com/develop/background-work/services/alarms)
- The app is not listed in the device-idle whitelist; no battery exemption was added. Notification channels, lock-screen privacy, Do Not Disturb, Battery Saver, sleeping-app restrictions, boot recovery and reminder delivery across time-zone changes were not exercised on the Galaxy.
- Android 16 Live Updates are intended for active, user-initiated, time-sensitive activities; Android documentation explicitly excludes upcoming calendar events. They are not a fit for ordinary future shift/class reminders. [Android Live Updates](https://developer.android.com/develop/ui/views/notifications/live-update)
- **REQUIRES IMPLEMENTATION/TESTING:** Verify per-event deep links, notification categories and safe lock-screen content on the emulator with synthetic schedules. Do not ask the owner to grant notification or exact-alarm access during this compatibility audit.

## 5. Samsung apps, routines and system integrations

| Integration | Finding | Status |
|---|---|---|
| Samsung Calendar / Google Calendar | Current StudyShift UI can hand off an event draft via Android's insert intent. This avoids unrestricted calendar reads and lets the selected calendar app ask the user to save. Existing external events are not read or deleted by this flow | VERIFIED IN SOURCE; emulator UI test still needed |
| Android Calendar Provider | Direct calendar reads/writes require permissions; an `ACTION_INSERT` draft is the lower-permission supported export path | SUPPORTED BY DOCUMENTATION; [Calendar Provider](https://developer.android.com/identity/providers/calendar-provider) |
| Modes and Routines | Samsung documents routines and actions, with availability varying by device/software. Samsung support material describes “Open an app or do an app action”; app-launch compatibility is plausible. A custom StudyShift action requires an Android shortcut/action that Samsung exposes in that picker | SUPPORTED BY DOCUMENTATION (general); StudyShift-specific action REQUIRES TESTING |
| Samsung Modes and Routines | App installed (5.0.04.1); Samsung documents user-created triggers/actions and app-launch actions. Existing routine list was not opened to avoid reading personal routines | DEVICE APP VERIFIED; documented capability; StudyShift action NOT RUN |
| Android shortcuts | StudyShift currently has no declared app shortcut integration. Android supports static/dynamic/pinned shortcuts; a pinned shortcut requires launcher/user consent | REQUIRES IMPLEMENTATION; [Android shortcuts](https://developer.android.com/develop/ui/compose/system/shortcuts/creating-shortcuts) |
| Samsung Reminder / Clock | No direct private-app API or account access is assumed. Use standard intents only when a supported user-facing flow exists | UNKNOWN / no direct integration verified |
| System theme, sharing, file picker, edge-to-edge | App has system light/dark following and a local file import/export path; behavior on this firmware still needs direct acceptance for system-bar contrast, Samsung picker, Back gestures and text scaling | SOURCE VERIFIED; REQUIRES TESTING |

Samsung's official Modes and Routines guide explains user-created conditions/actions and notes that availability varies by device and software version. It does not guarantee a public API for third-party routine creation or access. [Samsung Modes and Routines guide](https://www.samsung.com/us/support/answer/ANS10002538/)

## 6. Hardware, performance and layout

- **VERIFIED ON DEVICE:** The API 36 physical screen is 1080 × 2340 at 450 dpi (about 432 × 936 dp), with system font scale 1.0. Standard gesture navigation is in use.
- **VERIFIED ON EMULATOR:** The isolated StudyShift API 36 emulator booted as `emulator-5554` at 1080 × 2400 / 420 dpi. The other connected emulator (`emulator-5558`) belongs to another project and was not touched.
- **VERIFIED ON DEVICE:** StudyShift v34 launched after an in-place APK replacement and remained alive; no matching app-process fatal, Flutter, SQLite or database exception was found in the targeted log check. The user's local records were not inspected.
- **VERIFIED ON DEVICE:** APK hash `E45F5015…DAB2D920` installed over the existing package with `adb install -r`, retaining the same `app.shiftstudy.mobile` identity. Package metadata reported version code 44. The app launched and its accessibility tree showed the device-local “Good Night” daypart at the observed evening hour; no schedule entries were opened or read. The phone was returned to its home screen after the check.
- **VERIFIED ON DEVICE:** v46 APK hash `2BE78FCC…4007D78` installed in place over `app.shiftstudy.mobile`; the package reports version code 46. The app data-directory inode matched the pre-update observation; schedule contents were not inspected.
- **BLOCKED ON DEVICE:** Launching the installed v46 package did not bring StudyShift onscreen. A read-only package query reports `suspended=true` and `suspendingPackage=com.samsung.android.lool`; Samsung's official [Device Care listing](https://play.google.com/store/apps/details?id=com.samsung.android.lool) identifies that package as Device Care. `enabled=0` is the normal default enabled-state value, not an app disable. Android routed a launch to `SuspendedAppDcActivity`. No attempt was made to clear app suspension or change phone settings. Latest-build daypart, visual, widget and app-flow acceptance therefore remains unverified on the Galaxy.
- **VERIFIED ON EMULATOR:** v46, SHA-256 `2BE78FCC…4007D78`, installed in place and launched on `emulator-5554`; the dark-mode wordmark and More notifications row were visually confirmed. Tapping the row opened Android Settings > StudyShift notifications; the emulator showed notifications were not allowed. No permission was changed.
- **VERIFIED ON DEVICE:** Android App info reported notification delivery blocked and battery use set to Optimized; neither setting was changed.
- **VERIFIED ON EMULATOR:** First-run setup and empty Today rendered; the app saved and displayed a synthetic work shift, preserved it after force-stop/relaunch, then removed the synthetic record. The emulator was left with no synthetic schedule entry.
- **VERIFIED ON EMULATOR:** Build 0.1.0+36 installed in place on the dedicated API 36 emulator. The empty Week grid opens at 6 a.m.; when timed events exist it continues to open one hour before the earliest relevant interval. This was checked after an earlier build visibly opened at 5 p.m. with most of the useful day hidden.
- **VERIFIED ON EMULATOR (screen review):** Today shows the time-based greeting, focused date, a blue featured Next up card even on an empty day, schedule count and the separate illustrated empty state. Work and Study show the requested category tabs and empty states; More exposes search, widget, import/export, backup, time format and appearance controls. The current implementation matches the blueprint's structure in part, but it is not yet a visual match: the concept's sunlit hero and polished card/surface treatment are still incomplete, and More does not yet have the full Settings/Notifications/About organization. These are product-design implementation gaps, not Samsung-specific failures.
- **VERIFIED ON EMULATOR:** A placed Today / Next Event widget rendered the saved synthetic next-day shift, stayed populated after app force-stop, opened the app when tapped in normal use, and refreshed to its empty state after the record was deleted. The emulator widget remains on its clean launcher in the empty state.
- **NOT MEASURED:** sustained frame time, memory, battery drain, long calendar scrolling, app standby, Battery Saver, background wakeups, storage pressure, 120 Hz presentation, and low-memory recovery.
- **REQUIRES TESTING:** landscape, split-screen, large font/accessibility sizes, multi-window and display zoom on both emulator and Galaxy. No source change specifically for those cases is included in this audit.

Targets for the next performance pass: no layout overflow at 1.3× font scale or 360 dp width; no missed frame bursts during ordinary week navigation; cold-start and resume measurements reported separately; no recurring background work beyond user reminders and widget lifecycle needs; and no schedule content in logs.

## 7. Historical compatibility matrix (v34–v70)

| Check | Result | Evidence/next step |
|---|---|---|
| Install APK on clean emulator | PASS | API 36, package `app.shiftstudy.mobile`, v34 baseline; v35 and v36 were subsequently installed in place |
| In-place APK update on Galaxy | PASS | v46 hash `2BE78FCC…4007D78` installed over existing `app.shiftstudy.mobile`; package identity retained and version code checked |
| Start app on Galaxy, installed v46 package | BLOCKED | Package state reports `suspended=true`; `enabled=0` is the default enabled-state value. No phone changes were made |
| Start app on Galaxy, prior v44 package | PASS (smoke only) | Earlier hash `E45F5015…DAB2D920` launched and displayed local daypart; schedule contents were not inspected |
| Start app and complete first-run path on emulator | PASS | Work + School setup selection and Today empty state |
| Create/display synthetic work shift | PASS | Emulator UI showed `QA shift v34`, date/time and one-event Today state |
| Restart/persistence | PASS | Force-stop and relaunch retained the synthetic record |
| Delete synthetic shift | PASS | Confirmation and Today returned to 0 events |
| Slow-start copy regression | PASS | Targeted widget test reproduces prior false-failure behavior and verifies truthful loading copy |
| Empty Week initial position | PASS | v36 installed emulator displays 6 a.m. at the top of the useful grid; previously opened at approximately 5 p.m. |
| Today empty Next up card | PASS | v36 emulator screenshot shows the blue featured card and the separate empty-schedule message without obscuring Add |
| Work/Study/More route screen review | PASS (emulator observation) | v36; category tabs and More tools are visible. Visual fidelity to the approved concept remains incomplete |
| More opens StudyShift notification settings | PASS (emulator) | v46 opened Android's app-specific notification settings; emulator showed notifications not allowed, and permission was not changed |
| App icon beside Samsung Calendar/Clock | NOT RUN | Clean comparison not obtained; no icon size/shape settings changed |
| Samsung widget host registration | PASS (presence/size only) | Existing StudyShift widget was already placed at about 4 × 2 cells; content/settings not inspected |
| Samsung widget settings/transparency/stack | NOT RUN | No Galaxy widget was modified; only Samsung documentation establishes possible host controls |
| Widget resize and real schedule projection on Samsung | NOT RUN | Source supports variable RemoteViews; requires live widget instance and synthetic data |
| Notifications/lock screen/exact alarm | NOT RUN | Galaxy notification setting is not granted; no settings changed |
| Modes and Routines StudyShift action | NOT RUN | No routine screens opened and no custom action is currently published |
| Landscape on emulator | PASS (screen review) | v44 Week view reviewed on API 36 emulator; compact-height spacing removed the bottom overflow. Galaxy landscape remains NOT RUN |
| Accessibility font scaling, multi-window | NOT RUN | Separate responsive acceptance pass required |
| Samsung Calendar export | NOT RUN on device | Android draft handoff source exists; verify receiving app without saving an external event |

## 8. Recommended actions (ranked)

1. **Samsung widget configuration and privacy:** test v46's per-widget content and appearance configuration, empty/populated states, resize behavior, host background controls and tap behavior on the Galaxy after the app can launch. Verify stale and unavailable states after process death and reboot.
2. **Samsung visual acceptance:** with owner present or otherwise clearly authorizing visible launcher changes, compare icon size/mask and test widget background/transparency/resizing using synthetic data. Do not alter current Home screen merely to obtain evidence.
3. **Reminder permission flow:** verify the existing event-form permission request, the new More-to-system-settings action, and clear fallback behavior for notification and exact-alarm denial. The More settings handoff is verified on the emulator; reminder delivery and alternate permission states still need coverage.
4. **Modes and Routines:** publish safe Android shortcuts for “Open Today,” “Open Work,” “Open Study,” and “Add event” if the normal app-shortcut surfaces make them available. Then verify whether One UI exposes them as “app actions”; do not depend on undocumented Samsung APIs.
5. **Responsive/performance checks:** exercise landscape, large font, multi-window and dense weeks on emulator, then repeat high-value cases on the Galaxy. Capture timings and frame metrics before making optimization claims.
6. **Calendar draft test:** use the existing Android insert-intent integration to confirm Samsung Calendar and Google Calendar can receive a draft. Cancel without saving during compatibility validation.

## 9. Historical build and verification identity

- APK: `app/build/app/outputs/flutter-apk/app-personal-debug.apk`
- Package: `app.shiftstudy.mobile`
- Version: `0.1.0` (version code 46)
- Target SDK: 36; min SDK: 26
- Latest artifact is a personal debug APK installed and launched on the API 36 emulator and installed in place on the Galaxy. Galaxy launch is blocked by package suspension. Earlier hash `E45F5015…DAB2D920` was launched successfully. No Samsung widget settings or personal schedule contents were inspected.
- Size: 169,486,271 bytes
- SHA-256: `2BE78FCC6EF41E048535283556E80F819F3E701112B07377A814747934007D78`
- Signing certificate SHA-256: `eea93468227272260014d7f20efcf693529f9a4c7f11484ac6ba0ae2b2be4cbb`
- Flutter tests: 152 passed
- Flutter analyze: no issues found
- Galaxy: latest v46 hash is installed in place, but launch is blocked by `suspended=true`; no setting or schedule data was changed or inspected. Samsung widget appearance, Samsung-specific layout, reminders, calendar handoff, icon comparison and routines remain unverified.
- Emulator: latest v46 hash installed and launched; More opened Android's StudyShift notification settings and showed that notifications were not allowed, without changing permission. Landscape Week screenshot is `app/build/qa/v44-landscape-week-fixed.png`. Per-widget content/appearance configuration, independent Work/Study projections, synthetic event deletion, widget empty refresh, dark empty/populated card contrast, and post-restart Today empty state were exercised on the API 36 emulator. Samsung-specific widget acceptance is still required.
- Git: project worktree contains existing owner/project modifications; this run did not commit or push them.

## Official references

- [Samsung Galaxy S23 FE specifications](https://www.samsung.com/uk/support/mobile-devices/specifications-for-the-new-galaxy-s23-fe/)
- [Samsung widget customization](https://www.samsung.com/ca/support/mobile-devices/use-widgets-on-your-galaxy-phone/)
- [Samsung Modes and Routines](https://www.samsung.com/us/support/answer/ANS10002538/)
- [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)
- [Android app widget creation and configuration](https://developer.android.com/develop/ui/views/appwidgets)
- [Android responsive widget layouts](https://developer.android.com/develop/ui/views/appwidgets/layouts)
- [Android widget update interval](https://developer.android.com/reference/android/appwidget/AppWidgetProviderInfo)
- [Android notification permission](https://developer.android.com/develop/ui/compose/notifications/notification-permission)
- [Android exact alarms](https://developer.android.com/develop/background-work/services/alarms)
- [Android Live Updates](https://developer.android.com/develop/ui/views/notifications/live-update)
- [Android Calendar Provider](https://developer.android.com/identity/providers/calendar-provider)
- [Android app shortcuts](https://developer.android.com/develop/ui/compose/system/shortcuts/creating-shortcuts)

## Current Galaxy acceptance evidence — 2026-11-15

Target: Samsung Galaxy S23 FE `SM-S711B`, Android 16 / API 36, display 1080×2340 at 450 dpi, font scale 1.0. Installed package `app.shiftstudy.mobile`, version name `0.1.0`, version code `10243`; current foreground activity returned to StudyShift Today after checks.

- **VERIFIED ON DEVICE:** Today weather reports a saved place and responds to a horizontal swipe between Grantley Adams International Airport and Bridgetown. Swiping back restored the original Grantley Adams selection. The Local weather page exposes optional Today weather, approximate location, manual place search, saved places and current area. No location setting was changed.
- **VERIFIED ON DEVICE:** The Today screen displays the current local date, time-based greeting, weather summary, next event and today schedule. Today, Week and More navigation surfaces were opened; the app returned to Today.
- **VERIFIED ON DEVICE:** More > Notifications states notifications are on and exact reminder timing is off. Android `SCHEDULE_EXACT_ALARM` app-op reports default/no operation. No alarm permission was enabled and no reminder delivery was triggered.
- **VERIFIED ON DEVICE:** More > Home-screen widget opens an app-owned list with Next Event (2×2), Today (4×2), This Week (4×1), Next Class (2×2) and Upcoming Deadline (2×2). Continuing Next Event opens Samsung Launcher's “Add to Home screen?” preview for “StudyShift schedule / NEXT UP · WORK / 2 x 2”. The flow was canceled before adding. This did not verify the full Samsung widget picker, resizing, populated data, appearance options, widget refresh or process-death behavior.
- **VERIFIED ON DEVICE:** `dumpsys appwidget` lists five installed StudyShift providers: Schedule, Today, Week, Next Class and Deadline. Registry presence does not prove visible rendering or resizing.
- **NOT RUN:** Reminder delivery (exact timing is off); widget add/resize/configuration on the Home screen; Samsung landscape, large text, and widget-stack acceptance; updated in-place APK upgrade on this build.

App appearance and accent were temporarily switched for splash checks, then restored to Dark + Stylish Violet. No phone/system setting, schedule record, external calendar item, or widget placement was changed. The historical v46 section above is retained as prior evidence; it is not the current installed build identity.

### Additional Galaxy acceptance — 2026-11-15, same installed build

- **VERIFIED ON DEVICE:** The app-owned Add a StudyShift widget route presents all five layout choices and sizing descriptions: Next Event (2×2), Today (4×2), This Week (4×1), Next Class (2×2), and Upcoming Deadline (2×2). It also explains that an existing widget is edited by long-pressing it on the Home screen and choosing Settings. The route was canceled before placing or changing a widget.
- **SUPPORTED BY DEVICE REGISTRY:** Android's AppWidget service lists the five StudyShift providers. Each has resize mode `3` (horizontal and vertical) and `updatePeriodMillis=1800000` (30 minutes); event-driven update behavior and rendered One UI resizing still require testing. The Android platform's periodic widget refresh is therefore not a real-time update guarantee.
- **VERIFIED ON DEVICE:** Android reports `POST_NOTIFICATIONS` granted. The app's reminder prompt was inspected and dismissed without changing settings or scheduling a reminder. StudyShift's reminder settings reported exact reminder timing off; `SCHEDULE_EXACT_ALARM` has no app-op record and remains unenabled. Reminder delivery is NOT RUN on this Galaxy.
- **VERIFIED ON DEVICE:** Package inspection found no `READ_CALENDAR` or `WRITE_CALENDAR` grant/request in the installed package's permission report. The saved-event calendar handoff was separately tested in Samsung Calendar earlier: it opened a correctly populated draft, which was discarded; no external event was saved.
- **VERIFIED ON DEVICE:** A cold launch of `app.shiftstudy.mobile/.LauncherVioletDark` returned `Status: ok`, `LaunchState: COLD`, `TotalTime: 1658 ms`. The captured app splash showed the Violet mark and proportionate artwork; after forecast loading, StudyShift returned to Today with the saved weather summary. This is one smoke timing and visual observation, not a benchmark.
- **Final device state:** StudyShift is foregrounded on Today with Dark + Stylish Violet selected. No settings, schedule data, external calendar records or widget placements were changed during this pass.

### Galaxy in-place update retest — 2026-11-15

- **VERIFIED ON DEVICE:** Built and installed the ARM64 `personalDebug` APK in place on `SM-S711B`; package remained `app.shiftstudy.mobile`, version `0.1.0`, versionCode `10243`, target API 36. Android reported a new `lastUpdateTime` and the app returned to StudyShift Today after relaunch. Previously saved schedule content remained present; no schedule record was changed.
- **VERIFIED ON DEVICE:** Dark appearance and Stylish Violet accent remained selected after the update. The Today screen rendered weather, date, next-event card, schedule card, available-time ranges, and all five navigation destinations without a visible overflow at the tested portrait size/font scale.
- **VERIFIED ON DEVICE:** The app's widget-family route/provider inventory remains available. The captured launcher page did not show a StudyShift widget, so populated widget rendering and resizing on One UI remain **NOT RUN**. No widget placement or launcher setting was changed.
- **VERIFIED ON DEVICE:** Exact-alarm access remains off/unconfigured. No reminder was scheduled or delivered in this retest. Samsung Calendar returned to the foreground after package replacement; its unsaved draft was dismissed without saving, and no external calendar entry was created.
- ARM64 debug APK `app/build/app/outputs/flutter-apk/app-arm64-v8a-personal-debug.apk` SHA-256: `3797D73C4BD92EFF26C740BDE008640C7B4B34D27773EEB48A222E18D209A4E0`. `flutter test` completed with **310 passed** and `flutter analyze --no-pub` reported **no issues**. The release build remains blocked by the project's missing-keystore guard; this was a debug install only.
- Temporary screenshots and hierarchy XML created for this pass were removed from the phone and host temp directory. No Gallery, WhatsApp, or unrelated app content was opened. Samsung-specific widget refresh/resize, reminder delivery under power restrictions, launcher icon comparison, large text, landscape, and backup/restore acceptance remain open.

### Additional read-only launcher check — 2026-11-15
- **VERIFIED ON DEVICE:** `dumpsys appwidget` reports two StudyShift widgets currently bound to One UI Home (`com.sec.android.app.launcher`): `ScheduleWidgetProvider` at 4 columns × 2 rows (334 × 179 dp reported by One UI) and `NextClassWidgetProvider` at 2 × 2 (156 × 179 dp). These are real launcher instances, correcting the earlier assumption that no StudyShift widget was placed. The first visible home page did not contain a StudyShift widget, so its rendered contents and resize interaction were not captured.
- **VERIFIED ON DEVICE:** The installed app remains `0.1.0` / versionCode `10243` on `SM-S711B`, Android 16/API 36. Today returned to the foreground after the launcher check and displayed the current date/greeting, weather summary, next event, schedule card, available-time summary and five navigation destinations at the device's existing portrait/font settings. No route was altered and no schedule event was edited.
- **VERIFIED ON DEVICE:** Week and Month both rendered on the Galaxy. Month showed the November 2026 grid, category dots, month summary, and selected-day event card. The Galaxy's read-only `settings get system time_12_24` value is `24`; Week and event times therefore correctly appeared in 24-hour style on this device. Existing widget tests cover AM/PM in 12-hour mode. The Week grid showed five columns at the initial viewport with the selected Sunday at the right edge; swiping access to the earlier days and owner preference for the initial framing still need acceptance.
- **VERIFIED ON DEVICE:** Work and Study destinations opened from bottom navigation. Work displayed the shift-code-legend entry and existing work filters; Study displayed Classes/Assignments/Exams, academic terms and the empty class state alongside saved deadlines. The screens scrolled beneath the fixed navigation without a visible overlap in the captured portrait views. No schedule item or filter was changed.
- **NOT RUN:** Samsung launcher widget resize, visual density comparison at 2×2/4×2 after this build, per-widget configuration, refresh after schedule edit/date rollover, widget-stack behavior, reminders, landscape, large text, backup/restore, and One UI 8.5-specific icon comparison. Registry dimensions establish placement metadata only; they do not establish visual or interaction acceptance.
- Temporary launcher/app screenshots and UI hierarchy XML were removed from the phone and host temp directory after inspection. The phone was returned to StudyShift Today. No Gallery, WhatsApp, unrelated app, system setting, or launcher placement was opened or changed.

### Week initial viewport fix — 2026-11-15, build 0.1.0+8244
- A Galaxy Week screenshot showed an 08:30 weekday item clipped above the viewport because vertical positioning used only the selected Sunday. Added a regression test with an early weekday item and later selected-day event; it failed before the implementation change.
- The initial vertical position now considers all intervals intersecting the visible week when the focused date has a timed event, while retaining the prior morning default when the focused date is empty and preserving overnight continuations.
- **VERIFIED ON DEVICE:** Built and installed personal debug APKs in place with no uninstall: Galaxy S23 FE `SM-S711B` ARM64 version `0.1.0`, versionCode `10244`; emulator `emulator-5554` x86_64 versionCode `12244`. The Samsung schedule remained visible after the update. Week then opened at 05:00 because the current week contains a 06:00 start, and the 08:30 weekday item was fully visible. Monday–Friday were reachable by horizontal swipe from the Sunday-centered viewport. Returned the Galaxy to Today.
- **VERIFIED ON EMULATOR:** Current x86_64 APK launched successfully to Today after in-place update. This emulator had an empty local schedule from the earlier integration-runner reinstall; no owner schedule was copied to it.
- ARM64 APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-personal-debug.apk`, SHA-256 `EDB373CA8D91AFF0FBF4DEB1CB2079D00202732F3888B512442A98F4949BD282`.
- x86_64 APK: `app/build/app/outputs/flutter-apk/app-x86_64-personal-debug.apk`, SHA-256 `33906C2C4483DD8C44AF51A85FC68F005A95263D202FC1F3CCA8056CDC87A5CA`.
- **VERIFIED SOURCE:** `flutter test --no-pub` completed with **311 passed**; `flutter analyze --no-pub` reported **no issues**. Native test results were not rerun for this Dart-only change. Build emitted existing Gradle restricted-native-access, SDK XML v4, and `cryptography_flutter` Kotlin-plugin compatibility warnings; APK build succeeded.
- Captured temporary screen images were deleted from the host and emulator. No schedule entry was edited, and no launcher widget placement or phone setting was changed.

### Galaxy launch-screen correction — 2026-11-15, build 0.1.0+8245

- **VERIFIED ON DEVICE:** Reproduced the oversized colored tile in the Android 16 system-owned first splash frame. The v8244 styles pointed `windowSplashScreenAnimatedIcon` at the full adaptive launcher icon. Updated each light/dark accent style to use its existing transparent S splash foreground; launcher icons themselves are unchanged.
- **VERIFIED ON DEVICE:** Built and installed the ARM64 personal debug APK in place on Galaxy S23 FE `SM-S711B`; installed package is `app.shiftstudy.mobile`, version `0.1.0`, versionCode `10245`, target API 36. Cold launch showed the transparent violet S mark without the oversized purple tile. The Flutter splash then showed the existing StudyShift wordmark, loading state and accent waves, and the app returned to Today. Dark + Stylish Violet remained selected; saved schedule content remained visible.
- **VERIFIED ON DEVICE:** Barbados local time was 06:08–06:09. The first Today capture showed cached nighttime weather; after weather refresh, Today changed to “Good Morning” and a sun icon at 06:09. No time, weather, location, appearance, notification, calendar or schedule setting was changed.
- Splash resource tests: **7 passed** across blue, teal, violet, amber and red in light/dark Android resources. `flutter analyze --no-pub`: **no issues**. ARM64 debug APK SHA-256: `50A723FB50C82FC35D342F894A36898802AF32273198BAA2E5626F9008934A92`. This is a debug APK, not a release build.
- The app is foregrounded on Today. Reminder delivery and visible One UI widget layout/refresh remain unverified. This run did not open Gallery, WhatsApp, or unrelated apps.
- Temporary app screenshots remain in `%TEMP%`: `studyshift-galaxy-today.png`, `studyshift-galaxy-launch.png`, `studyshift-splash-native.png`, `studyshift-splash-after.png`, `studyshift-galaxy-later.png`. The host rejected their deletion command. They were not added to Git and contain StudyShift UI, including saved schedule content.

### Galaxy acceptance continuation — 2026-11-15, personal build 0.1.0+8249

**Target:** Samsung Galaxy S23 FE (`SM-S711B`), Android 16 / API 36, One UI 8.5. Physical-device claims below apply only to this model and installed build.

- **VERIFIED ON DEVICE:** Updated `app.shiftstudy.mobile` in place to version `0.1.0`, version code `10249`, target API 36. The existing schedule was still visible after the update. ARM64 debug APK: `app/build/app/outputs/flutter-apk/app-arm64-v8a-personal-debug.apk`; SHA-256 `764C1D261F073DD4FA8951E1AF70D5BDE3D3DB30404D5FC1F474BB0BFF6D8932`.
- **VERIFIED ON DEVICE:** Today, Week, Month, Work, Study and More opened. Week showed the saved events in date order; Month showed November 2026 and its event counts. Work showed its shift categories and event cards. Study showed the available class/deadline sections; no classes fell in the focused week.
- **VERIFIED ON DEVICE:** Today weather was enabled. Horizontal swiping changed the weather location from slot 3 of 3 to slot 1 of 3; the selected location was returned to slot 3. Location permission is approximate/coarse and foreground-only; fine location is denied. Weather-settings copy states that background location is not used.
- **VERIFIED ON DEVICE:** Changed appearance Dark → Light → Dark and accent Stylish Violet → Stylish Blue → Stylish Violet. Both changed while the app remained open. Package Manager reports `.LauncherVioletDark` enabled after restoring the owner’s prior appearance. No theme preference was left changed.
- **VERIFIED ON DEVICE:** Forced landscape for a short layout check. The app rotated, kept all five navigation destinations available, and exposed the More/preferences controls. Restored the original settings (`accelerometer_rotation=1`, `user_rotation=0`).
- **VERIFIED ON DEVICE:** Battery Saver was off and Always On Display was on at inspection time. StudyShift is not in `deviceidle`’s battery-optimization exemption list. This is not a measured battery-drain test. App notification permission is on; exact-alarm access is off, so Android may delay alarms. App info reported 195 MB storage use.
- **VERIFIED ON DEVICE:** Samsung widget picker opened from the app’s own “Add a StudyShift widget” screen and listed Next Event 2×2, Today 4×2, This Week 4×1, Next Class 2×2 and Upcoming Deadline 2×2. Added one Today widget; Samsung registered a 4×2 instance at approximately 334×180 dp with resize enabled and a 30-minute periodic update. Its final home-screen cell, resize interaction, tap destination, transparency settings and live data refresh were not visually verified. No other widgets were added or moved.
- **VERIFIED ON DEVICE:** StudyShift’s system notification permission is enabled. Samsung notification settings currently say the personal package “hasn't sent you any notifications.” A separate `.review` flavor delivered a synthetic scheduled reminder on the Galaxy and the integration test passed. This proves the notification path for that isolated package, not personal-package channel settings or audible delivery. Exact timing remains off.
- **VERIFIED ON DEVICE:** StudyShift’s Shift Code Legend page is empty (“No shift codes saved”) even though saved work entries show codes. The roster-code legend is not populated from the saved roster. This remains a product acceptance defect.
- **VERIFIED ON DEVICE:** Import review page offered ICS, StudyShift CSV/XLSX, PDF/schedule-image OCR and exam-timetable OCR routes; no file was imported. Calendar export page described `.ics` export, but no file was written and Samsung Calendar import was not exercised. Samsung Calendar, Clock, Weather, Good Lock, Home Up, Theme Park and Modes and Routines packages are present; app-to-app integrations were not tested in this pass.
- **VERIFIED SOURCE:** Flutter suite passed **314 tests**, `flutter analyze --no-pub` reported no issues, and Android `:app:testPersonalDebugUnitTest` succeeded/up-to-date. The Samsung reminder integration test passed with synthetic data.
- **OPEN:** Cold-start splash/icon visual confirmation on build 10249; personal-package audible/lock-screen reminder; widget placement/resize/tap/refresh; Samsung Calendar/Clock/Good Lock/Modes and Routines; battery drain under a measured use interval; power-saving-mode and AOD behavior; PDF import and actual ICS export; full landscape overflow inspection; and population/verification of the shift-code legend.
- **Test artifact cleanup:** The `.review` test package was not present for owner user 0 after the run. Generic uninstall returned `DELETE_FAILED_INTERNAL_ERROR`; targeted uninstall for user 0 reported `not installed for 0`. A package-manager query also reported shell access denied for user 150, so no attempt was made to access or alter that profile. The personal package remained installed at code 10249.


### Galaxy widget settings layout retest — 2026-11-15, personal build 0.1.0+8251

- **VERIFIED ON DEVICE:** Fixed StudyShift's widget configuration choice controls from a clipped horizontal strip to a responsive two-column layout. After the first build, a Galaxy screenshot showed the rows at wrap-content width and labels breaking mid-word; rows were changed to match the available width, then the control page was retested on the Samsung.
- **VERIFIED ON DEVICE:** On the third One UI Home page, long-pressing the Today widget and selecting **Settings** opens StudyShift's own configuration activity. Its preview, Today 4×2 layout, all five content filters and all five appearance choices were visible after vertical scrolling; labels remained whole. Cancel returned without saving any configuration changes.
- **VERIFIED ON DEVICE:** Existing Next Event, Next Class and Today widgets are grouped on the third home page in separate launcher slots, with open space below and no overlap with the dock or neighboring app icons. Their positions were left unchanged.
- **VERIFIED ON DEVICE:** Installed ARM64 `personalDebug` APK in place on Galaxy S23 FE `SM-S711B`, version `0.1.0`, versionCode `10251`, target API 36. StudyShift returned to Today; existing local data was preserved. APK SHA-256: `98D86331A13FBD7A69D0F2A32C71C77D7856DE1C48840F84277F839DDC860C1B`.
- **VERIFIED SOURCE:** `:app:testPersonalDebugUnitTest` succeeded after the Kotlin layout edit. Android build completed; existing Gradle/Kotlin and Android SDK XML warnings remain.
- **NOT RUN:** One UI widget resizing, appearance-mode change/save, refresh after schedule mutation, periodic update timing, and Samsung widget-stack behavior. This pass did not alter widget preferences, home-screen placement, calendar entries, or device settings.

### Shift code legend retest — 2026-11-15, personal build 0.1.0+8252

- **VERIFIED ON DEVICE:** In-place ARM64 personal build `0.1.0`, versionCode `10252`, target API 36 opened on Galaxy S23 FE `SM-S711B` / One UI 8.5. The Work → Shift code legend screen now shows observed patterns from existing saved work entries, including separate intervals for split shifts; the page no longer reports that no codes are saved.
- **VERIFIED ON DEVICE:** Search with a deliberately unmatched synthetic term displayed “No matching shift codes.” No event or legend entry was edited, created, or deleted. The app was returned to Today.
- **PRIVACY:** The device's roster was used only for this requested acceptance check. No personal roster values were copied into source, tests, Git, or this report. Temporary screenshots were removed.
- **VERIFIED SOURCE:** The new extraction/widget regression tests passed, the full Flutter suite passed (316 tests), and `flutter analyze --no-pub` reported no issues before this build. `git diff --check` completed without whitespace errors; Git emitted only existing LF/CRLF working-copy notices.
- **BUILD:** ARM64 APK SHA-256 `16B90DDF40CA9F8D5DD8FD7BE37C9EFD2CBDE64ABE818CC652D142918C5366A3`.
- **OPEN:** This focused legend check does not close the remaining Samsung matrix: current-build widget resize/refresh and appearance, reminder delivery on the personal package, landscape/large-text page review, calendar import/export, backup/restore, battery/power-saving behavior, and integrations remain to be exercised.
