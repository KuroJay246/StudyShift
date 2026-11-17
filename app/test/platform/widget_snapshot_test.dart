import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/schedule_queries.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/domain/schedule_engine.dart';
import 'package:shift_study/platform/widget_snapshot.dart';
import 'package:shift_study/platform/widget_snapshot_publisher.dart';
import 'package:shift_study/platform/widget_snapshot_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/widget_snapshot');

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  test('snapshot preserves overnight interval dates and upcoming identity', () {
    final day = CivilDate(2026, 11, 5);
    final shift = ScheduleItem(
      id: 'synthetic-shift',
      kind: ScheduleKind.work,
      title: 'Ramp duty',
      startDate: day,
      intervals: [
        EventInterval.overnight(startMinute: 22 * 60 + 30, endMinute: 6 * 60),
      ],
      code: 'SIM',
      location: 'Test location',
      timeZoneId: 'America/Barbados',
    );
    final queries = ScheduleQueries(const ScheduleEngine());
    final now = DateTime(2026, 11, 5, 12);
    final snapshot = WidgetSnapshot.forSchedule(
      items: [shift],
      queries: queries,
      now: now,
    );

    final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    expect(json['schemaVersion'], 7);
    expect(json['localDate'], '2026-11-05');
    expect(json['today'], hasLength(1));
    expect(json['next']['id'], 'synthetic-shift');
    expect(json['next']['timeZoneId'], 'America/Barbados');
    expect(json['upcoming'], hasLength(1));
    expect(json['upcoming'][0]['localDate'], '2026-11-05');
    expect(json['throughDate'], '2026-12-05');
    expect(
      json['today'][0]['intervals'][0]['endEpochMillis'],
      DateTime.utc(2026, 11, 6, 10).millisecondsSinceEpoch,
    );
  });

  test(
    'snapshot labels future recurrence dates for native widget rollover',
    () {
      final day = CivilDate(2026, 11, 5);
      final classEntry = ScheduleItem(
        id: 'synthetic-weekly-class',
        kind: ScheduleKind.classSession,
        title: 'Weekly lab',
        startDate: day,
        intervals: [
          EventInterval.sameDay(startMinute: 10 * 60, endMinute: 11 * 60),
        ],
        recurrence: WeeklyRecurrence(
          weekdays: {DateTime.saturday},
          until: CivilDate(2026, 11, 14),
        ),
      );
      final snapshot = WidgetSnapshot.forSchedule(
        items: [classEntry],
        queries: ScheduleQueries(const ScheduleEngine()),
        now: DateTime(2026, 11, 5, 9),
      );

      final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      expect(json['today'], isEmpty);
      expect((json['upcoming'] as List).map((entry) => entry['localDate']), [
        '2026-11-07',
        '2026-11-14',
      ]);
    },
  );

  test(
    'snapshot keeps the next event by widget filter beyond its 30-day window',
    () {
      final today = CivilDate(2026, 11, 5);
      ScheduleItem timedEvent({
        required String id,
        required ScheduleKind kind,
        required int daysAhead,
      }) => ScheduleItem(
        id: id,
        kind: kind,
        title: id,
        startDate: today.addDays(daysAhead),
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
        ],
      );
      final snapshot = WidgetSnapshot.forSchedule(
        items: [
          timedEvent(
            id: 'far-personal',
            kind: ScheduleKind.personal,
            daysAhead: 35,
          ),
          timedEvent(id: 'far-work', kind: ScheduleKind.work, daysAhead: 40),
          timedEvent(
            id: 'far-class',
            kind: ScheduleKind.classSession,
            daysAhead: 45,
          ),
        ],
        queries: ScheduleQueries(const ScheduleEngine()),
        now: DateTime(2026, 11, 5, 8),
      );

      final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      final filteredNext = json['nextByFilter'] as Map<String, dynamic>;
      expect(json['upcoming'], isEmpty);
      expect((json['next'] as Map)['id'], 'far-personal');
      expect((filteredNext['all'] as Map)['id'], 'far-personal');
      expect((filteredNext['work'] as Map)['id'], 'far-work');
      expect((filteredNext['study'] as Map)['id'], 'far-class');
    },
  );

  test('snapshot exposes the next date-only deadline beyond 30 days', () {
    final today = CivilDate(2026, 11, 5);
    final assignment = ScheduleItem(
      id: 'synthetic-far-assignment',
      kind: ScheduleKind.deadline,
      deadlineType: DeadlineType.assignment,
      title: 'Long-range project submission',
      startDate: today.addDays(45),
      intervals: const [],
    );
    final snapshot = WidgetSnapshot.forSchedule(
      items: [assignment],
      queries: ScheduleQueries(const ScheduleEngine()),
      now: DateTime(2026, 11, 5, 8),
    );

    final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
    final filtered = json['nextAllDayByFilter'] as Map<String, dynamic>;
    expect(json['upcoming'], isEmpty);
    expect(filtered['deadline']['id'], assignment.id);
    expect(filtered['deadline']['localDate'], '2026-12-20');
    expect(filtered['deadline']['intervals'], isEmpty);
  });

  test('snapshot separates next classes from upcoming deadlines', () {
    final today = CivilDate(2026, 11, 5);
    ScheduleItem event({
      required String id,
      required ScheduleKind kind,
      required int startMinute,
    }) => ScheduleItem(
      id: id,
      kind: kind,
      title: id,
      startDate: today.addDays(1),
      intervals: [
        EventInterval.sameDay(
          startMinute: startMinute,
          endMinute: startMinute + 60,
        ),
      ],
    );
    final snapshot = WidgetSnapshot.forSchedule(
      items: [
        event(id: 'class', kind: ScheduleKind.classSession, startMinute: 11 * 60),
        event(id: 'deadline', kind: ScheduleKind.deadline, startMinute: 9 * 60),
        event(id: 'shift', kind: ScheduleKind.work, startMinute: 8 * 60),
      ],
      queries: ScheduleQueries(const ScheduleEngine()),
      now: DateTime(2026, 11, 5, 8),
    );

    final nextByFilter = jsonDecode(snapshot.encode())['nextByFilter'] as Map;
    expect(nextByFilter['class']['id'], 'class');
    expect(nextByFilter['deadline']['id'], 'deadline');
  });

  test('snapshot store reports native persistence failure', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => false);
    await expectLater(
      WidgetSnapshotStore(channel: channel).save('{}'),
      throwsA(isA<PlatformException>()),
    );
  });

  test(
    'snapshot exposes unresolved wall times instead of inventing instants',
    () {
      final day = CivilDate(2026, 11, 1);
      final item = ScheduleItem(
        id: 'ambiguous-class',
        kind: ScheduleKind.classSession,
        title: 'Synthetic repeated-hour class',
        startDate: day,
        timeZoneId: 'America/New_York',
        intervals: [EventInterval.sameDay(startMinute: 90, endMinute: 150)],
      );
      final snapshot = WidgetSnapshot.forSchedule(
        items: [item],
        queries: ScheduleQueries(const ScheduleEngine()),
        now: DateTime(2026, 11, 1, 12),
      );

      final json = jsonDecode(snapshot.encode()) as Map<String, dynamic>;
      expect(json['today'].single['intervals'], isEmpty);
      expect(json['today'].single['timeIssues'], ['ambiguousStart']);
      expect(json['next'], isNull);
    },
  );

  test(
    'publisher uses the shared query service and writes its snapshot',
    () async {
      String? savedJson;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'saveSnapshot');
            savedJson = call.arguments as String;
            return true;
          });
      final day = CivilDate(2026, 11, 5);
      final classEntry = ScheduleItem(
        id: 'synthetic-class',
        kind: ScheduleKind.classSession,
        title: 'Discrete Mathematics',
        startDate: day,
        intervals: [
          EventInterval.sameDay(startMinute: 9 * 60, endMinute: 10 * 60),
        ],
        code: 'MATH-SIM',
      );
      final publisher = WidgetSnapshotPublisher(
        queries: ScheduleQueries(const ScheduleEngine()),
        store: WidgetSnapshotStore(channel: channel),
      );

      await publisher.publish([classEntry], DateTime(2026, 11, 5, 8));

      final json = jsonDecode(savedJson!) as Map<String, dynamic>;
      expect(json['today'].single['id'], 'synthetic-class');
      expect(json['next']['kind'], 'classSession');
    },
  );
}
