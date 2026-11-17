# Owner Decision Register

These decisions materially affect product foundations. Until answered, implementation choices remain proposals.

## Requires owner review before visual UI implementation

1. **Framework:** owner selected Flutter + Dart; Kotlin is reserved for Android widgets/system APIs. No Apple code in this phase.
2. **Visual direction — historical, superseded 2026-11-07:** Daylight Ledger was approved on 2026-11-05, with Shift Atlas informing weekly-grid precision. The owner replaced that direction with the supplied StudyShift timetable and logo boards; see `DESIGN.md`.
3. **Android API range:** initial build will compile/target API 36; use minSdk 26 for broad Android 8+ compatibility unless the selected widget/dependency requires higher. Revisit after install testing.
4. **App identity:** private Android package ID chosen as `app.shiftstudy.mobile` before first build. No Play package registration or iOS bundle ID is configured. Keep this ID stable for in-place APK updates.
5. **Backup policy:** Android Auto Backup/device transfer remains disabled so schedule data is not copied automatically. An explicit encrypted schedule-only backup/restore is implemented with a user-selected local document; app settings are not included. No cloud backup or service is approved.
6. **Open-source license:** decide whether the app source is private, permissively licensed, or copyleft. No project LICENSE has been added; review candidate dependency licenses before committing to a license.

## Needed before the roster parser or official product terminology

7. A scrubbed/synthetic example of the Caribbean Aircraft Handling roster, including a legend and confirmation of dates, airport duty, airline assignment, training, rest/leave and reporting semantics. Do not provide personal/colleague data; substitute names and remove sensitive identifiers.
8. Preferred handling of roster correction history, overtime summaries, swap records, and whether pay estimates are in scope.
9. Initial time zone should default from device settings, but confirm whether the user needs separate work/home zones or specific roster zone handling.

## Can be deferred

10. Which future desktop platform is first after Android, if any.
11. iOS target timing and availability of a Mac/Xcode device environment.
12. Exact calendar integration depth after basic event export.
13. Whether future optional synchronization is wanted; no backend design should start until requested.
14. Language set, first-weekday default and public/private repository choice. Product name **StudyShift** and the supplied S-logo direction were selected by the owner on 2026-11-07. The Android application ID remains `app.shiftstudy.mobile` for safe updates.

Phase 1 source implementation and primary-screen composition are authorized. The owner-approved StudyShift concept boards dated 2026-11-07 supersede the earlier Daylight Ledger direction; implement them as recorded in `DESIGN.md`.

## Implemented provider choice — optional weather (2026-11-14)

- GitHub’s [`public-apis`](https://github.com/public-apis/public-apis) catalogue is a discovery index, not a blanket licence or service guarantee. Each API provider’s current terms, privacy policy, rate limits, and availability must be checked separately.
- StudyShift uses Open-Meteo for manually selected town/city lookup and current forecast details. Its free endpoint is keyless and currently limited to non-commercial use, with a 10,000-request/day limit and no uptime guarantee. See the [service terms](https://open-meteo.com/en/terms) and [forecast documentation](https://open-meteo.com/en/docs).
- Weather starts disabled. The owner approved two opt-in location paths: choose a place manually, or tap **Use my location** for one-time approximate foreground access. Android requests only `ACCESS_COARSE_LOCATION` after the app's plain-language consent step; it does not request precise or background location and does not continuously track. The selected coordinates are sent to Open-Meteo for a forecast and stored locally as the active weather place. Core scheduling remains local and offline, with the last successful weather result cached only as an optional display fallback.
- The UI attributes Open-Meteo under CC BY 4.0 and describes conditions as informational, not operational or airport safety guidance. Re-check provider terms before any commercial release, advertising, broader distribution, or material usage increase; a paid/commercial licence is not included in this project scope.
