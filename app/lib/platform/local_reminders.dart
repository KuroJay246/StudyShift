import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/schedule.dart';
import '../domain/schedule_engine.dart';

const reminderOffsets = <int?>[null, 0, 5, 15, 30, 60, 1440];

String reminderOffsetLabel(int? minutes) => switch (minutes) {
  null => 'No reminder',
  0 => 'At start time',
  60 => '1 hour before',
  1440 => '1 day before',
  _ => '$minutes minutes before',
};

class PlannedReminder {
  const PlannedReminder({
    required this.key,
    required this.item,
    required this.occurrenceDate,
    required this.triggerAt,
    required this.eventStart,
  });

  final String key;
  final ScheduleItem item;
  final CivilDate occurrenceDate;
  final DateTime triggerAt;
  final DateTime eventStart;
}

class ReminderPlanner {
  const ReminderPlanner(this.engine);
  final ScheduleEngine engine;

  static const maxPending = 60;

  List<PlannedReminder> plan(List<ScheduleItem> items, DateTime now) {
    final today = CivilDate.fromDateTime(now);
    final occurrences = engine.expand(items, today, today.addDays(32));
    final planned = <PlannedReminder>[];
    for (final occurrence in occurrences) {
      final item = occurrence.item;
      final minutesBefore = item.reminderMinutesBefore;
      if (minutesBefore == null || item.hasNoTime || item.timeZoneId == null) {
        continue;
      }
      final resolved = engine.resolveOccurrence(occurrence);
      if (resolved.intervals.isEmpty ||
          resolved.issues.any((issue) => issue.intervalIndex == 0)) {
        continue;
      }
      final start = resolved.intervals.first.start;
      final trigger = start.subtract(Duration(minutes: minutesBefore));
      if (!trigger.isAfter(now)) continue;
      planned.add(
        PlannedReminder(
          key:
              '${item.id}|${occurrence.date}|${start.toUtc().millisecondsSinceEpoch}|$minutesBefore',
          item: item,
          occurrenceDate: occurrence.date,
          triggerAt: trigger,
          eventStart: start,
        ),
      );
    }
    planned.sort((a, b) => a.triggerAt.compareTo(b.triggerAt));
    return planned.take(maxPending).toList(growable: false);
  }
}

class ReminderPermissionResult {
  const ReminderPermissionResult({
    required this.notificationsAllowed,
    required this.exactTimingAllowed,
  });

  final bool notificationsAllowed;
  final bool exactTimingAllowed;
}

/// The safe in-app destination carried by a local schedule reminder.
class ReminderDestination {
  const ReminderDestination({
    required this.itemId,
    required this.occurrenceDate,
  });

  static const payloadPrefix = 'shift-study-reminder:';

  final String itemId;
  final CivilDate occurrenceDate;

  /// Existing reminder payloads wrap `eventId|date|epochMillis|offset` in URI
  /// encoding. Keep that payload stable for notification reconciliation while
  /// exposing only the identity and civil occurrence date to navigation.
  static ReminderDestination? parse(String? payload) {
    if (payload == null || !payload.startsWith(payloadPrefix)) return null;
    try {
      final key = Uri.decodeComponent(payload.substring(payloadPrefix.length));
      final parts = key.split('|');
      if (parts.length != 4 || parts[0].trim().isEmpty) return null;
      final dateParts = parts[1].split('-');
      if (dateParts.length != 3 ||
          dateParts[0].length != 4 ||
          dateParts[1].length != 2 ||
          dateParts[2].length != 2) {
        return null;
      }
      final values = dateParts.map(int.tryParse).toList(growable: false);
      if (values.any((value) => value == null)) return null;
      final date = CivilDate(values[0]!, values[1]!, values[2]!);
      final epoch = int.tryParse(parts[2]);
      final offset = int.tryParse(parts[3]);
      if (!date.isValid ||
          epoch == null ||
          epoch <= 0 ||
          offset == null ||
          offset < 0 ||
          offset > 1440) {
        return null;
      }
      return ReminderDestination(itemId: parts[0], occurrenceDate: date);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  /// Resolve against current persisted records so stale/deleted or skipped
  /// occurrences never open a misleading detail sheet.
  EventOccurrence? resolve(List<ScheduleItem> items) {
    final matches = items.where((item) => item.id == itemId).toList();
    if (matches.length != 1) return null;
    final occurrences = const ScheduleEngine().expand(
      matches,
      occurrenceDate,
      occurrenceDate,
    );
    if (occurrences.length != 1 || occurrences.single.item.id != itemId) {
      return null;
    }
    return occurrences.single;
  }
}

class LocalReminderService {
  LocalReminderService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const _payloadPrefix = ReminderDestination.payloadPrefix;
  static const _channelId = 'schedule_reminders';
  static const _channelName = 'Schedule reminders';

  final FlutterLocalNotificationsPlugin _plugin;
  final StreamController<ReminderDestination> _destinations =
      StreamController<ReminderDestination>.broadcast();
  Future<void>? _initialized;
  Future<void> _reconcileQueue = Future<void>.value();
  ReminderDestination? _initialDestination;

  /// Emits taps received while running and replays one cold-start tap.
  Stream<ReminderDestination> get destinations async* {
    await initialize();
    final initial = _initialDestination;
    _initialDestination = null;
    if (initial != null) yield initial;
    yield* _destinations.stream;
  }

  Future<void> initialize() => _initialized ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_stat_schedule'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
        macOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final destination = ReminderDestination.parse(response.payload);
        if (destination != null) _destinations.add(destination);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      _initialDestination = ReminderDestination.parse(
        launch?.notificationResponse?.payload,
      );
    }
  }

  Future<ReminderPermissionResult> requestPermissions() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return const ReminderPermissionResult(
        notificationsAllowed: false,
        exactTimingAllowed: false,
      );
    }
    final notificationsAllowed =
        await android.requestNotificationsPermission() ??
        await android.areNotificationsEnabled() ??
        false;
    if (!notificationsAllowed) {
      return const ReminderPermissionResult(
        notificationsAllowed: false,
        exactTimingAllowed: false,
      );
    }
    final exact = await android.canScheduleExactNotifications() ?? true;
    return ReminderPermissionResult(
      notificationsAllowed: true,
      exactTimingAllowed: exact,
    );
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return false;
    return await android.requestNotificationsPermission() ??
        await android.areNotificationsEnabled() ??
        false;
  }

  /// Reads Android reminder capabilities without displaying any permission UI.
  Future<ReminderPermissionResult> currentPermissions() async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) {
      return const ReminderPermissionResult(
        notificationsAllowed: false,
        exactTimingAllowed: false,
      );
    }
    return ReminderPermissionResult(
      notificationsAllowed: await android.areNotificationsEnabled() ?? false,
      exactTimingAllowed: await android.canScheduleExactNotifications() ?? true,
    );
  }

  Future<void> reconcile(List<ScheduleItem> items, {DateTime? now}) {
    final operation = _reconcileQueue.then<void>(
      (_) => _reconcileItems(items, now: now),
      onError: (_, _) => _reconcileItems(items, now: now),
    );
    _reconcileQueue = operation.then<void>(
      (_) {},
      onError: (_, _) {},
    );
    return operation;
  }

  Future<void> _reconcileItems(
    List<ScheduleItem> items, {
    DateTime? now,
  }) async {
    await initialize();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android == null) return;
    final enabled = await android.areNotificationsEnabled() ?? false;
    final pending = await _plugin.pendingNotificationRequests();
    final ownedPending = pending
        .where(
          (request) => request.payload?.startsWith(_payloadPrefix) ?? false,
        )
        .toList(growable: false);
    final active = await _plugin.getActiveNotifications();
    final ownedActive = active
        .where(
          (notification) =>
              notification.channelId == _channelId &&
              notification.id != null &&
              (notification.tag?.startsWith(_payloadPrefix) ?? false),
        )
        .toList(growable: false);
    if (!enabled) {
      for (final request in ownedPending) {
        await _plugin.cancel(id: request.id);
      }
      for (final notification in ownedActive) {
        await _plugin.cancel(id: notification.id!, tag: notification.tag);
      }
      return;
    }

    final planned = const ReminderPlanner(ScheduleEngine())
        .plan(items, now ?? DateTime.now());
    final requestsByPayload = <String, PendingNotificationRequest>{
      for (final request in ownedPending)
        if (request.payload != null) request.payload!: request,
    };
    final expectedPayloads = <String>{};
    final expectedIds = <int, String>{};
    for (final reminder in planned) {
      final payload = '$_payloadPrefix${Uri.encodeComponent(reminder.key)}';
      expectedPayloads.add(payload);
      var id = _notificationId(reminder.key);
      var salt = 0;
      while (expectedIds.containsKey(id) && expectedIds[id] != reminder.key) {
        id = _notificationId('${reminder.key}#${++salt}');
      }
      expectedIds[id] = reminder.key;
      final old = requestsByPayload[payload];
      final title = reminder.item.title;
      final body = _body(reminder);
      if (old != null && old.title == title && old.body == body) continue;
      if (old != null) await _plugin.cancel(id: old.id);
      final exact = await _exactAllowed(android);
      await _schedule(id, reminder, payload, title, body, exact);
    }
    for (final request in ownedPending) {
      if (!expectedPayloads.contains(request.payload)) {
        await _plugin.cancel(id: request.id);
      }
    }
    for (final notification in ownedActive) {
      if (!_activeReminderIsCurrent(notification, items)) {
        await _plugin.cancel(id: notification.id!, tag: notification.tag);
      }
    }
  }

  bool _activeReminderIsCurrent(
    ActiveNotification notification,
    List<ScheduleItem> items,
  ) {
    final tag = notification.tag;
    if (tag == null || !tag.startsWith(_payloadPrefix)) return false;
    final String key;
    try {
      key = Uri.decodeComponent(tag.substring(_payloadPrefix.length));
    } on FormatException {
      return false;
    }
    final parts = key.split('|');
    if (parts.length != 4) return false;
    final matches = items.where((item) => item.id == parts[0]);
    if (matches.isEmpty) return false;
    final item = matches.first;
    if (item.reminderMinutesBefore == null ||
        item.hasNoTime ||
        notification.title != item.title) {
      return false;
    }
    final dateParts = parts[1].split('-');
    if (dateParts.length != 3) return false;
    final dateValues = dateParts.map(int.tryParse).toList();
    if (dateValues.any((value) => value == null)) return false;
    final date = CivilDate(dateValues[0]!, dateValues[1]!, dateValues[2]!);
    if (!date.isValid) return false;
    final occurrence = const ScheduleEngine().expand([item], date, date);
    if (occurrence.isEmpty) return false;
    final resolution = const ScheduleEngine().resolveOccurrence(
      occurrence.single,
    );
    if (resolution.issues.isNotEmpty || resolution.intervals.isEmpty) {
      return false;
    }
    final start = resolution.intervals.first.start;
    final currentKey =
        '${item.id}|$date|${start.toUtc().millisecondsSinceEpoch}|${item.reminderMinutesBefore}';
    return key == currentKey &&
        notification.body == _bodyForOffset(item.reminderMinutesBefore!);
  }

  Future<bool> _exactAllowed(
    AndroidFlutterLocalNotificationsPlugin android,
  ) async => await android.canScheduleExactNotifications() ?? true;

  Future<void> _schedule(
    int id,
    PlannedReminder reminder,
    String payload,
    String title,
    String body,
    bool exact,
  ) async {
    final zone = tz.getLocation(reminder.item.timeZoneId!);
    final scheduledDate = tz.TZDateTime.from(reminder.triggerAt.toUtc(), zone);
    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Local reminders you choose for schedule events.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@drawable/ic_stat_schedule',
        tag: payload,
      ),
    );
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } on PlatformException catch (error, stack) {
      if (!exact || error.code != 'exact_alarms_not_permitted') rethrow;
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'local reminder scheduling',
          context: ErrorDescription('Falling back to an inexact reminder.'),
        ),
      );
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        payload: payload,
        scheduledDate: scheduledDate,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  String _body(PlannedReminder reminder) {
    return _bodyForOffset(reminder.item.reminderMinutesBefore!);
  }

  String _bodyForOffset(int offset) {
    if (offset == 0) return 'Starting now';
    if (offset == 60) return 'Starts in 1 hour';
    if (offset == 1440) return 'Starts in 1 day';
    return 'Starts in $offset minutes';
  }

  int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final unit in utf8.encode(value)) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
