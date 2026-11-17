import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/local_reminders.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Android delivers a scheduled local event reminder', (
    tester,
  ) async {
    final plugin = FlutterLocalNotificationsPlugin();
    final android = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    expect(android, isNotNull);
    final service = LocalReminderService(plugin: plugin);
    await service.initialize();
    expect(
      await android!.requestNotificationsPermission(),
      isTrue,
      reason: 'The emulator test package must have reminder permission.',
    );
    expect(
      await android.areNotificationsEnabled(),
      isTrue,
      reason: 'The Android app-level notification switch must be enabled.',
    );
    expect(
      await android.canScheduleExactNotifications(),
      isFalse,
      reason: 'This run must verify delivery without exact-alarm access.',
    );

    tzdata.initializeTimeZones();
    final zone = tz.getLocation('America/Barbados');
    final now = tz.TZDateTime.now(zone);
    final eventStart = tz.TZDateTime(
      zone,
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    ).add(const Duration(minutes: 2));
    final eventEnd = eventStart.add(const Duration(minutes: 30));
    final item = ScheduleItem(
      id: 'synthetic-reminder-delivery',
      kind: ScheduleKind.work,
      title: 'Synthetic reminder check',
      startDate: CivilDate.fromDateTime(now),
      timeZoneId: 'America/Barbados',
      intervals: [
        EventInterval(
          startDayOffset: eventStart.day == now.day ? 0 : 1,
          startMinute: eventStart.hour * 60 + eventStart.minute,
          endDayOffset: eventEnd.day == now.day ? 0 : 1,
          endMinute: eventEnd.hour * 60 + eventEnd.minute,
        ),
      ],
      reminderMinutesBefore: 0,
    );
    final payloadPrefix = 'shift-study-reminder:';

    await service.reconcile([item], now: now);
    final plannedPayload = (await plugin.pendingNotificationRequests())
        .singleWhere(
          (request) => request.payload?.startsWith(payloadPrefix) ?? false,
        )
        .payload!;

    final delivered = await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(minutes: 4));
      while (DateTime.now().isBefore(deadline)) {
        final active = await plugin.getActiveNotifications();
        if (active.any((notification) => notification.tag == plannedPayload)) {
          return true;
        }
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      return false;
    });
    expect(delivered, isTrue, reason: 'Android did not deliver the reminder.');
    final deliveredNotifications = await plugin.getActiveNotifications();
    expect(
      deliveredNotifications.any(
        (notification) =>
            notification.tag == plannedPayload &&
            notification.title == 'Synthetic reminder check',
      ),
      isTrue,
      reason: 'The delivered notification must identify the scheduled event.',
    );

    await service.reconcile(const [], now: DateTime.now());
    expect(
      (await plugin.pendingNotificationRequests()).where(
        (request) => request.payload?.startsWith(payloadPrefix) ?? false,
      ),
      isEmpty,
    );
    final reminderDismissed = await tester.runAsync(() async {
      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (DateTime.now().isBefore(deadline)) {
        final active = await plugin.getActiveNotifications();
        if (!active.any(
          (notification) =>
              notification.tag?.startsWith(payloadPrefix) ?? false,
        )) {
          return true;
        }
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }
      return false;
    });
    expect(
      reminderDismissed,
      isTrue,
      reason: 'Removing the event must dismiss its active reminder.',
    );
  });
}
