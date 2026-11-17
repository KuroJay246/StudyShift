import 'package:flutter/services.dart';

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/local_reminders.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');

  test(
    'removing or editing an event clears its already-shown reminder',
    () async {
      final now = DateTime.utc(2026, 11, 6, 14, 10);
      final unchanged = _item(
        id: 'keep',
        title: 'Keep reminder',
        startMinute: 10 * 60 + 4,
      );
      final edited = _item(
        id: 'edited',
        title: 'Edited reminder',
        startMinute: 10 * 60 + 9,
      );
      final notifications = [
        _active(
          unchanged,
          startEpoch: DateTime.utc(2026, 11, 6, 14, 4).millisecondsSinceEpoch,
          id: 11,
        ),
        _active(
          edited,
          startEpoch: DateTime.utc(2026, 11, 6, 14, 4).millisecondsSinceEpoch,
          id: 12,
        ),
        const {
          'id': 13,
          'channelId': 'schedule_reminders',
          'tag': null,
          'title': 'Unrelated notification',
          'body': 'Keep me',
        },
      ];
      final cancelled = <Map<Object?, Object?>>[];
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'initialize':
              case 'areNotificationsEnabled':
                return true;
              case 'pendingNotificationRequests':
                return const <Map<String, Object?>>[];
              case 'getActiveNotifications':
                return notifications;
              case 'cancel':
                cancelled.add(
                  Map<Object?, Object?>.from(call.arguments as Map),
                );
                return true;
              default:
                return null;
            }
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      await LocalReminderService().reconcile([unchanged, edited], now: now);

      expect(cancelled, hasLength(1));
      expect(cancelled.single['id'], 12);
      expect(cancelled.single['tag'], startsWith('shift-study-reminder:'));
    },
  );

  test(
    'notification permission flow does not request exact-alarm access',
    () async {
      final calls = <String>[];
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            return switch (call.method) {
              'initialize' => true,
              'requestNotificationsPermission' => true,
              'areNotificationsEnabled' => true,
              'canScheduleExactNotifications' => false,
              _ => null,
            };
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });

      final result = await LocalReminderService().requestPermissions();

      expect(result.notificationsAllowed, isTrue);
      expect(result.exactTimingAllowed, isFalse);
      expect(calls, contains('requestNotificationsPermission'));
      expect(calls, contains('canScheduleExactNotifications'));
      expect(calls, isNot(contains('requestExactAlarmsPermission')));
    },
  );

  test('reconciliation does not overlap a newer schedule snapshot', () async {
    final now = DateTime.now();
    final item = ScheduleItem(
      id: 'synthetic-reminder-race',
      kind: ScheduleKind.work,
      title: 'Synthetic reminder race',
      startDate: CivilDate.fromDateTime(now.add(const Duration(days: 1))),
      intervals: [
        EventInterval.sameDay(startMinute: 9 * 60, endMinute: 17 * 60),
      ],
      timeZoneId: 'America/Barbados',
      reminderMinutesBefore: 0,
    );
    final firstPendingRead = Completer<void>();
    final releaseFirstPendingRead = Completer<void>();
    final calls = <String>[];
    var pendingReads = 0;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'initialize':
              return true;
            case 'areNotificationsEnabled':
              return true;
            case 'pendingNotificationRequests':
              final read = ++pendingReads;
              calls.add('pending-$read-start');
              if (read == 1) {
                firstPendingRead.complete();
                await releaseFirstPendingRead.future;
              }
              calls.add('pending-$read-end');
              return const <Map<String, Object?>>[];
            case 'getActiveNotifications':
              return const <Map<String, Object?>>[];
            case 'canScheduleExactNotifications':
              return false;
            case 'zonedSchedule':
              calls.add('schedule');
              return null;
            default:
              return null;
          }
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final service = LocalReminderService();
    final first = service.reconcile([item], now: now);
    await firstPendingRead.future;
    final second = service.reconcile(const [], now: now);
    await Future<void>.delayed(Duration.zero);
    final readsBeforeFirstCompleted = pendingReads;
    releaseFirstPendingRead.complete();
    await Future.wait([first, second]);

    expect(readsBeforeFirstCompleted, 1);
    expect(
      calls.indexOf('schedule'),
      lessThan(calls.indexOf('pending-2-start')),
    );
  });
}

ScheduleItem _item({
  required String id,
  required String title,
  required int startMinute,
}) => ScheduleItem(
  id: id,
  kind: ScheduleKind.work,
  title: title,
  startDate: CivilDate(2026, 11, 6),
  intervals: [
    EventInterval.sameDay(
      startMinute: startMinute,
      endMinute: startMinute + 60,
    ),
  ],
  timeZoneId: 'America/Halifax',
  reminderMinutesBefore: 0,
);

Map<String, Object?> _active(
  ScheduleItem item, {
  required int startEpoch,
  required int id,
}) {
  final key =
      '${item.id}|${item.startDate}|$startEpoch|${item.reminderMinutesBefore}';
  return {
    'id': id,
    'channelId': 'schedule_reminders',
    'tag': 'shift-study-reminder:${Uri.encodeComponent(key)}',
    'title': item.title,
    'body': 'Starting now',
  };
}
