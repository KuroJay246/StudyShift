# Architecture Proposal

**Status:** Flutter/Dart Android-first direction selected by owner; implementation is being established in Phase 1. Cross-platform clients remain planned only.

## Recommended system shape

A Flutter/Dart application with an offline-first domain and platform adapters. Android/Gradle development uses the owner-selected JDK 21, pinned at project level; the specific Gradle Wrapper, Android Gradle Plugin, and Kotlin combination must be compatible with it. No account, network service, Firebase, analytics, or AI provider in the initial product. Web and desktop are clients over the same domain and file-based/local storage interfaces, but use layouts and navigation suited to keyboard, pointer, and larger screens.

```text
Flutter presentation (mobile / tablet / web / desktop)
        │ Riverpod view models, routing, accessible design system
        ▼
Application services
  schedule query • recurrence expansion • conflict analysis • import review
        │ ports/interfaces
        ├── Drift + SQLite local repository (one authoritative event store)
        ├── local file import/export + explicit backup/restore
        ├── notification adapter
        ├── calendar adapter (permissioned OS APIs)
        └── widget snapshot adapter ── Android Kotlin / AppWidget + RemoteViews
                                  └── iOS Swift / WidgetKit
```

## Proposed modules

1. **Core domain:** stable event identifiers; work, education, personal and task records; exact raw imported text; recurrence and exception rules; intervals; time zones; provenance; user confirmation state. No Flutter UI or database classes in domain rules.
2. **Schedule engine:** recurrence expansion over a bounded date range; conflict detection; rest windows; estimated hours; deadline/reminder priorities. Pure deterministic Dart functions with explicit local date/time and zone inputs.
3. **Local persistence:** Drift over SQLite; migration version table; transactions for a confirmed import batch; indexes on start/end and source. Keep recurrence definitions and single-occurrence overrides distinct. Do not store only UTC instants because future weekly classes and rosters are local civil-time commitments.
4. **Application services:** Today/week/month queries, editing commands, import preview/commit, calendar export, backup/restore, notification plan and widget summary creation.
5. **Presentation:** feature routes and reusable tokens/components; work/study modules opt-in; phone bottom navigation and tablet/desktop rail/two-pane layouts. Views never own SQL or parse import formats directly.
6. **Import adapters:** picker → private temporary source → format-specific extraction → normalized candidates with warnings/confidence → duplicate/change comparison → human review and correction → one transaction commit. Preserve original source or a reference/hash only according to the user's retention choice. Delete temporary copies after completion/cancel.
7. **OS adapters:** Flutter platform interface with Android Kotlin and Apple Swift implementations. Each operation must report capability, permission state, sync/write result, and unsupported behavior. No assumption that web/desktop shares native calendar or widget APIs.
8. **Widget snapshot:** app generates a small, versioned JSON/value snapshot containing only data needed for selected widgets. The implemented Android widget reads this app-private snapshot and renders through the native `AppWidgetProvider`/`RemoteViews` API; it does not open Drift directly. iOS WidgetKit remains a future platform adapter. The snapshot avoids two database implementations, reduces widget latency, and can show a clear stale-data state. Shared containers and platform storage bridges are owned by each OS adapter and tested independently.
9. **Future sync port:** a sync contract can be introduced later, but no server/provider is selected. Local records need durable IDs, revision/update timestamps, deletion tombstones and conflict semantics before any sync is designed. Avoid writing speculative sync engine code now.

## Domain model outline

- `ScheduleProfile`: selected modes/features, locale, display preference (12/24 hour), home week-start, time zone policy.
- `ScheduleSource`: work, school, personal; source identity and color/icon; category label never relies on color alone.
- `Workplace`, `Department`, `Role`, `EmployerCodeDefinition`: per-employer organization and user-validated local meanings. A code may denote duty, training, leave, rest, or opaque/unresolved entry.
- `AcademicTerm`, `Institution`, `Course`, `ClassSeries`, `Task/Deadline`: institution/term boundaries and generated occurrences with exceptions.
- `ScheduleItem`: stable ID, source, title, raw source string, explicit user label, location, note, recurrence or concrete occurrence, lifecycle/status, source provenance, confidence/review state.
- `TimeInterval`: local start date/time, optional end date/time, IANA time-zone identifier and resolved start/end instants. One schedule item may contain multiple intervals (split shifts). Overnight end date is explicit and later than start date. Validate DST gaps/folds and make user choose when input cannot map uniquely.
- `RecurrenceRule` and `OccurrenceOverride`: weekly/daily/monthly rules with start/end bounds and excluded/added dates; term date boundaries; cancellation/reschedule exceptions. Use bounded expansion; do not store unbounded occurrences or turn every repeat into a manually duplicated record.
- `ImportBatch`: source type, import timestamp, parser version, proposed/accepted/rejected/skipped/warning counts. Keep only the 50 newest local summaries; never persist the selected file name, path, content or extracted text in batch history. Event-level provenance is stored separately.
- `ExternalCalendarLink`: provider/calendar ID and app-created event IDs/hashes only if integration is enabled. Removing a link disconnects refresh; user explicitly chooses whether app-created exported events may be removed.

## Time and recurrence invariants

- Never infer missing year, locale ordering, end date, offset, or employer code silently.
- Store recurrence in local civil time and named zone; store resolved instants for concrete occurrences. Preserve original source time text and parsed interpretation.
- Preserve 12/24-hour input preference independently from canonical time values.
- Overnight event is one interval spanning consecutive local dates; split shifts are separate intervals. Validate breaks and overlap without merging segments.
- Recurring class times are zone/term-aware. A weekly rule is anchored to the term and excludes holidays/cancellations or includes rescheduled exceptions.
- Conflict detection uses resolved instants while displaying local times with an explicit date and zone when useful. Test daylight-saving gaps/folds even though Barbados uses fixed UTC−4 today, because other users/platform zones may change.

## Storage, import, and backups

- SQLite/Drift is selected for structured relationships, transactions and migrations; pinned package versions and licenses are recorded in the Flutter app manifest and lockfile.
- Private application storage is the default. Do not claim database encryption; operating-system device encryption and app sandbox are baseline only. Decide whether to add SQLCipher or encrypt exported backup separately after a practical compatibility/performance review.
- Consider disabling Android Auto Backup by default until the user understands that platform backup may store data in a Google account. Provide explicit, integrity-checked archive export/restore. If device-to-device backup is later enabled, make disclosure and exclusions part of setup.
- Backup format is versioned and portable (JSON manifest + event data + optional user-chosen media/import sources). Validate schema, ID uniqueness, times, hash, and size before replacing data. Restore to a new staging store first and require merge/replace choice.
- CSV/ICS first as transparent structured formats; XLSX after parser package review; PDF/image parsing as best-effort suggestions with OCR optional/on-device where available. Keep originals only while user requests, propose fields, confidence, warnings and a side-by-side editable preview. No silent commits.

## Notifications, calendar, widgets

- Local notifications are derived from confirmed schedule data and rebuilt after edits, time-zone changes, clock/date changes, restore, and reboot. Avoid exact-alarm entitlement by default unless policy eligibility and user need are established; gracefully handle notification and exact-alarm denial. Battery optimization/vendor differences remain.
- Android calendar: start with user-mediated system insert/edit intents. Direct provider read/write is a later opt-in requiring narrow permission and reliable ownership tracking; disallow bulk delete. iOS: prefer system event editor/write-only access for export; full calendar read scope only if a later reviewed feature truly needs it.
- Android widget candidates: Today overview, next shift, next class, week strip, upcoming deadlines. The implemented first widget is a versioned schedule snapshot over an app-owned MethodChannel into app-private Android SharedPreferences. A Kotlin `AppWidgetProvider` renders that projection with `RemoteViews`, never opening Drift's SQLite file. The bounded native persistence handler, Dart snapshot contract/publisher, app-foreground schedule subscription, tap-to-open intent, date/time refresh receiver, empty/unavailable/stale states, and resize support are implemented. Android permits scheduled refresh at a coarse minimum interval; actual delivery is controlled by the system/launcher. Samsung One UI and other launchers still need physical-device layout/refresh testing.
- `home_widget` 0.10.0 was evaluated in a build spike and removed: it compiles today but applies its own Kotlin Gradle Plugin, causing Flutter 3.47.9 to warn that future Flutter releases will fail with KGP-dependent plugins. The smaller owned MethodChannel avoids that dependency and keeps Android-specific behavior in the Android adapter.
- Apple widgets: Today, next event, deadline; timeline entries and deep links. Do not promise arbitrary tap actions, continuous ticking, or exact refresh timing. Quick Add may open the app to a prefilled form; widget interactivity restrictions vary by platform generation.

## Security boundaries

- No login or cloud by default; no access to mail, messages, contacts or arbitrary phone data.
- Import parsing uses bounded file size/type validation, safe temporary storage and defensive error handling. Treat OCR/parser output as untrusted proposals.
- Database snapshots and backups never enter public Git or diagnostics.
- Calendar and notification permissions are asked only after clear feature intent; revocation produces a visible disconnected state and never deletes schedule records.
- Signing key and private APK handoff never go to Git, project chat or issue trackers.

## Android private-build and update policy

- Keep `app.shiftstudy.mobile` stable and increment `versionCode` for each APK upgrade. Updates require the same package ID and signing identity; preserve SQLite records with schema migrations and an install-over-update acceptance check.
- Debug APKs use the Android debug key and are for local QA only. Release builds are unsigned unless all four `SHIFT_STUDY_*` process environment values are supplied. Store the release keystore outside the repository, maintain two owner-controlled encrypted offline backups, and never put passwords or key material in a committed properties file.
- A direct APK is the personal/private Android artifact; AAB and Play publishing are out of scope. An APK does not install on iOS. Private sharing still requires manual safe transfer and matching signing keys for updates.
