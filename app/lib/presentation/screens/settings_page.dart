import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../data/preferences_repository.dart';
import '../../platform/widget_pin_requester.dart';
import '../../platform/startup_appearance_bridge.dart';
import 'notifications_settings_page.dart';
import 'backup_restore_page.dart';
import 'schedule_search_page.dart';
import 'schedule_import_page.dart';
import 'calendar_export_page.dart';
import 'about_page.dart';
import 'weather_settings_page.dart';
import '../widgets/shift_icon.dart';
import '../design/studyshift_spacing.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key, required this.mode});

  final ScheduleMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(appPreferencesProvider).value;
    final repo = ref.read(preferencesRepositoryProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.pageMargin,
        StudyShiftSpacing.x8,
      ),
      children: [
        _MoreSection(
          title: 'Plan & organize',
          children: [
            ListTile(
              leading: const ShiftIcon('search'),
              title: const Text('Find an event'),
              subtitle: const Text('Search your schedule'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScheduleSearchPage(),
                ),
              ),
            ),
            if (Theme.of(context).platform == TargetPlatform.android)
              ListTile(
                leading: const ShiftIcon('grid-2x2-plus'),
                title: const Text('Home-screen widget'),
                subtitle: const Text('Add or configure a widget'),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => _requestWidget(context),
              ),
          ],
        ),
        const SizedBox(height: StudyShiftSpacing.x4),
        _MoreSection(
          title: 'Calendar',
          children: [
            ListTile(
              leading: const ShiftIcon('file-input'),
              title: const Text('Import calendar'),
              subtitle: const Text('Import ICS or CSV'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ScheduleImportPage(),
                ),
              ),
            ),
            ListTile(
              leading: const ShiftIcon('file-output'),
              title: const Text('Export calendar'),
              subtitle: const Text('Export as an iCalendar file'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CalendarExportPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: StudyShiftSpacing.x4),
        _MoreSection(
          title: 'Notifications & weather',
          children: [
            if (Theme.of(context).platform == TargetPlatform.android)
              ListTile(
                leading: const Icon(Icons.notifications_none_rounded),
                title: const Text('Notifications'),
                subtitle: const Text('Manage reminders'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NotificationsSettingsPage(),
                  ),
                ),
              ),
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Weather & location'),
              subtitle: const Text('Location and Today’s forecast'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WeatherSettingsPage(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: StudyShiftSpacing.x4),
        _MoreSection(
          title: 'Preferences',
          children: [
            ListTile(
              leading: const ShiftIcon('clock-3'),
              title: const Text('Time format'),
              subtitle: const Text('12-hour or 24-hour clock'),
              trailing: DropdownButton<bool?>(
                value: prefs?.use24HourTime,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('System')),
                  DropdownMenuItem(value: false, child: Text('12 hour')),
                  DropdownMenuItem(value: true, child: Text('24 hour')),
                ],
                onChanged: (value) async {
                  if (value == null) {
                    await repo.clear('use_24_hour_time');
                  } else {
                    await repo.set24HourTime(value);
                  }
                  ref.invalidate(appPreferencesProvider);
                },
              ),
            ),
            ListTile(
              leading: const ShiftIcon('sun-moon'),
              title: const Text('Appearance'),
              subtitle: const Text('Light, dark or follow your device'),
              trailing: DropdownButton<ThemePreference?>(
                value: prefs?.theme,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('System')),
                  DropdownMenuItem(
                    value: ThemePreference.light,
                    child: Text('Light'),
                  ),
                  DropdownMenuItem(
                    value: ThemePreference.dark,
                    child: Text('Dark'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) {
                    await repo.clear('theme');
                  } else {
                    await repo.setTheme(value);
                  }
                  await _refreshAndSyncStartupAppearance(ref);
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Color theme'),
              subtitle: Text(_accentThemeName(prefs?.accentTheme)),
              trailing: DropdownButton<AccentTheme?>(
                value: prefs?.accentTheme,
                underline: const SizedBox.shrink(),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Stylish Blue')),
                  DropdownMenuItem(
                    value: AccentTheme.teal,
                    child: Text('Stylish Teal'),
                  ),
                  DropdownMenuItem(
                    value: AccentTheme.violet,
                    child: Text('Stylish Violet'),
                  ),
                  DropdownMenuItem(
                    value: AccentTheme.amber,
                    child: Text('Stylish Amber'),
                  ),
                  DropdownMenuItem(
                    value: AccentTheme.red,
                    child: Text('Stylish Red'),
                  ),
                ],
                onChanged: (value) async {
                  if (value == null) {
                    await repo.clear('accent_theme');
                  } else {
                    await repo.setAccentTheme(value);
                  }
                  await _refreshAndSyncStartupAppearance(ref);
                },
              ),
            ),
            ListTile(
              leading: const ShiftIcon('sliders-horizontal'),
              title: const Text('Schedule focus'),
              subtitle: Text(_modeName(mode)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => _showModes(context, ref),
            ),
          ],
        ),
        const SizedBox(height: StudyShiftSpacing.x4),
        _MoreSection(
          title: 'Your data',
          children: [
            ListTile(
              leading: const ShiftIcon('archive'),
              title: const Text('Backup & restore'),
              subtitle: const Text('Protect or restore your saved schedule'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BackupRestorePage(),
                ),
              ),
            ),
            const ListTile(
              leading: ShiftIcon('lock-keyhole'),
              title: Text('Stored on this device'),
              subtitle: Text('Works offline. No account or cloud service.'),
            ),
          ],
        ),
        const SizedBox(height: StudyShiftSpacing.x4),
        _MoreSection(
          title: 'About',
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline_rounded),
              title: const Text('About StudyShift'),
              subtitle: const Text('App version and privacy information'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutPage()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'StudyShift · private alpha',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Future<void> _requestWidget(BuildContext context) async {
    final family = await showDialog<WidgetFamily>(
      context: context,
      builder: (dialogContext) {
        var selected = WidgetFamily.nextEvent;
        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            scrollable: true,
            icon: const Icon(Icons.widgets_rounded),
            title: const Text('Add a StudyShift widget'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose the layout to add to your Home screen.'),
                const SizedBox(height: 12),
                RadioGroup<WidgetFamily>(
                  groupValue: selected,
                  onChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final option in const [
                        (
                          WidgetFamily.nextEvent,
                          'Next event',
                          '2 × 2 · next item',
                        ),
                        (
                          WidgetFamily.today,
                          'Today',
                          '4 × 2 · today’s schedule',
                        ),
                        (
                          WidgetFamily.week,
                          'This week',
                          '4 × 1 · weekly overview',
                        ),
                        (
                          WidgetFamily.nextClass,
                          'Next class',
                          '2 × 2 · next class only',
                        ),
                        (
                          WidgetFamily.upcomingDeadline,
                          'Upcoming deadline',
                          '2 × 2 · next assignment or exam',
                        ),
                      ])
                        RadioListTile<WidgetFamily>(
                          contentPadding: EdgeInsets.zero,
                          value: option.$1,
                          title: Text(option.$2),
                          subtitle: Text(option.$3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'To edit an existing widget, touch and hold it on your '
                  'Home screen and tap Settings. Android may delay background '
                  'updates to protect battery life.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
      },
    );
    if (family == null || !context.mounted) return;
    var accepted = false;
    try {
      accepted = await WidgetPinRequester().requestPin(family);
    } catch (_) {
      // Keep unsupported launchers and platform bridges recoverable in the UI.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted
              ? 'Finish adding the widget in your launcher.'
              : 'Open Home screen → Widgets → StudyShift to add a widget.',
        ),
      ),
    );
  }

  Future<void> _showModes(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<ScheduleMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final value in ScheduleMode.values)
              ListTile(
                title: Text(_modeName(value)),
                trailing: value == mode
                    ? const Icon(Icons.check_rounded)
                    : null,
                onTap: () => Navigator.pop(context, value),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
    if (selected != null) {
      await ref.read(preferencesRepositoryProvider).setScheduleMode(selected);
      ref.invalidate(appPreferencesProvider);
    }
  }
}

Future<void> _refreshAndSyncStartupAppearance(WidgetRef ref) async {
  ref.invalidate(appPreferencesProvider);
  final preferences = await ref.read(appPreferencesProvider.future);
  await StartupAppearanceBridge.sync(preferences);
}

class _MoreSection extends StatelessWidget {
  const _MoreSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      Card(
        clipBehavior: Clip.antiAlias,
        child: ListTileTheme(
          data: const ListTileThemeData(
            visualDensity: VisualDensity.compact,
            minVerticalPadding: 4,
            contentPadding: EdgeInsets.symmetric(horizontal: 12),
          ),
          child: Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const Divider(height: 1, indent: 56),
                children[index],
              ],
            ],
          ),
        ),
      ),
    ],
  );
}

String _modeName(ScheduleMode mode) => switch (mode) {
  ScheduleMode.workOnly => 'Work',
  ScheduleMode.schoolOnly => 'School',
  ScheduleMode.workAndSchool => 'Work + School',
  ScheduleMode.personalPlanner => 'Personal planner',
};

String _accentThemeName(AccentTheme? theme) => switch (theme) {
  null || AccentTheme.studyShiftBlue => 'Stylish Blue',
  AccentTheme.teal => 'Stylish Teal',
  AccentTheme.violet => 'Stylish Violet',
  AccentTheme.amber => 'Stylish Amber',
  AccentTheme.red => 'Stylish Red',
};
