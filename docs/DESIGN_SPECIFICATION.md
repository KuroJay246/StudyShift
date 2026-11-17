# STUDYSHIFT — MASTER DESIGN IMPLEMENTATION SPECIFICATION

**Version:** 1.0 — Design handoff<br>
**Application:** StudyShift<br>
**Platform:** Flutter Android, with native Kotlin widgets<br>
**Primary target:** Samsung Galaxy S23 FE<br>
**Project:** StudyShift repository

## 1. Implementation objective

Refine the existing StudyShift application to match the approved premium blue visual direction.

Preserve existing scheduling functionality, database contracts, recurrence logic, widget infrastructure and saved information.

Do not rebuild the application from scratch.

The existing generated presentation boards are visual references. This document defines the actual implementation measurements.

Do not use a full presentation-board image as an application background or launcher icon.

Do not introduce an authentication screen, registration system or separate Home destination.

The application opens to **Today**.

## 2. Brand identity and launcher icon

### Approved branding

- Product name: `StudyShift`
- Wordmark: **Study** in midnight navy, **Shift** in vivid cobalt blue
- Tagline: `Work • Study • Plan`
- Primary symbol: The approved stylized S with horizontal segmented schedule marks
- Brand personality: Modern, precise, premium, organized, dependable

### Authoritative brand colors

| Token | Value | Use |
|---|---|---|
| `brand.navy` | `#0B1F5B` | Icon background, wordmark |
| `brand.cobalt` | `#0D5BFF` | Brand gradients |
| `brand.cyan` | `#1FB6FF` | Symbol highlights |
| `brand.ice` | `#CFEAFF` | Highlights and light accent |
| `brand.white` | `#FFFFFF` | Light surfaces and symbol highlights |

### Launcher icon source requirements

The approved S must be recreated as a clean vector master, following the selected reference image.

It must retain:

- The large recognizable S.
- The white-to-blue/cyan gradient within the symbol.
- Both sets of segmented schedule marks.
- The deep navy-to-cobalt icon background.
- Accurate proportions and balanced margins.

Do not replace the S with a generic calendar, book, graduation cap or plain letter.

Do not render the entire launcher icon as one undifferentiated blue gradient.

### Required asset exports

| Asset | Specification |
|---|---|
| `studyshift-symbol.svg` | Editable S symbol, transparent background |
| `studyshift-wordmark.svg` | Editable horizontal wordmark |
| `studyshift-icon-master.svg` | Master assembled icon |
| `studyshift-adaptive-foreground.xml/svg` | Transparent foreground, S centered |
| `studyshift-adaptive-background.xml` | Navy/blue background without the S |
| `studyshift-monochrome.xml/svg` | One-color icon for Android themed icons |
| `studyshift-icon-1024.png` | High-resolution preview |
| `studyshift-icon-512.png` | General-purpose preview |
| Android mipmap icons | Appropriate platform-density exports |

The production icon must use Android adaptive-icon resources.

**Adaptive canvas:** 108 × 108 dp.

**Safe content area:** Centered 66 × 66 dp.

Keep the critical S silhouette and segmented details inside that safe area.

Provide matching adaptive icon layers and a monochrome variant.

Do not bake launcher-specific rounded corners or system shadows into the foreground.

### Acceptance

Verify the actual installed launcher icon at small and large sizes, including circular and rounded-square launcher masks.

Capture the icon beside other installed applications.

Ensure the icon is not cropped, blurred, disproportionate, or replaced by a blue gradient without its S symbol.

Preserve the existing Android package identity.

## 3. Authoritative light-mode design tokens

The icon gradient and the application UI palette are related but not identical.

Use the following UI roles:

| Token | Hex |
|---|---|
| `ui.primary` | `#0D47E1` |
| `ui.secondary` | `#2563EB` |
| `ui.accent` | `#60A5FA` |
| `ui.background` | `#F7F9FE` |
| `ui.surface` | `#FFFFFF` |
| `ui.surfaceAlt` | `#EDF3FF` |
| `ui.textPrimary` | `#0F172A` |
| `ui.textSecondary` | `#475569` |
| `ui.border` | `#DCE5F3` |
| `ui.onPrimary` | `#FFFFFF` |

Page backgrounds should be predominantly light neutral surfaces.

Use strong blue for:

- Selected navigation
- Primary calls to action
- Focus and selection accents
- Selected tabs
- Occasional featured event surfaces

Do not use blue gradients indiscriminately on cards, forms, navigation bars and page backgrounds.

## 4. Dark-mode design tokens

| Token | Hex |
|---|---|
| `dark.primary` | `#7DB4FF` |
| `dark.secondary` | `#59B8FF` |
| `dark.background` | `#000000` |
| `dark.surface` | `#000000` |
| `dark.surfaceAlt` | `#121212` |
| `dark.surfaceRaised` | `#1E1E1E` |
| `dark.textPrimary` | `#F5F5F5` |
| `dark.textSecondary` | `#B3B3B3` |
| `dark.border` | `#303030` |

Dark mode requires its own contrast-tested surfaces and component states.

Do not simply invert the light theme.

## 5. Semantic event colors

| Category | Color | Purpose |
|---|---|---|
| Work | `#2563EB` | Shifts and work commitments |
| Study | `#7C3AED` | Classes and academic commitments |
| Personal | `#0D9488` | Personal activities |
| Training | `#C28113` | Training and special duty |
| Success | `#16A34A` | Confirmed/saved state |
| Warning | `#B45309` | Important warning |
| Error / Conflict | `#D92D20` | Conflicts and failures |

Event cards should use a restrained category indicator, such as a 4 dp colored leading strip, icon and label.

Do not fill every event card with saturated category colors.

Do not communicate event meaning using color alone.

## 6. Typography specification

### Primary typeface

Use **Inter** as the preferred UI typeface, subject to obtaining an appropriately licensed source and bundling it correctly in the Flutter project.

Supported weights:

- Regular 400
- Medium 500
- Semibold 600
- Bold 700

Fallback: Roboto/system sans-serif.

Do not use random fonts per screen.

### Typography scale

| Element | Size | Weight | Line height |
|---|---:|---:|---:|
| Main greeting | 28 sp | 700 | 34 sp |
| Screen heading | 24 sp | 700 | 30 sp |
| Section heading | 18 sp | 700 | 24 sp |
| Card title | 16 sp | 600 | 22 sp |
| Body primary | 16 sp | 400 | 24 sp |
| Body secondary | 14 sp | 400 | 20 sp |
| Button text | 14 sp | 600 | 20 sp |
| Event time | 14 sp | 600 | 20 sp |
| Field text | 16 sp | 400 | 24 sp |
| Caption | 12 sp | 400 | 16 sp |
| Navigation label | 12 sp | 500 | 16 sp |

### Important time formatting

Use tabular figures for dates, durations, roster times and aligned numerical content.

In Flutter, use the appropriate `FontFeature.tabularFigures()` support where available.

Do not arbitrarily shrink text to fit schedule cards.

Prefer wrapping, adaptive layouts or an appropriate detail view.

Respect system font-scaling and accessibility settings.

## 7. Layout foundation

### Units

All Flutter layout measurements must be in logical pixels, equivalent to Android dp for this design purpose.

Text sizes are specified in sp-equivalent logical sizing, with system text scaling respected.

Do not copy raw screenshot pixels directly into widget dimensions.

### Reference frames

Design and test at:

| Frame | Logical size |
|---|---|
| Compact phone | 360 × 800 |
| Standard phone | 393 × 851 |
| Large phone | 412 × 915 |
| Expanded layout | 600 dp or wider |
| Landscape | Responsive to available width and height |

These are reference frames, not hardcoded display constraints.

### Global spacing scale

`4, 8, 12, 16, 20, 24, 32 dp`

### Standard dimensions

| Component | Target |
|---|---|
| Page horizontal margin | 16 dp |
| Expanded page margin | 24 dp |
| Top app bar | 64 dp |
| Bottom navigation | 80 dp, excluding system inset |
| Navigation icon | 24 dp |
| Card padding | 16 dp |
| Card radius | 16 dp |
| Large surface radius | 24 dp |
| Form input height | 56 dp |
| Primary button minimum height | 48 dp |
| Button radius | 14 dp |
| Filter chip height | 36 dp |
| Floating action button | 56 × 56 dp |
| Standard icon | 24 dp |
| Dense inline icon | 20 dp |
| Minimum touch target | 48 × 48 dp |

Respect actual Android status-bar, gesture-navigation and keyboard insets.

Do not recreate the Android status bar or navigation bar as fake app components.

## 8. Navigation system

The five primary destinations are fixed for the combined Work + School experience:

| Position | Label | Icon family | Route |
|---|---|---|---|
| 1 | Today | House/home | `/today` |
| 2 | Week | Calendar | `/week` |
| 3 | Work | Briefcase | `/work` |
| 4 | Study | Graduation cap | `/study` |
| 5 | More | Four-square grid | `/more` |

Use consistent Material Symbols Rounded-style outlined/filled icons, or an equally consistent supported set.

Selected navigation:

- Filled icon
- Strong blue emphasis
- Selected label
- Accessible selected state

Unselected navigation:

- Outlined icon
- Muted text
- No extra decorative shapes

The selected tab must remain correct after editing an event and returning.

The application opens to Today.

Do not create an additional Home tab.

## 9. Today screen specification

### Purpose

Show the user's current day immediately and clearly.

### Content order

1. Compact StudyShift wordmark or page identity.
2. Optional notification action when supported.
3. Greeting and current date.
4. Next Up featured event.
5. Today's Schedule.
6. Availability and conflicts when available.
7. Quick Add action.
8. Bottom navigation.

### Design rules

Use one prominent Next Up card, approximately 112–144 dp high depending on content.

The featured card may use a contained navy-to-blue gradient.

Ordinary events use white/light surfaces with subtle borders.

Each event should show:

- Category icon
- Event title
- Start and end time
- Optional location
- Appropriate status information

Minimum event card height: approximately 76 dp, expanding when content requires.

The Add Event control must not cover schedule information.

### Required states

- Empty day
- One event
- Several events
- Work and class overlap
- Overnight event
- Unresolved time warning
- Loading
- Save failure

## 10. Week screen specification

### Purpose

Provide a precise weekly timetable suitable for complicated work and school schedules.

### Grid structure

- Week navigation header.
- Weekday selector.
- Horizontal day columns.
- Vertical time axis.
- Scrollable schedule.
- Distinct work/study event blocks.
- Selected event detail action.

### Recommended dimensions

- Time gutter: 48 dp.
- Day header: 56–64 dp.
- Default hour row: 64 dp.
- Minimum visible event block: 30 dp, with accessible detailed view.
- Event corner radius: 8 dp.
- Internal event padding: 4–6 dp.
- Grid lines: very light neutral borders.

Automatically focus on relevant working hours rather than always beginning at midnight.

Allow scrolling to earlier and overnight events.

Overlapping events must remain visible independently.

A floating button cannot obscure the last calendar entry.

Test split shifts, overnight shifts and three simultaneous events.

## 11. Work screen specification

### Purpose

Manage employment scheduling and roster information.

### Header and filters

Screen heading: Work.

Filter chips:

- Shifts
- Roster
- Leave
- Training

Only display interactive features as active if they actually work.

### Work card content

- Date badge
- Shift code or title
- Start/end time
- Employer or department, if configured
- Location or notes when relevant
- Clear tap-to-edit interaction

### Summary information

Optional weekly summary cards may show:

- Scheduled hours
- Number of shifts
- Training sessions

Display only statistics that can be calculated reliably.

Do not fabricate attendance percentages or pay figures.

## 12. Study screen specification

### Purpose

Manage academic activities.

### Header and filters

Screen heading: Study.

Filter chips:

- Classes
- Assignments
- Exams

### Class cards

- Course name
- Course code
- Date or recurrence information
- Start/end time
- Location
- Category icon

### Deadline cards

When implemented, show:

- Assignment or exam title
- Course
- Due date
- Status
- Direct detail action

Use purple academic accents consistently.

## 13. More screen specification

### Purpose

Provide access to app configuration and tools.

Do not use More as a second home screen.

Do not place an oversized StudyShift promotional/profile card at the top.

The page should open with the heading **More**, then relevant sections.

Suggested entries:

- Settings
- Appearance
- Notifications and reminders
- Backup and restore
- Import schedule
- Calendar export
- Widget settings
- About

Only enable entries backed by working functionality.

Hide unfinished features or label them clearly as unavailable.

Do not pretend that an offline-only application has an account profile or authentication settings.

The StudyShift brand can appear discreetly in About.

## 14. Event editor specification

The event editor is a key workflow and must receive the same design attention as the five main screens.

### Proposed sequence

1. Choose Work, Study or Personal event.
2. Enter the event title.
3. Set date.
4. Set start/end time.
5. Set recurrence where applicable.
6. Add location and optional details.
7. Review warnings.
8. Save or cancel.

### Layout

- One-column form on compact phones.
- 16 dp horizontal padding.
- 12–16 dp between related fields.
- 24 dp between major sections.
- Native-feeling date and time controls.
- 56 dp standard input height.
- Sticky or safely reachable Save action.
- Keyboard-safe scrolling.

Advanced time-zone controls should be grouped under an Advanced section.

Do not expose developer jargon such as daylight-saving fold terminology unnecessarily during ordinary entry.

Include appropriate validation and error feedback.

For deletion, require confirmation and preserve any recurrence-specific meaning.

## 15. Home-screen widget design system

Widgets must use the same brand identity but simpler visual composition.

The native widget is not a Flutter screen.

Do not treat widget screenshots as implementable source.

### Widget A — Next Event

**Target launcher footprint:** 2 × 2 cells.

Show:

- Category
- Next event title
- Start time
- Optional date
- Clear tap-to-open action

Use a compact layout.

### Widget B — Today Schedule

**Target launcher footprint:** 4 × 2 cells.

Show:

- Today's date
- Two upcoming events where space permits
- Category icons
- Time labels

Overflow should be handled gracefully.

### Widget C — Expanded Today

**Target launcher footprint:** 4 × 3 cells.

Show:

- Date
- Three or more events, according to available size
- Optional conflict indication
- Empty state when appropriate

### Widget D — Weekly Overview

**Target launcher footprint:** 4 × 4 cells.

Show:

- Current week
- Selected date
- Compact day summaries
- Important upcoming events
- Navigation into the app

### Widget E — Next Work/Class

Provide separately configurable categories where the supported widget architecture permits.

Examples:

- Next Shift
- Next Class

### Widget styling

Use:

- 16–24 dp inner padding depending on available size.
- Rounded surfaces where supported.
- Readable typography.
- Clear category labels.
- Minimal decoration.
- Light and dark variants.
- No tiny ornamental text.
- No unverified countdown promises.

Prefer responsive size buckets over layouts that assume every 4 × 2 launcher grid is physically identical.

Implement using the current Android widget infrastructure where appropriate.

### Widget functionality

Verify:

- Real saved data.
- Day rollover.
- Updates after edits.
- Normal app restart.
- Widget resizing.
- Empty schedules.
- Deleted events.
- Correct selected event.
- Safe tap actions.
- Dark/light contrast.
- Samsung launcher behavior.

The system controls many background refresh and resizing behaviors. Respect these limitations.

## 16. Responsive layout rules

For portrait phones, retain the five-destination bottom navigation.

For wider layouts, evaluate navigation rail adaptation.

For landscape phones, prevent:

- Clipped forms.
- Overlapping buttons.
- Hidden calendar information.
- Unreachable Save actions.
- Excessively narrow timetable columns.

Avoid fixed-height layouts that cannot scroll.

All primary interactions must remain accessible with enlarged text.

## 17. Animation and interaction specifications

Use restrained motion.

Recommended targets:

- Routine transitions: approximately 180–220 ms.
- Short exits: approximately 120–180 ms.
- Visible pressed states.
- Clear loading feedback.
- No excessive bouncing.
- No decorative animation delaying navigation.

Respect reduced-motion preferences.

Use appropriate semantic feedback for save, delete, error and conflict states.

## 18. Design assets and project deliverables

Create these as real editable implementation assets inside the existing project:

### Brand

- Vector S symbol.
- Vector wordmark.
- Launcher adaptive foreground.
- Launcher background.
- Monochrome themed icon.
- App icon previews.

### Design source

- Authoritative tokens in JSON or another structured format.
- Flutter `ThemeData`/`ColorScheme`.
- Flutter typography definitions.
- Spacing and radius constants.
- Reusable component specifications.
- Light and dark themes.

### UI designs

Prepare editable frames or component specifications for:

- Today
- Week
- Work
- Study
- More
- Add/Edit Event
- Event Details
- Empty states
- Error/conflict states
- Widget variants

A Figma file is desirable if available, but not a prerequisite for implementing the approved tokens and Flutter components.

Do not claim an SVG, Figma file or PNG export exists unless it has actually been created and verified.

### Suggested source organization

Keep files within the existing authoritative project.

Possible design modules:

- `app/lib/design/studyshift_colors.dart`
- `app/lib/design/studyshift_typography.dart`
- `app/lib/design/studyshift_spacing.dart`
- `app/lib/design/studyshift_theme.dart`
- `app/lib/design/studyshift_components.dart`

Adapt paths to the existing architecture; do not duplicate working theme modules.

## 19. Visual verification and acceptance
