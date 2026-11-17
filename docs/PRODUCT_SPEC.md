# Product Specification — StudyShift

## Product promise

One calm, trustworthy personal schedule for changing work patterns, education and everyday life. It must handle uncertain imports and overnight work correctly, keep core information available offline, and let each person enable only the work/school/planner areas they need.

**Initial persona:** a Caribbean Aircraft Handling airport ground-handling worker who also studies at UWI Cave Hill. This persona informs discovery; do not hard-code the employer, airline, airport, or university into the domain model. The owner has supplied real roster and examination-timetable examples for field discovery only. Their personal schedule values must not enter app source, automated fixtures, screenshots, or repository documentation.

## Modes and setup

Offer four starting choices: Work, School, Work + School, and Personal Planner. These select enabled modules, not account types or permanent commitments. Modules can be turned on/off later without deleting their data. Setup asks only for locale, time zone, preferred 12/24-hour clock and optional first weekday; explain local-only storage and permission defaults.

## Core information architecture

- **Today:** date and day context; next item, shift/class status, time gaps, tasks/deadlines and concise workload summary. Empty days are intentionally useful and invite one next action.
- **Calendar:** agenda, day, week, and month views; category filters; visible clashes; tablet/desktop two-pane layout.
- **Work:** employer(s), department and role; roster by month/week; shift details and code legend; leave/rest/training/overtime, local notes and separate optional reporting instructions.
- **Study:** institution, term, course timetable; weekly class view; assignments, exams and deadlines; cancelled/moved sessions.
- **Plans:** personal events, tasks and study blocks; reminders and deterministic suggestions.
- **Settings:** modules, appearance, time format, week start, permissions/connections, import history, backup/restore, privacy and about.

Phone navigation should be a small set of stable destinations with Work and Study present only when enabled. Avoid exposing every configuration entity in the primary navigation. Tablet/desktop can use a navigation rail and list/detail or split-pane calendar.

## Essential product capabilities (first usable release scope proposal)

### Schedule foundation

- Create/edit/delete personal events, shifts, classes and tasks manually.
- Support one or more workplaces and academic institutions/terms.
- Store exact start/end dates and time; 12-hour and 24-hour input/display; optional all-day events; location and notes.
- Overnight shifts, split shifts, training, leave, rest days, overtime, shift changes and opaque custom codes.
- Work role, airline assignment, reporting instruction, department and employer-specific legend as optional structured fields.
- Weekly recurring lectures/tutorials/practicals bounded by term dates, exceptions, cancellations and make-up sessions.
- Conflict, overlap and insufficient-rest warnings, always editable/overridable with explanation.
- Day/week/month/agenda views and category filters; access to all records offline.
- Local reminders with permission/precision explanation and a reliable “notifications may be delayed” state where relevant.
- User-owned JSON/ICS export and a validated backup/restore path before any broader import rollout.

### Import workflow

ICS, documented CSV/XLSX, and Android on-device PDF/image OCR feed a review-before-save workflow. OCR only drafts rows with one ISO date and exactly two 24-hour times; all other text remains available for manual review. Every import preserves local provenance, shows parser warnings and ambiguities, supports correction and duplicate comparison, and commits only after explicit confirmation. OCR drafts do not infer roster codes or table layouts. Manual entry remains available for every schedule category.

After a confirmed import, keep a local summary containing only source type, import time, parser version and proposed/accepted/rejected/skipped/warning counts. Keep at most the 50 newest summaries. Do not put the selected file name, path, contents or extracted text in this batch history; event-level provenance remains separate.

No employer format is assumed. Custom parsers require a user-supplied, sanitized sample and confirmed legend, or a well-documented public format. Do not scrape employer or university accounts or automate login without separate approval.

### Calendar integration

Initial goal is explicit “add selected event(s) to device calendar” through OS UI where possible. Later, an optional connection can read existing calendars after a clear user request. Provide calendar chooser, permission state, disconnect/revoke flow and duplication detection. Never turn external events into owned events without saying so, and never delete external events as part of an app edit.

### Widgets

Design and validate native Android widget families for Today, Next Work Shift, Next Class, Combined Week and Upcoming Deadline. Support user-selected source/filter, light/dark/system appearance, readable contrast, resize ranges, tap to open relevant screen, small empty state and stale-data cues. Quick Add is a shortcut to the app's prefilled entry flow. Do not promise minute-by-minute countdown refresh. Add iOS WidgetKit equivalents after Mac/Xcode/device testing; be explicit about limited refresh and interactive controls.

### Planning intelligence (deterministic and explainable)

- Work/class conflict and overlap detection.
- Next-shift/class countdown computed on screen/widget render, not via frequent background polling.
- Scheduled work hours, split interval duration, days on/off and weekly load summaries.
- Available windows around known commitments, with travel/setup buffer configured by user.
- Study-block suggestions placed only in chosen availability windows; user accepts/edits before adding.
- Upcoming deadline and reminder priority; rest gaps as configurable heuristic, never medical advice.
- Label suggestions as estimates, expose the rules and allow dismissal. No paid AI API or cloud inference.

## Advanced capabilities (post-first release)

- Shift swaps, change proposals and history; overtime rate/pay estimates only if user enters local rates.
- ICS and Excel round-trip, institutional term templates, public holiday calendars as optional offline datasets.
- Carefully reviewed PDF/image extraction with on-device OCR fallback and no automatic replacement.
- Separate read-only calendar overlays and calendar writeback with app ownership tags.
- Richer widgets/configuration and Android shortcuts; iOS shortcuts/controls where supported by the OS.
- Encrypted export archives, configurable auto backup and restore/merge.
- Optional synchronization only after a separate privacy, conflict, cost, and backend review.

## Explicit non-goals for current phase

No live integration with Caribbean Aircraft Handling, airlines, UWI systems, Gmail, calendars or cloud services; no account or subscription; no social/team roster service; no AI provider; no public release; no claim that imported roster interpretation is authoritative; no feature implementation until the owner reviews architecture and design choices.

## Import acceptance requirements

For each accepted import, user can answer: What was read? What is uncertain? What changes? What will be retained? What will be written? An accepted event retains its raw input or source reference, canonical interpretation, parser version, user correction and import-batch provenance. Re-importing the same source should not silently duplicate records. A file that cannot be reliably parsed should yield useful manual-entry guidance and no database write.

## Design review deliverable

The owner selected the supplied StudyShift timetable and S-logo concept boards on 2026-11-07. They supersede the three exploratory directions below; `DESIGN.md` records the active visual authority.

Prepare 2–3 visual directions before choosing one:

1. **Shift Atlas:** bold time-grid, quiet charcoal/ivory base with one bright operational accent, compact roster-first overview.
2. **Daylight Ledger:** warm paper-like surfaces, editorial typography, readable mixed work/study cards and gentle planning summaries.
3. **Orbit Schedule:** modular contemporary cards, distinct work/study/personal identity, clear at-a-glance widget composition.

These labels are historical research concepts only. Any further major visual direction requires owner review after seeing real-size phone/tablet layouts and functional screens.
