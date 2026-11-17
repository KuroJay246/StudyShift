# StudyShift Design System

The owner approved the complete StudyShift visual and interaction specification on 2026-11-07. Its exact color roles, typography, dimensions, navigation, screen behavior, widgets and acceptance guidance are preserved in [DESIGN_SPECIFICATION.md](DESIGN_SPECIFICATION.md). Structured implementation tokens are in [design-tokens.json](design-tokens.json).

## Direction

Use a clean, premium Android schedule UI: white cards on a quiet cool-neutral canvas in light mode; individually tuned deep navy surfaces in dark mode; restrained cobalt actions; cyan brand highlights; and semantic color accents for work, study, personal plans and training. The launcher mark is the S ribbon with two rows of three schedule dashes. Do not use a concept-board image as an app screen or app icon.

## Information hierarchy

The app opens on Today. Combined mode keeps the five primary destinations Today, Week, Work, Study and More. Today leads with identity, date, Next Up and the day's schedule. Week prioritizes accurate grid reading. Work and Study expose only functional filters. More contains working tools and settings without a promotional profile card.

## Interaction and layout

Use the specification's 4–32 dp spacing scale, 16 dp page margins and cards, 56 dp inputs, 48 dp minimum touch targets, restrained transitions and platform insets. Preserve a scrollable single-column phone layout, protect landscape actions and adapt wider layouts with a navigation rail. Category meaning is always conveyed by labels/icons as well as color.

## Type and implementation

The system provides the specified size/weight/line-height roles. Roboto is the safe bundled-system fallback until an appropriately licensed Inter font package is deliberately added. The shared Material 3 theme and local SVG icon set are the implementation source of truth.

## Approval boundary

The supplied design specification now authorizes implementing its visual direction. The prior hold on visual work is superseded. Do not add concepts or features beyond the approved spec, and preserve scheduling, database, recurrence, widget and saved-data behavior.
