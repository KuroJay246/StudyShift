# Roster Batch Import Implementation Plan

> Execution: native implementation in this authorized task.

**Goal:** Import multiple roster periods in one reviewed operation, creating the selected user's shifts and attaching coworkers only to matching shift occurrences.

**Architecture:** A batch preview separates owned shift proposals from per-occurrence coworker updates. Apply the complete review atomically; ambiguous date/code matches remain unresolved. PDF/image OCR remains offline and human-correctable, while CSV/XLSX map into the same preview model.

**Tech Stack:** Flutter/Dart, Drift/SQLite, Riverpod, existing local OCR/file-picker adapters.

**Spec:** User's StudyShift import and coworker requirements; `docs/ARCHITECTURE.md` and `docs/DESIGN_SPECIFICATION.md`.

## Global Constraints
- Keep all imported roster content on-device and out of Git.
- Never create calendar shifts from coworker rows.
- Preserve existing events unless the reviewed batch explicitly updates/replaces them.
- Do not guess ambiguous OCR, duplicate date/code matches, or overlapping roster periods.

## Review Focus
- Same code repeated on one date: match to the exact occurrence or require review.
- Duplicate employee names: preserve spelling and surface identity ambiguity.
- Old/new period overlap: require explicit precedence in preview.
- Off days, month/year boundaries, split and overnight work: keep dates correct.
- Partial parse or OCR uncertainty: never silently save.

### Task 1: Batch proposal model
**Files:** Create focused import batch model/planner under `app/lib/data/`; test under `app/test/data/`.
- [ ] Write failing tests for combined old/new periods, duplicate cells, off days and ambiguous repeated codes.
- [ ] Confirm each fails for missing batch behavior.
- [ ] Implement immutable plan rows for create/update/coworker-only/unresolved outcomes.
- [ ] Verify focused planner tests pass.

### Task 2: One-source multi-file review flow
**Files:** `schedule_import_file_bridge.dart`, `schedule_import_page.dart`, relevant tests.
- [ ] Write failing widget tests for selecting multiple files, owner-row selection per roster, and previewing both schedule and coworker effects before save.
- [ ] Implement file accumulation and a single reviewed save transaction; attach coworkers by date/code without constructing coworker events.
- [ ] Keep ICS event import supported in the same import hub.
- [ ] Verify focused import tests and analyze.

### Task 3: Clean emulator acceptance
- [ ] Use a dedicated empty emulator dataset; retain the personal Galaxy database.
- [ ] Import both roster periods together once both files are available.
- [ ] Check saved shift counts, coworker links, duplicates, ambiguous rows and calendar unchanged for coworker-only inputs.
- [ ] Capture current-build emulator screenshots and record unresolved inputs.
