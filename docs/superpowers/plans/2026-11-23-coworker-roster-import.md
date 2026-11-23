# Coworker Roster Import Implementation Plan

> **For agentic workers:** Use this plan task-by-task with red-green TDD.

**Goal:** Add coworker names from a roster file to uniquely matching saved work shifts without creating or changing schedule entries beyond the coworker list.

**Architecture:** Parse a minimal CSV roster of date, shift code, and coworker names. Match each grouped roster assignment against existing work shifts by civil start date and normalized shift code, then present matched, unmatched, and ambiguous results for review. Save only confirmed coworker-list updates through the existing schedule repository.

**Tech Stack:** Flutter/Dart, existing CSV reader, Drift schedule repository, Riverpod, Flutter widget tests, Android emulator.

**Spec:** Owner instructions in the current StudyShift conversation; project constraints in `AGENTS.md`.

## Global Constraints

- Never create shifts during coworker-only import.
- Never alter shift dates, times, codes, supervisors, or other fields.
- Do not write unmatched or ambiguous rows.
- Keep import files and schedule data local; use only synthetic emulator fixtures.
- Require review and explicit confirmation before saving.

## Review Focus

- Duplicate or repeated coworker names must not add the same name twice.
- Multiple saved shifts with the same date and code must be marked ambiguous.
- Unmatched rows must not create calendar events.
- Matching must use the shift start date and code, including overnight shifts.
- Saving a match must preserve every existing shift field other than coworkers.

### Task 1: Parse and match roster coworker rows

**Files:**
- Modify: `app/lib/data/csv_schedule_import.dart`
- Create: `app/lib/data/coworker_roster_matcher.dart`
- Test: `app/test/data/csv_schedule_import_test.dart`
- Test: `app/test/data/coworker_roster_matcher_test.dart`

**Interfaces:**
- Parse required `date`, `code`, and `coworkers` columns; allow repeated rows and semicolon-separated names.
- Group rows by normalized date and code; preserve optional employer discriminator when supplied.
- Return each assignment as matched, unmatched, or ambiguous against saved work shifts.

**Steps:**
- [x] Add failing tests for parsing, grouping, duplicate names, unique match, no match, and ambiguous matches.
- [x] Run focused tests and confirm the expected failures.
- [x] Implement the smallest parser and matcher that passes.
- [x] Run focused tests and analyzer.

### Task 2: Add review-and-save UI

**Files:**
- Create: `app/lib/presentation/screens/coworker_roster_import_page.dart`
- Modify: `app/lib/presentation/screens/schedule_import_page.dart`
- Test: `app/test/presentation/coworker_roster_import_page_test.dart`

**Steps:**
- [x] Add a distinct toolbar entry point from Import calendar.
- [x] Add a CSV picker, grouped match cards, and explicit save confirmation.
- [x] Prove with widget tests that matched shifts update coworkers while unmatched/ambiguous rows and all other schedule fields remain unchanged.
- [x] Run the full Flutter suite and analyzer.

### Task 3: Verify on an isolated Android review flavor

**Steps:**
- [x] Build and install review flavor `0.1.0+24379` on `emulator-5554` only.
- [x] Import a synthetic coworker roster against a synthetic saved shift.
- [x] Confirm coworkers appear on the existing shift and no extra event was created (3 events before and after).
- [x] Capture current-build screenshots; leave the Galaxy and personal app data untouched.

## Verification outcome

- Full Flutter suite: 467 tests passed.
- Analyzer: no issues found.
- Emulator review package: `app.shiftstudy.mobile.review`, version code `24379`, Android API 36.
- Synthetic CSV matched one `TST1` shift on 2026-11-24 and left one unmatched row untouched. After explicit confirmation the existing row retained its identity, date, code, and coworker data while merging names case-insensitively; database row count stayed at three.
- Scope limitation: coworker-only import currently accepts CSV. XLSX and roster-table PDF/image inputs still need a matching review adapter.
