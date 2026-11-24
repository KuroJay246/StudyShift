# Shift Overtime Hours Implementation Plan

> Execution: native implementation in this authorized task.

**Goal:** Record extra worked hours on a scheduled shift and report daily/weekly regular and premium-eligible hours accurately.

**Architecture:** Store overtime duration on a specific shift occurrence without extending its planned intervals or creating a second event. Preserve standalone overtime duties for compatibility; include both forms in Overtime views.

**Tech Stack:** Flutter/Dart, Drift/SQLite, Riverpod, existing backup/import/export formats.

**Spec:** User's StudyShift overtime explanation; `docs/ARCHITECTURE.md` and `docs/DESIGN_SPECIFICATION.md`.

## Global Constraints
- Keep overtime entry duration-based; no clock time is required.
- The regular threshold is eight hours; only duration beyond it is premium-eligible.
- Do not calculate wages without a configured rate and applicable payroll rules.
- Preserve existing schedule, recurrence, backup and export data during migration.

## Review Focus
- Split shifts: extra hours can be logged in a scheduled gap or after the final interval.
- Repeated/recurring shifts: extra hours belong to one occurrence date.
- Corrections and imports: totals must not double count.
- Existing standalone overtime events remain visible.
- Eight-hour threshold: only hours beyond eight are marked premium-eligible.

### Task 1: Per-occurrence duration model
**Files:** Domain model, Drift schema/migration, repository, backup/import/export codecs, tests.
- [ ] Add failing tests for adding hours without changing shift intervals, occurrence scoping, migration and backup round-trip.
- [ ] Implement non-negative extra-hours records keyed to shift occurrence, with an optional note/source for auditability.
- [ ] Verify domain, persistence and codec tests.

### Task 2: Work UI and totals
**Files:** Event/shift detail UI, Work page, tests.
- [ ] Add failing tests for recording/correcting hours, Overtime filter membership, daily totals, weekly totals and the eight-hour threshold.
- [ ] Implement duration entry and present scheduled, extra, total and premium-eligible hours.
- [ ] Verify focused UI tests and analyze.

### Task 3: Android acceptance
- [ ] Install current debug build on a dedicated clean emulator only.
- [ ] Exercise regular, split, gap and after-shift overtime entry.
- [ ] Verify totals, Overtime filter, app restart persistence and current-build screenshot evidence.
