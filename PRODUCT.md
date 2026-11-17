# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

People who combine changing work schedules, education and personal plans. The first product examples are airport ground-handling work and university classes, but no employer, airline or institution is hard-coded into the app.

## Product Purpose

Keep work, school and everyday commitments in one dependable schedule that is useful without an account, paid service or internet connection.

## Positioning

One locally controlled schedule combines irregular shifts, split or overnight work, recurring classes and personal commitments while preserving their civil dates, time zones and exceptions.

## Operating Context

People check the schedule quickly on a phone, often around shift changes, class days and deadlines. Events must remain available offline and survive ordinary app restarts and APK updates.

## Capabilities and Constraints

The Android-first application uses Flutter/Dart, a local SQLite database through Drift, deterministic schedule queries and native Android adapters only where the operating system requires them. Manual entry is the first input path. No account, cloud service, telemetry, email scanning, subscription or paid dependency is approved. iOS, web and desktop are future clients, not part of this implementation phase.

## Brand Commitments

The owner-selected product name is StudyShift, following the supplied timetable and logo boards: a custom S mark, navy/blue/cyan palette, and five primary destinations (Today, Week, Work, Study and More). Keep work, school, deadline and personal events distinguishable without color alone. Do not copy other products' assets or branding.

## Evidence on Hand

Only synthetic schedules are present in tests and emulator evidence. The concept boards are visual proposals, not proof of implemented screens. No real employer roster, airline assignment or university timetable has been imported.

## Product Principles

- Keep core scheduling private and offline.
- Preserve exact civil dates, time zones, separate intervals and recurrence exceptions.
- Make work and school equally understandable at a glance.
- Explain conflicts and uncertain time interpretations without silently changing user data.
- Make every visible action work and remain usable with accessibility settings enabled.

## Accessibility & Inclusion

Use Material 3 native controls, scalable text, screen-reader names, adequate touch targets and accessible contrast. Category meaning must not depend on color. Respect system reduced-motion settings.
