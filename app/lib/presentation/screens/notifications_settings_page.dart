import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../platform/local_reminders.dart';
import '../../platform/notification_settings_bridge.dart';
import '../design/studyshift_spacing.dart';

class NotificationsSettingsPage extends ConsumerStatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  ConsumerState<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState
    extends ConsumerState<NotificationsSettingsPage> {
  final _settings = const NotificationSettingsBridge();
  ReminderPermissionResult? _permissions;
  bool _permissionRequestedBefore = false;
  bool _loading = true;
  bool _requesting = false;
  String? _error;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final service = ref.read(localReminderServiceProvider);
      final permissions = await service.currentPermissions();
      final wasRequested = await _settings.wasNotificationPermissionRequested();
      if (!mounted) return;
      setState(() {
        _permissions = permissions;
        _permissionRequestedBefore = wasRequested;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Permission status could not be checked.';
      });
    }
  }

  Future<void> _requestNotifications() async {
    setState(() => _requesting = true);
    var allowed = false;
    try {
      allowed = await ref
          .read(localReminderServiceProvider)
          .requestNotificationPermission();
      await _settings.recordNotificationPermissionRequest();
      await _refresh();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Android could not update notification access.');
      }
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            allowed
                ? 'Notifications are enabled.'
                : 'Notifications remain off. You can change this in Android settings.',
          ),
        ),
      );
    }
  }

  Future<void> _openSettings({required bool exactAlarm}) async {
    final opened = exactAlarm
        ? await _settings.openExactAlarmSettings()
        : await _settings.openNotificationSettings();
    if (!mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Android settings could not be opened.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final permissions = _permissions;
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        padding: const EdgeInsets.all(StudyShiftSpacing.pageMargin),
        children: [
          Text(
            'Reminders that fit your schedule',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'StudyShift schedules reminders on this device for events where '
            'you choose a reminder time. You stay in control of notification access.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _StatusCard(
            icon: Icons.notifications_active_outlined,
            title: 'Notification permission',
            status: _loading
                ? 'Checking…'
                : permissions?.notificationsAllowed == true
                ? 'Notifications are on'
                : _permissionRequestedBefore
                ? 'Notifications are off'
                : 'Not enabled yet',
            detail: permissions?.notificationsAllowed == true
                ? 'Event reminders can appear in your notification shade.'
                : 'Allow notifications to receive the reminders you set for events.',
            enabled: permissions?.notificationsAllowed == true,
          ),
          if (!_loading &&
              permissions != null &&
              !permissions.notificationsAllowed) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _requesting ? null : _requestNotifications,
              icon: _requesting
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_outlined),
              label: Text(
                _requesting ? 'Requesting permission…' : 'Allow notifications',
              ),
            ),
            if (_permissionRequestedBefore) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => _openSettings(exactAlarm: false),
                icon: const Icon(Icons.settings_outlined),
                label: const Text('Open notification settings'),
              ),
            ],
          ],
          const SizedBox(height: 20),
          _StatusCard(
            icon: Icons.alarm_on_outlined,
            title: 'Exact reminder timing',
            status: _loading
                ? 'Checking…'
                : permissions?.exactTimingAllowed == true
                ? 'Exact timing is on'
                : 'Exact timing is off',
            detail: permissions?.exactTimingAllowed == true
                ? 'Android can deliver reminders close to the chosen time.'
                : 'Reminders can still arrive, but Android may delay them. '
                      'Exact timing is optional.',
            enabled: permissions?.exactTimingAllowed == true,
          ),
          if (!_loading &&
              permissions != null &&
              !permissions.exactTimingAllowed) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _openSettings(exactAlarm: true),
              icon: const Icon(Icons.alarm_add_outlined),
              label: const Text('Open exact alarm settings'),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Check again'),
            ),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Choose a reminder while adding or editing a timed event. '
                      'No reminder is scheduled unless you select one. Android '
                      'may limit background delivery while Battery Saver or '
                      'device-specific restrictions are active.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.status,
    required this.detail,
    required this.enabled,
  });

  final IconData icon;
  final String title;
  final String status;
  final String detail;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
