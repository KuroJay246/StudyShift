import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/widgets/device_calendar_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/device_calendar');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return true;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets(
    'calendar action shows one clear action without duplicate helper copy',
    (tester) async {
      final item = ScheduleItem(
        id: 'synthetic-calendar-spacing',
        kind: ScheduleKind.classSession,
        title: 'Synthetic class',
        startDate: CivilDate(2026, 11, 7),
        timeZoneId: 'America/Barbados',
        intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: DeviceCalendarAction(
                item: item,
                occurrenceDate: item.startDate,
                resolvedIntervals: [
                  ResolvedInterval(
                    start: DateTime.utc(2026, 11, 7, 14),
                    end: DateTime.utc(2026, 11, 7, 15),
                  ),
                ],
                use24Hour: false,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Add to device calendar'), findsOneWidget);
      expect(
        find.textContaining('Opens a draft for you to review and save.'),
        findsNothing,
      );
      expect(tester.getRect(find.byType(OutlinedButton)).width, greaterThan(0));
    },
  );

  testWidgets('split work sends only the interval the user selects', (
    tester,
  ) async {
    final item = ScheduleItem(
      id: 'synthetic-calendar-split',
      kind: ScheduleKind.work,
      title: 'Synthetic split shift',
      startDate: CivilDate(2026, 11, 7),
      timeZoneId: 'America/Barbados',
      code: 'RAMP',
      location: 'Synthetic airport',
      notes: 'Synthetic notes',
      intervals: [
        EventInterval.sameDay(startMinute: 360, endMinute: 600),
        EventInterval.sameDay(startMinute: 780, endMinute: 1020),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCalendarAction(
            item: item,
            occurrenceDate: item.startDate,
            resolvedIntervals: [
              ResolvedInterval(
                start: DateTime.utc(2026, 11, 7, 10),
                end: DateTime.utc(2026, 11, 7, 14),
              ),
              ResolvedInterval(
                start: DateTime.utc(2026, 11, 7, 17),
                end: DateTime.utc(2026, 11, 7, 21),
              ),
            ],
            use24Hour: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add to device calendar'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a shift interval'), findsOneWidget);
    await tester.tap(find.text('Part 2'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'openEventDraft');
    final arguments = Map<Object?, Object?>.from(calls.single.arguments as Map);
    expect(arguments['title'], 'Synthetic split shift');
    expect(
      arguments['startMillis'],
      DateTime.utc(2026, 11, 7, 17).millisecondsSinceEpoch,
    );
    expect(
      arguments['endMillis'],
      DateTime.utc(2026, 11, 7, 21).millisecondsSinceEpoch,
    );
    expect(arguments['allDay'], isFalse);
    expect(arguments['location'], 'Synthetic airport');
    expect(arguments['description'], contains('Code: RAMP'));
    expect(arguments['description'], contains('Synthetic notes'));
  });

  testWidgets('all-day work creates a single civil-date calendar draft', (
    tester,
  ) async {
    final item = ScheduleItem(
      id: 'synthetic-calendar-rest-day',
      kind: ScheduleKind.work,
      title: 'Synthetic rest day',
      startDate: CivilDate(2026, 11, 7),
      workCategory: WorkCategory.restDay,
      intervals: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCalendarAction(
            item: item,
            occurrenceDate: item.startDate,
            resolvedIntervals: const [],
            use24Hour: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add to device calendar'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final arguments = Map<Object?, Object?>.from(calls.single.arguments as Map);
    expect(arguments['allDay'], isTrue);
    expect(
      arguments['startMillis'],
      DateTime.utc(2026, 11, 7).millisecondsSinceEpoch,
    );
    expect(
      arguments['endMillis'],
      DateTime.utc(2026, 11, 8).millisecondsSinceEpoch,
    );
  });

  testWidgets('a repeating class exports only the chosen occurrence', (
    tester,
  ) async {
    final item = ScheduleItem(
      id: 'synthetic-weekly-calendar-class',
      kind: ScheduleKind.classSession,
      title: 'Synthetic weekly class',
      startDate: CivilDate(2026, 11, 2),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
      recurrence: WeeklyRecurrence(weekdays: {DateTime.monday}, until: null),
    );
    final occurrenceDate = CivilDate(2026, 11, 9);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCalendarAction(
            item: item,
            occurrenceDate: occurrenceDate,
            resolvedIntervals: [
              ResolvedInterval(
                start: DateTime.utc(2026, 11, 9, 14),
                end: DateTime.utc(2026, 11, 9, 15),
              ),
            ],
            use24Hour: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add to device calendar'));
    await tester.pumpAndSettle();

    expect(calls, hasLength(1));
    final arguments = Map<Object?, Object?>.from(calls.single.arguments as Map);
    expect(
      arguments['startMillis'],
      DateTime.utc(2026, 11, 9, 14).millisecondsSinceEpoch,
    );
    expect(
      arguments['description'],
      contains('This is one occurrence of a repeating schedule item'),
    );
  });

  testWidgets('unavailable calendar apps show the file export fallback', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    final item = ScheduleItem(
      id: 'synthetic-calendar-no-handler',
      kind: ScheduleKind.classSession,
      title: 'Synthetic calendar class',
      startDate: CivilDate(2026, 11, 7),
      timeZoneId: 'America/Barbados',
      intervals: [EventInterval.sameDay(startMinute: 600, endMinute: 660)],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DeviceCalendarAction(
            item: item,
            occurrenceDate: item.startDate,
            resolvedIntervals: [
              ResolvedInterval(
                start: DateTime.utc(2026, 11, 7, 14),
                end: DateTime.utc(2026, 11, 7, 15),
              ),
            ],
            use24Hour: true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add to device calendar'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No calendar app can create an event. Use Export calendar to save an .ics file.',
      ),
      findsOneWidget,
    );
  });
}
