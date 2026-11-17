import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/widgets/week_grid.dart';

void main() {
  testWidgets('week headers expose full dates and the focused day', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    const weekStart = CivilDate(2026, 11, 2);
    const focusDate = CivilDate(2026, 11, 4);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: focusDate,
            occurrences: const [],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final focusedDay = tester.getSemantics(
      find.byKey(const ValueKey('week-day-2026-11-4')),
    );
    expect(focusedDay.label, 'Wednesday, November 4, 2026');
    expect(
      focusedDay.getSemanticsData().flagsCollection.isSelected,
      Tristate.isTrue,
    );
    semantics.dispose();
  });

  testWidgets('week timeline hour labels include AM and PM', (tester) async {
    const weekStart = CivilDate(2026, 11, 2);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: weekStart.addDays(2),
            occurrences: const [],
            conflictedIds: const {},
            use24Hour: true,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('6 AM').hitTestable(), findsOneWidget);
    expect(find.text('12 PM').hitTestable(), findsOneWidget);
    expect(find.text('06').hitTestable(), findsNothing);
  });

  testWidgets('week hour labels stay on one line at 130 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const weekStart = CivilDate(2026, 11, 2);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: WeekGrid(
              weekStart: weekStart,
              focusDate: weekStart.addDays(2),
              occurrences: const [],
              conflictedIds: const {},
              use24Hour: false,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('10 AM'), findsOneWidget);
    expect(tester.getSize(find.text('10 AM')).height, lessThan(36));
    expect(tester.takeException(), isNull);
  });

  testWidgets('week day headers do not overflow at 130 percent text scale', (
    tester,
  ) async {
    const weekStart = CivilDate(2026, 11, 9);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: WeekGrid(
              weekStart: weekStart,
              focusDate: weekStart.addDays(6),
              occurrences: const [],
              conflictedIds: const {},
              use24Hour: false,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('week-day-header'))).height,
      greaterThanOrEqualTo(83.2),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('week day headers do not overflow at 175 percent text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const weekStart = CivilDate(2026, 11, 9);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.75)),
          child: Scaffold(
            body: WeekGrid(
              weekStart: weekStart,
              focusDate: weekStart.addDays(6),
              occurrences: const [],
              conflictedIds: const {},
              use24Hour: false,
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byKey(const Key('week-day-header'))).height,
      greaterThanOrEqualTo(126),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('short events expose date and interval to screen readers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    const day = CivilDate(2026, 11, 4);
    final shortClass = ScheduleItem(
      id: 'qa-short-class',
      kind: ScheduleKind.classSession,
      title: 'QA short class',
      startDate: day,
      intervals: [EventInterval.sameDay(startMinute: 545, endMinute: 560)],
      timeZoneId: 'America/Barbados',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: const CivilDate(2026, 11, 2),
            focusDate: day,
            occurrences: [EventOccurrence(item: shortClass, date: day)],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    const expectedLabel =
        'School: QA short class, Wednesday, November 4, 2026, '
        '9:05 AM – 9:20 AM';
    final event = tester.getSemantics(find.bySemanticsLabel(expectedLabel));
    expect(event.label, expectedLabel);
    expect(event.getSemanticsData().flagsCollection.isButton, isTrue);
    expect(find.text('9:05 AM – 9:20 AM'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('horizontal week scrolling keeps day headers aligned', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const weekStart = CivilDate(2026, 11, 2);
    final sunday = weekStart.addDays(6);
    final sundayClass = ScheduleItem(
      id: 'synthetic-sunday-class',
      kind: ScheduleKind.classSession,
      title: 'QA Sunday class',
      startDate: sunday,
      intervals: [
        EventInterval.sameDay(startMinute: 10 * 60, endMinute: 11 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: weekStart,
            occurrences: [EventOccurrence(item: sundayClass, date: sunday)],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('week-grid-horizontal-scroll')),
          )
          .dragStartBehavior,
      DragStartBehavior.down,
    );
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('week-day-header-scroll')),
          )
          .dragStartBehavior,
      DragStartBehavior.down,
    );

    expect(find.text('Sun').hitTestable(), findsNothing);
    await tester.dragFrom(const Offset(320, 380), const Offset(-750, 0));
    await tester.pumpAndSettle();

    expect(find.text('Sun').hitTestable(), findsOneWidget);
    expect(find.text('QA Sunday class').hitTestable(), findsOneWidget);
    expect(find.text('8 AM').hitTestable(), findsOneWidget);
    expect(find.text('12 PM').hitTestable(), findsOneWidget);
  });

  testWidgets('initially centers the focused day and its event on a phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const weekStart = CivilDate(2026, 11, 2);
    final friday = weekStart.addDays(4);
    final fridayShift = ScheduleItem(
      id: 'focused-friday-shift',
      kind: ScheduleKind.work,
      title: 'QA Friday shift',
      startDate: friday,
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 11 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    final earlierWeekShift = ScheduleItem(
      id: 'earlier-week-shift',
      kind: ScheduleKind.work,
      title: 'QA Monday early shift',
      startDate: weekStart,
      intervals: [
        EventInterval.sameDay(startMinute: 4 * 60, endMinute: 6 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: friday,
            occurrences: [
              EventOccurrence(item: earlierWeekShift, date: weekStart),
              EventOccurrence(item: fridayShift, date: friday),
            ],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final header = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('week-day-header-scroll')),
    );
    final grid = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('week-grid-horizontal-scroll')),
    );
    expect(header.controller!.position.pixels, greaterThan(0));
    expect(
      header.controller!.position.pixels,
      closeTo(grid.controller!.position.pixels, 0.5),
    );
    expect(find.text('Fri').hitTestable(), findsOneWidget);
    expect(find.text(fridayShift.title).hitTestable(), findsOneWidget);
    expect(find.text('9:00 AM – 11:00 AM').hitTestable(), findsOneWidget);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('week-grid-time-scroll')),
          )
          .controller!
          .position
          .pixels,
      closeTo(8 * 64, 1),
      reason: 'the focused Friday event should set the opening timeline',
    );
    final eventTitle = tester.widget<Text>(find.text(fridayShift.title));
    expect(eventTitle.maxLines, 3);
    expect(eventTitle.softWrap, isTrue);
  });

  testWidgets('lets users scroll to earlier days from a Sunday focus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const weekStart = CivilDate(2026, 11, 9);
    final thursday = weekStart.addDays(3);
    final sunday = weekStart.addDays(6);
    final earlyShift = ScheduleItem(
      id: 'qa-early-week-shift',
      kind: ScheduleKind.work,
      title: 'QA Thursday 08:30 shift',
      startDate: thursday,
      intervals: [
        EventInterval.sameDay(startMinute: 8 * 60 + 30, endMinute: 16 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    final sundayShift = ScheduleItem(
      id: 'qa-sunday-shift',
      kind: ScheduleKind.work,
      title: 'QA Sunday 10:00 shift',
      startDate: sunday,
      intervals: [
        EventInterval.sameDay(startMinute: 10 * 60, endMinute: 17 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: sunday,
            occurrences: [
              EventOccurrence(item: earlyShift, date: thursday),
              EventOccurrence(item: sundayShift, date: sunday),
            ],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(sundayShift.title).hitTestable(), findsOneWidget);
    final grid = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('week-grid-horizontal-scroll')),
    );
    grid.controller!.jumpTo(3 * 156);
    await tester.pumpAndSettle();
    expect(find.text(earlyShift.title).hitTestable(), findsOneWidget);
  });
  testWidgets('landscape week keeps a Sunday shift readable and tappable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(834, 411);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const weekStart = CivilDate(2026, 11, 2);
    final sunday = weekStart.addDays(6);
    final shift = ScheduleItem(
      id: 'landscape-sunday-shift',
      kind: ScheduleKind.work,
      title: 'QALandscape64',
      startDate: sunday,
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    var selected = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: sunday,
            occurrences: [EventOccurrence(item: shift, date: sunday)],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) => selected = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sun').hitTestable(), findsOneWidget);
    expect(find.text('9a–5p').hitTestable(), findsOneWidget);
    final title = tester.widget<Text>(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == shift.title,
      ),
    );
    expect(title.maxLines, 3);
    await tester.tap(find.text('9a–5p'));
    expect(selected, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late focused-day events remain visible without an overscroll', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const weekStart = CivilDate(2026, 11, 2);
    final saturday = weekStart.addDays(5);
    final lateShift = ScheduleItem(
      id: 'late-focused-day-shift',
      kind: ScheduleKind.work,
      title: 'QA late shift',
      startDate: saturday,
      intervals: [
        EventInterval.sameDay(startMinute: 23 * 60, endMinute: 23 * 60 + 45),
      ],
      timeZoneId: 'America/Barbados',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: saturday,
            occurrences: [EventOccurrence(item: lateShift, date: saturday)],
            conflictedIds: const {},
            use24Hour: true,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final timeGrid = tester.widget<SingleChildScrollView>(
      find.byKey(const Key('week-grid-time-scroll')),
    );
    final position = timeGrid.controller!.position;
    expect(position.pixels, lessThanOrEqualTo(position.maxScrollExtent));
    expect(find.text(lateShift.title).hitTestable(), findsOneWidget);
  });

  testWidgets('shows an overnight continuation before dawn on the next day', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const weekStart = CivilDate(2026, 11, 2);
    final friday = weekStart.addDays(4);
    final saturday = friday.addDays(1);
    final overnightShift = ScheduleItem(
      id: 'overnight-continuation',
      kind: ScheduleKind.work,
      title: 'QA overnight shift',
      startDate: friday,
      intervals: [
        EventInterval.overnight(startMinute: 21 * 60, endMinute: 3 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: saturday,
            occurrences: [EventOccurrence(item: overnightShift, date: friday)],
            conflictedIds: const {},
            use24Hour: true,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('00:00 – 03:00').hitTestable(), findsOneWidget);
    expect(find.text('QA overnight shift').hitTestable(), findsOneWidget);
  });

  testWidgets('overlapping events open a readable selection list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(700, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = CivilDate.fromDateTime(DateTime.now());
    final monday = today.addDays(1 - today.weekday);
    final firstDay = today;
    ScheduleItem event(String id, int start) => ScheduleItem(
      id: id,
      kind: ScheduleKind.work,
      title: id,
      startDate: firstDay,
      intervals: [
        EventInterval.sameDay(startMinute: start, endMinute: start + 120),
      ],
      timeZoneId: 'America/Barbados',
    );
    final first = event('Overlapping shift A', 9 * 60);
    final second = event('Overlapping shift B', 9 * 60 + 30);
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: monday,
            focusDate: today,
            occurrences: [
              EventOccurrence(item: first, date: firstDay),
              EventOccurrence(item: second, date: firstDay),
            ],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (occurrence) => selected.add(occurrence.item.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final overlapSummary = find.byKey(Key('week-overlap-group-$firstDay-2'));
    expect(overlapSummary, findsOneWidget);
    await tester.tap(overlapSummary);
    await tester.pumpAndSettle();
    expect(find.text(first.title), findsOneWidget);
    expect(find.text(second.title), findsOneWidget);
    await tester.tap(find.text(second.title));
    await tester.pumpAndSettle();
    expect(selected, [second.id]);
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const Key('week-grid-time-scroll')),
          )
          .controller!
          .position
          .pixels,
      greaterThan(0),
    );
  });

  testWidgets('dense overlap group opens a readable list of each event', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = CivilDate.fromDateTime(DateTime.now());
    final monday = today.addDays(1 - today.weekday);
    ScheduleItem event(String id, int start) => ScheduleItem(
      id: id,
      kind: ScheduleKind.work,
      title: id,
      startDate: today,
      intervals: [
        EventInterval.sameDay(startMinute: start, endMinute: start + 120),
      ],
      timeZoneId: 'America/Barbados',
    );
    final first = event('Ramp service 09:00 block', 9 * 60);
    final second = event('Aircraft cabin preparation 09:30', 9 * 60 + 30);
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: monday,
            focusDate: today,
            occurrences: [
              EventOccurrence(item: first, date: today),
              EventOccurrence(item: second, date: today),
            ],
            conflictedIds: {first.id, second.id},
            use24Hour: false,
            onSelect: (occurrence) => selected.add(occurrence.item.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final overlapSummary = find.byKey(Key('week-overlap-group-$today-2'));
    expect(overlapSummary, findsOneWidget);
    expect(find.text('2 overlapping events'), findsOneWidget);
    await tester.tap(overlapSummary);
    await tester.pumpAndSettle();

    expect(find.text(first.title), findsOneWidget);
    expect(find.text(second.title), findsOneWidget);
    await tester.tap(find.text(first.title));
    await tester.pumpAndSettle();
    expect(selected, [first.id]);
  });

  testWidgets('long overlap summary stays at the start of its time span', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = CivilDate.fromDateTime(DateTime.now());
    final monday = today.addDays(1 - today.weekday);
    ScheduleItem event(String id, int start) => ScheduleItem(
      id: id,
      kind: ScheduleKind.work,
      title: id,
      startDate: today,
      intervals: [
        EventInterval.sameDay(startMinute: start, endMinute: 17 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    final events = [
      event('QA long overlap A', 9 * 60),
      event('QA long overlap B', 9 * 60 + 30),
      event('QA long overlap C', 10 * 60),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: monday,
            focusDate: today,
            occurrences: [
              for (final item in events)
                EventOccurrence(item: item, date: today),
            ],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final group = find.byKey(Key('week-overlap-group-$today-3'));
    final summary = find.text('3 overlapping events');
    expect(group, findsOneWidget);
    expect(summary, findsOneWidget);
    final background = tester.widget<Material>(
      find.descendant(of: group, matching: find.byType(Material)).first,
    );
    expect(background.color!.a, lessThan(0.25));
    expect(
      tester.getTopLeft(find.byIcon(Icons.warning_amber_rounded)).dy -
          tester.getTopLeft(group).dy,
      lessThan(24),
    );
    expect(
      tester.getTopLeft(find.byIcon(Icons.chevron_right_rounded)).dy -
          tester.getTopLeft(group).dy,
      lessThan(24),
    );
    expect(
      tester.getTopLeft(summary).dy - tester.getTopLeft(group).dy,
      lessThan(24),
    );
  });

  testWidgets('short timeline events keep a compact visible label', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final today = CivilDate.fromDateTime(DateTime.now());
    final monday = today.addDays(1 - today.weekday);
    final item = ScheduleItem(
      id: 'brief-duty',
      kind: ScheduleKind.work,
      title: 'Brief duty',
      startDate: today,
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 9 * 60 + 15),
      ],
      timeZoneId: 'America/Barbados',
    );
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: monday,
            focusDate: today,
            occurrences: [EventOccurrence(item: item, date: today)],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (occurrence) => selected.add(occurrence.item.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = find.text('Brief duty');
    expect(label, findsOneWidget);
    expect(label.hitTestable(), findsOneWidget);
    await tester.tap(label);
    expect(selected, contains(item.id));
  });

  testWidgets('day header opens the full day agenda for dense week cells', (
    tester,
  ) async {
    const weekStart = CivilDate(2026, 11, 2);
    const day = CivilDate(2026, 11, 4);
    final item = ScheduleItem(
      id: 'dense-day-event',
      kind: ScheduleKind.work,
      title: 'QA dense day shift',
      startDate: day,
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
      ],
      timeZoneId: 'America/Barbados',
    );
    final selected = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: WeekGrid(
            weekStart: weekStart,
            focusDate: day,
            occurrences: [EventOccurrence(item: item, date: day)],
            conflictedIds: const {},
            use24Hour: false,
            onSelect: (occurrence) => selected.add(occurrence.item.id),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wed'));
    await tester.pumpAndSettle();
    expect(find.text('Wednesday, November 4, 2026'), findsOneWidget);
    final agendaEvent = find.text(item.title).last;
    expect(agendaEvent, findsOneWidget);
    await tester.tap(agendaEvent);
    await tester.pumpAndSettle();
    expect(selected, contains(item.id));
  });
}
