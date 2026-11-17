# Shift & Study Project Instructions

## Project boundary

Shift & Study is a standalone personal scheduling application. Keep its source, Git history, application identifiers, data, credentials, builds, and services separate from every other project. Never copy private data, branding, assets, credentials, or unrelated code from another project. Use synthetic fixtures for all development and testing. Do not create cloud projects or services; future sync needs a separate owner decision.

## Current phase and authority

Current phase: Android Phase 1 implementation. Flutter/Dart is owner-selected. Implement domain, persistence, validation, tests and Android integration within the approved scope. The owner-selected product name is StudyShift. The owner approved the complete StudyShift UI/UX implementation specification on 2026-11-07. Follow `docs/DESIGN_SPECIFICATION.md` and `docs/design-tokens.json` for branding, screen layouts, colors, typography, spacing, motion and acceptance. Preserve scheduling, database, recurrence, widget and saved-data behavior. The prior visual pause is superseded only for the owner-approved direction.

The owner designated `https://github.com/KuroJay246/StudyShift.git` as the public source repository on 2026-11-14. This authorizes reviewed StudyShift source and documentation commits to that repository only. It does not authorize publishing APKs, app-store release, paid services, cloud backends, or production integrations. Keep all personal schedules, imports, signing material, credentials, APKs, screenshots and local build outputs out of Git.

## Required JVM baseline

Use project-local JDK 21 at `.devtools/jdk-21.0.12.1+1` for Android/Gradle builds. Set `JAVA_HOME` only inside project tool invocations; do not change machine-wide Java settings or PATH. Keep Android source/bytecode compatibility separate from the Gradle runtime JDK and target only APIs supported by Android.

## Proposed architecture status

`docs/ARCHITECTURE.md` records the selected Flutter/Dart Android-first architecture. Keep core logic platform-neutral; add Kotlin Android code only for native widgets or OS APIs. Drift/SQLite, Riverpod, GoRouter and timezone dependencies are pinned in `app/pubspec.yaml` with `pubspec.lock`; keep their use purposeful. This phase does not implement iOS, web or desktop.

## Privacy and security

- Core scheduling must work offline and without account creation.
- Store personal schedules in the app's private local sandbox. No telemetry, tracking, external AI calls, or network access by default.
- Request permissions only at the point a user invokes an integration, explain why, and degrade gracefully after denial/revocation.
- Treat imports as untrusted files. Never execute imported data. Keep original files local only when the user chooses, and never silently overwrite accepted events.
- Preserve source text, parsed interpretation, time zone, provenance, and user confirmation separately.
- Never delete, edit, or duplicate external calendar data without explicit user choice and reliable ownership tracking.
- Backups must be explicit, validated, and understandable. Do not log schedule contents or sensitive filenames.
- Future synchronization must be a separately reviewed optional adapter; no backend is approved.

## Scheduling correctness

Model local civil date/time, IANA time zone, resolved instants, recurrence, exceptions, and separate work intervals explicitly. Overnight shifts carry an end date on the following day. Split shifts retain their separate intervals. Preserve original roster text and unknown codes; never infer an employer abbreviation as a regular shift without a confirmed legend. Flag ambiguous dates, incomplete intervals, and conflicts for user review.

## Design authority

The owner approved the detailed StudyShift UI/UX specification on 2026-11-07. Follow `docs/DESIGN_SPECIFICATION.md` and `docs/design-tokens.json` for the logo, palette, typography, spacing, screens, widgets, motion and accessibility. Preserve the StudyShift name, approved S mark and existing five destinations. The supplied boards are visual references, not app backgrounds. Continue the approved implementation while keeping work, study and other categories distinguishable by labels/icons as well as color. Use Material 3 behavior, system insets and responsive layouts. For each concept-led refinement, compare the current build’s rendered screen to the relevant approved concept; layout hierarchy, spacing, density, text emphasis and theme behavior must stay aligned. Passing tests or a previous build alone do not establish visual acceptance. Track remaining visible drift by screen and do not mark concept fidelity complete until rechecked on a current build.

Every app-owned route and state must have a deliberate, production-quality StudyShift interface, including setup/configuration flows, dialogs, loading, empty, unavailable, error, success and confirmation states. Apply the approved design tokens, readable hierarchy, responsive layout, accessibility labels and touch targets throughout; do not expose debug-like screens, raw framework defaults or unstyled forms. When an OS or launcher owns a surface, keep its ownership clear and use only documented platform UI where that ownership requires it.

## Quality and evidence

Use synthetic cases. Test time parsing, overnight/split intervals, recurrence, time-zone transitions, imports, duplicates, conflicts, persistence, permissions, widgets, backups, upgrades, accessibility, responsive layouts, and battery-sensitive behavior. Label source tests, emulator checks, physical-device acceptance, and release evidence separately. Do not claim runtime behavior without matching-build evidence.

Use installed tools where applicable: GitHub read/search for public source research, REA for artifact/device inspection when needed, Playwright and Chrome DevTools for browser work, Android SDK/ADB/emulator for Android verification, and current official platform documentation. No dedicated Flutter skill is available in the current Codex skill catalog. Do not install duplicate tool collections or change global Codex settings.

## Git and cleanup

Use only the owner-approved `origin` at `https://github.com/KuroJay246/StudyShift.git`. Review `git status` and exact diffs before each commit and push. Stage only intended files. Never commit keys, credentials, personal schedules/imports, generated APKs, runtime screenshots, build directories, or caches. Do not force-push or run broad cleanup commands. Remove only verified project-owned disposable artifacts.

## Completion boundary for this phase

This phase is complete when the first local offline alpha builds and its required scheduling, persistence, widget, and Android emulator checks are evidenced. Functional screen composition is authorized in the approved direction. Device-specific acceptance requires the owner's Galaxy S23 FE.
