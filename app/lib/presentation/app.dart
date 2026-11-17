import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/dependencies.dart';
import '../data/preferences_repository.dart';
import '../domain/schedule.dart';
import '../platform/local_reminders.dart';
import 'motion.dart';
import 'screens/schedule_pages.dart';
import 'screens/settings_page.dart';
import 'screens/event_editor_page.dart';
import 'widgets/schedule_details_sheet.dart';
import 'widgets/navigation_page_track.dart';
import 'widgets/shift_icon.dart';
import 'widgets/shift_brand_mark.dart';

enum _StudyAddSelection { classSession, assignment, examination }

enum _ScheduleAddSelection {
  work,
  classSession,
  assignment,
  examination,
  personal,
}

class ModeSetupPage extends ConsumerWidget {
  const ModeSetupPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modes = [
      (
        ScheduleMode.workOnly,
        'Work',
        'Keep shifts, training, leave and days off together.',
        Icons.work_outline_rounded,
      ),
      (
        ScheduleMode.schoolOnly,
        'School',
        'See classes and the week ahead in one place.',
        Icons.school_outlined,
      ),
      (
        ScheduleMode.workAndSchool,
        'Work + School',
        'Bring both schedules together and spot clashes.',
        Icons.calendar_month_rounded,
      ),
      (
        ScheduleMode.personalPlanner,
        'Personal planner',
        'Plan appointments and everyday commitments.',
        Icons.event_note_rounded,
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1F5B),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(5),
                    child: const StudyShiftBrandMark(size: 54),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'A schedule that fits your life',
                  style: Theme.of(context).textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Text(
                  'Your plans stay on this device. Choose what you want to organize; you can change this later without deleting events.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                for (final (mode, title, detail, icon) in modes) ...[
                  _ModeChoice(
                    title: title,
                    detail: detail,
                    icon: icon,
                    onTap: () async {
                      await ref
                          .read(preferencesRepositoryProvider)
                          .setScheduleMode(mode);
                      ref.invalidate(appPreferencesProvider);
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No account needed. Your schedule is stored locally.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.title,
    required this.detail,
    required this.icon,
    required this.onTap,
  });
  final String title;
  final String detail;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(detail, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    ),
  );
}

enum _Destination { today, week, work, school, plans, more }

class _NavItem {
  const _NavItem(this.destination, this.label, this.icon, this.selectedIcon);
  final _Destination destination;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class ScheduleShell extends ConsumerStatefulWidget {
  const ScheduleShell({
    super.key,
    required this.mode,
    this.clock,
    this.initialDestination = 'today',
  });
  final ScheduleMode mode;
  final DateTime Function()? clock;
  final String initialDestination;

  @override
  ConsumerState<ScheduleShell> createState() => _ScheduleShellState();
}

class _ScheduleShellState extends ConsumerState<ScheduleShell>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late _Destination _selected;
  late final AnimationController _pageSettleController;
  late CivilDate _selectedDay;
  late CivilDate _lastKnownToday;
  ReminderDestination? _pendingReminderDestination;
  String? _lastOpenedReminder;
  double _destinationSwipeDistance = 0;
  late final ValueNotifier<double> _pagePosition;
  double _settleStart = 0;
  double _settleEnd = 0;
  int _gestureStartIndex = 0;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _selected = switch (widget.initialDestination) {
      'week' => _Destination.week,
      'work' => _Destination.work,
      'study' => _Destination.school,
      _ => _Destination.today,
    };
    final initialIndex = _items.indexWhere(
      (item) => item.destination == _selected,
    );
    _pagePosition = ValueNotifier<double>(
      (initialIndex < 0 ? 0 : initialIndex).toDouble(),
    );
    _gestureStartIndex = _pagePosition.value.round();
    _pageSettleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(_handlePageSettleTick);
    _selectedDay = CivilDate.fromDateTime(_now());
    _lastKnownToday = _selectedDay;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageSettleController.dispose();
    _pagePosition.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(deviceTimeZoneIdProvider);
    }
    final today = CivilDate.fromDateTime(_now());
    final wasFollowingToday = _selectedDay == _lastKnownToday;
    _lastKnownToday = today;
    if (wasFollowingToday && _selectedDay != today) {
      setState(() => _selectedDay = today);
    }
  }

  List<_NavItem> get _items {
    final items = <_NavItem>[
      const _NavItem(
        _Destination.today,
        'Today',
        Icons.home_outlined,
        Icons.home_rounded,
      ),
      const _NavItem(
        _Destination.week,
        'Calendar',
        Icons.calendar_month_outlined,
        Icons.calendar_month_rounded,
      ),
    ];
    if (widget.mode == ScheduleMode.workOnly ||
        widget.mode == ScheduleMode.workAndSchool) {
      items.add(
        const _NavItem(
          _Destination.work,
          'Work',
          Icons.work_outline_rounded,
          Icons.work_rounded,
        ),
      );
    }
    if (widget.mode == ScheduleMode.schoolOnly ||
        widget.mode == ScheduleMode.workAndSchool) {
      items.add(
        const _NavItem(
          _Destination.school,
          'Study',
          Icons.school_outlined,
          Icons.school_rounded,
        ),
      );
    }
    if (widget.mode == ScheduleMode.personalPlanner) {
      items.add(
        const _NavItem(
          _Destination.plans,
          'Plans',
          Icons.event_note_outlined,
          Icons.event_note_rounded,
        ),
      );
    }
    items.add(
      const _NavItem(
        _Destination.more,
        'More',
        Icons.grid_view_outlined,
        Icons.grid_view_rounded,
      ),
    );
    return items;
  }

  String get _title =>
      _items.firstWhere((item) => item.destination == _selected).label;

  Widget _page(_Destination destination) => switch (destination) {
    _Destination.today => TodayPage(
      selectedDay: _selectedDay,
      clock: _now,
      onSelectedDateChanged: (date) => setState(() => _selectedDay = date),
    ),
    _Destination.week => WeekPage(
      focusDate: _selectedDay,
      onFocusDateChanged: (date) => setState(() => _selectedDay = date),
    ),
    _Destination.work => const WorkPage(),
    _Destination.school => const StudyPage(),
    _Destination.plans => const PlansPage(),
    _Destination.more => SettingsPage(mode: widget.mode),
  };

  bool _hasVisibleScheduleEntries(List<ScheduleItem> items) {
    final queries = ref.read(scheduleQueriesProvider);
    if (_selected == _Destination.today) {
      return queries.forDay(items, _selectedDay).isNotEmpty;
    }
    final kinds = switch (_selected) {
      _Destination.work => const {ScheduleKind.work},
      _Destination.school => const {
        ScheduleKind.classSession,
        ScheduleKind.deadline,
      },
      _Destination.plans => const {ScheduleKind.personal},
      _ => const <ScheduleKind>{},
    };
    if (kinds.isEmpty) return false;
    final today = CivilDate.fromDateTime(_now());
    return queries
        .forRange(items, today, today.addDays(90))
        .any((event) => kinds.contains(event.item.kind));
  }

  void _navigateToIndex(int index, List<_NavItem> items) {
    if (index < 0 || index >= items.length) return;
    _settleToIndex(index, items);
  }

  void _settleToIndex(int index, List<_NavItem> items) {
    if (index < 0 || index >= items.length) return;
    final destination = items[index].destination;
    if (_selected == destination &&
        (_pagePosition.value - index).abs() < 0.001) {
      return;
    }
    final duration = AppMotion.duration(context, AppMotion.change);
    _pageSettleController.stop();
    _settleStart = _pagePosition.value;
    _settleEnd = index.toDouble();
    setState(() => _selected = destination);
    if (duration <= Duration.zero) {
      _pagePosition.value = _settleEnd;
    } else {
      _pageSettleController.duration = duration;
      _pageSettleController
        ..reset()
        ..forward();
    }
  }

  void _handlePageSettleTick() {
    final progress = Curves.easeOutCubic.transform(_pageSettleController.value);
    _pagePosition.value = _settleStart + (_settleEnd - _settleStart) * progress;
  }

  void _startDestinationDrag() {
    _pageSettleController.stop();
    _destinationSwipeDistance = 0;
    _gestureStartIndex = _pagePosition.value.round();
  }

  void _updateDestinationDrag(DragUpdateDetails details, double width) {
    if (width <= 0) return;
    _destinationSwipeDistance += details.primaryDelta ?? 0;
    final items = _items;
    _pagePosition.value =
        (_gestureStartIndex - _destinationSwipeDistance / width)
            .clamp(0, items.length - 1)
            .toDouble();
  }

  void _finishDestinationDrag(DragEndDetails details, List<_NavItem> items) {
    final velocity = details.primaryVelocity ?? 0;
    var targetIndex = _gestureStartIndex;
    if (_destinationSwipeDistance.abs() >= 80 || velocity.abs() >= 120) {
      final directionSource = _destinationSwipeDistance.abs() >= 80
          ? _destinationSwipeDistance
          : velocity;
      targetIndex = (_gestureStartIndex + (directionSource < 0 ? 1 : -1)).clamp(
        0,
        items.length - 1,
      );
    }
    _settleToIndex(targetIndex, items);
  }

  void _openReminderDestination(ReminderDestination destination) {
    final items = ref.read(scheduleItemsProvider).asData?.value;
    if (items == null) {
      _pendingReminderDestination = destination;
      return;
    }
    final occurrence = destination.resolve(items);
    if (occurrence == null) {
      _pendingReminderDestination = null;
      return;
    }
    final identity = '${occurrence.item.id}|${occurrence.date}';
    if (_lastOpenedReminder == identity) return;
    _lastOpenedReminder = identity;
    _pendingReminderDestination = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showScheduleDetails(
        context,
        ref,
        occurrence.item,
        occurrenceDate: occurrence.date,
      );
    });
  }

  bool get _canAdd => _selected != _Destination.more;

  Future<void> _requestNotificationPermission() async {
    final enable = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const Text('Shift and class reminders'),
        content: const Text(
          'StudyShift can notify you before events when you add a reminder. '
          'Your schedule and reminders stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Enable reminders'),
          ),
        ],
      ),
    );
    if (enable != true || !mounted) return;
    var allowed = false;
    try {
      allowed = await ref
          .read(localReminderServiceProvider)
          .requestNotificationPermission();
    } catch (_) {
      if (!mounted) return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allowed ? 'Reminder notifications are enabled.' : 'Notifications are off. You can allow them in Android settings.',
        ),
      ),
    );
  }

  Future<void> _add({CivilDate? initialDate}) async {
    if (_selected == _Destination.school) {
      await _addFromSchool(initialDate);
      return;
    }
    final directKind = switch (_selected) {
      _Destination.work => ScheduleKind.work,
      _Destination.school => null,
      _Destination.plans => ScheduleKind.personal,
      _ when widget.mode == ScheduleMode.workOnly => ScheduleKind.work,
      _ when widget.mode == ScheduleMode.schoolOnly =>
        ScheduleKind.classSession,
      _ when widget.mode == ScheduleMode.personalPlanner =>
        ScheduleKind.personal,
      _ => null,
    };
    if (directKind != null) {
      await _openEventEditor(directKind, initialDate: initialDate);
      return;
    }

    final selection = await _chooseKind();
    if (selection == null || !mounted) return;
    final kind = switch (selection) {
      _ScheduleAddSelection.work => ScheduleKind.work,
      _ScheduleAddSelection.classSession => ScheduleKind.classSession,
      _ScheduleAddSelection.personal => ScheduleKind.personal,
      _ScheduleAddSelection.assignment ||
      _ScheduleAddSelection.examination => ScheduleKind.deadline,
    };
    final deadlineType = switch (selection) {
      _ScheduleAddSelection.assignment => DeadlineType.assignment,
      _ScheduleAddSelection.examination => DeadlineType.examination,
      _ => null,
    };
    await _openEventEditor(
      kind,
      initialDate: initialDate,
      deadlineType: deadlineType,
    );
  }

  Future<void> _openEventEditor(
    ScheduleKind kind, {
    CivilDate? initialDate,
    DeadlineType? deadlineType,
  }) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventEditorPage(
          kind: kind,
          initialDate: initialDate,
          initialDeadlineType: deadlineType,
        ),
      ),
    );
  }

  Future<void> _addFromSchool(CivilDate? initialDate) async {
    final selection = await showModalBottomSheet<_StudyAddSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add to school',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const ShiftIcon('graduation-cap'),
                  title: const Text('Class'),
                  onTap: () =>
                      Navigator.pop(context, _StudyAddSelection.classSession),
                ),
                ListTile(
                  leading: const ShiftIcon('clipboard-check'),
                  title: const Text('Assignment'),
                  onTap: () =>
                      Navigator.pop(context, _StudyAddSelection.assignment),
                ),
                ListTile(
                  leading: const ShiftIcon('calendar-check'),
                  title: const Text('Examination'),
                  onTap: () =>
                      Navigator.pop(context, _StudyAddSelection.examination),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selection == null || !mounted) return;
    final kind = selection == _StudyAddSelection.classSession
        ? ScheduleKind.classSession
        : ScheduleKind.deadline;
    final deadlineType = switch (selection) {
      _StudyAddSelection.classSession => null,
      _StudyAddSelection.assignment => DeadlineType.assignment,
      _StudyAddSelection.examination => DeadlineType.examination,
    };
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => EventEditorPage(
          kind: kind,
          initialDate: initialDate,
          initialDeadlineType: deadlineType,
        ),
      ),
    );
  }

  Future<_ScheduleAddSelection?>
  _chooseKind() => showModalBottomSheet<_ScheduleAddSelection>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add to your schedule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 12),
              if (widget.mode == ScheduleMode.workAndSchool) ...[
                ListTile(
                  leading: const ShiftIcon('briefcase-business'),
                  title: const Text('Work shift'),
                  onTap: () =>
                      Navigator.pop(context, _ScheduleAddSelection.work),
                ),
                ListTile(
                  leading: const ShiftIcon('graduation-cap'),
                  title: const Text('Class'),
                  onTap: () => Navigator.pop(
                    context,
                    _ScheduleAddSelection.classSession,
                  ),
                ),
                ListTile(
                  leading: const ShiftIcon('clipboard-check'),
                  title: const Text('Assignment'),
                  onTap: () =>
                      Navigator.pop(context, _ScheduleAddSelection.assignment),
                ),
                ListTile(
                  leading: const ShiftIcon('calendar-check'),
                  title: const Text('Examination'),
                  onTap: () =>
                      Navigator.pop(context, _ScheduleAddSelection.examination),
                ),
              ] else ...[
                ListTile(
                  leading: const ShiftIcon('calendar-plus-2'),
                  title: const Text('Personal event'),
                  onTap: () =>
                      Navigator.pop(context, _ScheduleAddSelection.personal),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(reminderDestinationsProvider, (previous, next) {
      next.whenData(_openReminderDestination);
    });
    ref.listen(scheduleItemsProvider, (previous, next) {
      final pending = _pendingReminderDestination;
      if (pending != null) {
        next.whenData((_) => _openReminderDestination(pending));
      }
    });
    final items = _items;
    if (!items.any((item) => item.destination == _selected)) {
      _selected = _Destination.today;
    }
    final selectedIndex = items.indexWhere(
      (item) => item.destination == _selected,
    );
    final size = MediaQuery.sizeOf(context);
    final useNavigationRail =
        size.width >= 600 && (size.height >= 480 || size.width > size.height);
    final compactHeight = size.height < 480;
    final hasVisibleEntries = ref
        .watch(scheduleItemsProvider)
        .maybeWhen(data: _hasVisibleScheduleEntries, orElse: () => false);
    final addTooltip = switch (_selected) {
      _Destination.work => 'Add shift',
      _Destination.school => 'Add class',
      _Destination.plans => 'Add plan',
      _Destination.week => 'Add event',
      _Destination.today => switch (widget.mode) {
        ScheduleMode.workOnly => 'Add shift',
        ScheduleMode.schoolOnly => 'Add class',
        ScheduleMode.personalPlanner => 'Add plan',
        ScheduleMode.workAndSchool => 'Add event',
      },
      _Destination.more => 'Add event',
    };
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          key: const Key('schedule-primary-swipe-handle'),
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (_) => _startDestinationDrag(),
          onHorizontalDragUpdate: (details) =>
              _updateDestinationDrag(details, MediaQuery.sizeOf(context).width),
          onHorizontalDragEnd: (details) =>
              _finishDestinationDrag(details, items),
          child: SizedBox(
            width: double.infinity,
            child: AnimatedSwitcher(
              duration: AppMotion.duration(context, AppMotion.change),
              reverseDuration: AppMotion.duration(context, AppMotion.exit),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInOutCubic,
              transitionBuilder: AppMotion.sharedFadeSlide,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [...previousChildren, ?currentChild],
              ),
              child: _selected == _Destination.today
                  ? const StudyShiftWordmark(key: ValueKey(_Destination.today))
                  : Text(_title, key: ValueKey(_selected)),
            ),
          ),
        ),
        actions: [
          if (_selected == _Destination.today)
            IconButton(
              tooltip: 'Set up reminders',
              onPressed: _requestNotificationPermission,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
          if (_canAdd &&
              (_selected == _Destination.today ||
                  _selected == _Destination.week ||
                  _selected == _Destination.work ||
                  compactHeight ||
                  hasVisibleEntries))
            IconButton(
              tooltip: addTooltip,
              onPressed: () => _add(
                initialDate:
                    _selected == _Destination.week ||
                        _selected == _Destination.today
                    ? _selectedDay
                    : null,
              ),
              icon: const ShiftIcon('plus'),
            ),
        ],
      ),
      body: Row(
        children: [
          if (useNavigationRail)
            NavigationRail(
              selectedIndex: selectedIndex,
              labelType: compactHeight
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              scrollable: true,
              onDestinationSelected: (index) => _navigateToIndex(index, items),
              destinations: [
                for (final item in items)
                  NavigationRailDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: Text(item.label),
                  ),
              ],
            ),
          Expanded(
            child: ClipRect(
              key: const Key('schedule-page-viewport'),
              child: LayoutBuilder(
                builder: (context, constraints) => GestureDetector(
                  key: const Key('schedule-main-pages'),
                  behavior: HitTestBehavior.opaque,
                  onHorizontalDragStart: (_) => _startDestinationDrag(),
                  onHorizontalDragUpdate: (details) =>
                      _updateDestinationDrag(details, constraints.maxWidth),
                  onHorizontalDragEnd: (details) =>
                      _finishDestinationDrag(details, items),
                  child: NavigationPageTrack(
                    pagePosition: _pagePosition,
                    pageWidth: constraints.maxWidth,
                    selectedIndex: selectedIndex,
                    pages: [
                      for (final item in items)
                        _RetainedDestinationPage(
                          key: ValueKey(item.destination),
                          child: _page(item.destination),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: useNavigationRail
          ? null
          : NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) => _navigateToIndex(index, items),
              destinations: [
                for (final item in items)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    selectedIcon: Icon(item.selectedIcon),
                    label: item.label,
                  ),
              ],
            ),
      floatingActionButton:
          _canAdd &&
              _selected != _Destination.today &&
              _selected != _Destination.work &&
              _selected != _Destination.week &&
              !compactHeight &&
              !hasVisibleEntries
          ? FloatingActionButton(
              tooltip: addTooltip,
              onPressed: () => _add(
                initialDate:
                    _selected == _Destination.today ||
                        _selected == _Destination.week
                    ? _selectedDay
                    : null,
              ),
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}

class _RetainedDestinationPage extends StatefulWidget {
  const _RetainedDestinationPage({super.key, required this.child});

  final Widget child;

  @override
  State<_RetainedDestinationPage> createState() =>
      _RetainedDestinationPageState();
}

class _RetainedDestinationPageState extends State<_RetainedDestinationPage>
    with AutomaticKeepAliveClientMixin<_RetainedDestinationPage> {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
