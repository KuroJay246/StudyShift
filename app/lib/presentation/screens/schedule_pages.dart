export '../weather_condition_icon.dart'
    show weatherIconFor, weatherIconColorFor, greetingForWeather;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'dart:async';
import 'dart:convert';

import '../../application/dependencies.dart';
import '../../application/day_availability.dart';
import '../../application/schedule_queries.dart';
import '../../domain/schedule.dart';
import '../../domain/schedule_engine.dart';
import '../../domain/work_overtime.dart';
import '../../data/preferences_repository.dart';
import '../../data/weather_repository.dart';
import '../../data/open_meteo_weather_service.dart';
import '../app_theme.dart';
import '../design/studyshift_spacing.dart';
import '../schedule_format.dart';
import '../weather_condition_icon.dart';
import '../motion.dart';
import '../widgets/schedule_event_tile.dart';
import '../widgets/schedule_details_sheet.dart';
import '../widgets/shift_icon.dart';
import '../widgets/today_hero.dart';
import '../widgets/week_grid.dart';
import 'academic_terms_page.dart';
import 'event_editor_page.dart';
import 'work_code_legend_page.dart';
import 'weather_settings_page.dart';

String greetingForLocalHour(int hour) =>
    greetingForWeather(localHour: hour, isDay: null);

String _hoursLabel(int minutes) =>
    '${(minutes / 60).toStringAsFixed(minutes % 60 == 0 ? 0 : 1)}h';

SchedulePalette _todayFeaturePalette(BuildContext context) {
  final theme = Theme.of(context);
  return theme.extension<SchedulePalette>() ??
      (theme.brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light())
          .extension<SchedulePalette>()!;
}

class TodayPage extends ConsumerStatefulWidget {
  const TodayPage({
    super.key,
    required this.selectedDay,
    required this.onSelectedDateChanged,
    this.clock,
  });

  final CivilDate selectedDay;
  final ValueChanged<CivilDate> onSelectedDateChanged;
  final DateTime Function()? clock;

  @override
  ConsumerState<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends ConsumerState<TodayPage>
    with WidgetsBindingObserver {
  static const _weatherRefreshInterval = Duration(minutes: 15);

  CivilDate get selectedDay => widget.selectedDay;
  ValueChanged<CivilDate> get onSelectedDateChanged =>
      widget.onSelectedDateChanged;
  DateTime Function()? get clock => widget.clock;

  Timer? _clockRefresh;
  DateTime? _lastWeatherRefreshAttempt;
  WeatherPlace? _pendingWeatherPlace;
  bool _weatherPlaceUnavailable = false;

  static bool _sameWeatherPlace(WeatherPlace first, WeatherPlace second) =>
      first.latitude.toStringAsFixed(4) == second.latitude.toStringAsFixed(4) &&
      first.longitude.toStringAsFixed(4) == second.longitude.toStringAsFixed(4);

  static WeatherPlace? _savedWeatherPlace(AppPreferences? preferences) {
    final encoded = preferences?.weatherLocationJson;
    if (encoded == null) return null;
    try {
      return decodeWeatherPlace(jsonDecode(encoded));
    } on FormatException {
      return null;
    }
  }

  void _selectWeatherPlace(WeatherPlace place) {
    setState(() {
      _pendingWeatherPlace = place;
      _weatherPlaceUnavailable = false;
    });
    unawaited(_persistWeatherPlace(place));
  }

  Future<void> _persistWeatherPlace(WeatherPlace place) async {
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .setWeatherLocation(jsonEncode(encodeWeatherPlace(place)));
      if (!mounted) return;
      ref.invalidate(appPreferencesProvider);
      _invalidateWeatherReading();
    } on Object {
      if (mounted) setState(() => _pendingWeatherPlace = null);
    }
  }

  DateTime _now() => clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClockRefresh();
  }

  void _scheduleClockRefresh() {
    final now = DateTime.now();
    final delay =
        const Duration(minutes: 1) -
        Duration(
          seconds: now.second,
          milliseconds: now.millisecond,
          microseconds: now.microsecond,
        );
    _clockRefresh = Timer(delay, () {
      if (!mounted) return;
      _refreshWeatherIfDue();
      setState(() {});
      _scheduleClockRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _refreshWeatherIfDue();
      setState(() {});
    }
  }

  void _refreshWeatherIfDue() {
    if (ref.read(appPreferencesProvider).value?.weatherEnabled != true) return;
    final now = _now();
    final lastAttempt = _lastWeatherRefreshAttempt;
    if (lastAttempt == null) {
      _lastWeatherRefreshAttempt = now;
      return;
    }
    if (now.difference(lastAttempt) < _weatherRefreshInterval) return;
    _invalidateWeatherReading();
  }

  void _invalidateWeatherReading() {
    _lastWeatherRefreshAttempt = _now();
    ref.invalidate(weatherReadingProvider);
  }

  Future<void> _refreshToday() async {
    final refreshedSchedule = ref.refresh(scheduleItemsProvider.future);
    await refreshedSchedule;
    final preferences = await ref.read(appPreferencesProvider.future);
    if (preferences.weatherEnabled != true) return;
    _lastWeatherRefreshAttempt = _now();
    final refreshedWeather = ref.refresh(weatherReadingProvider.future);
    try {
      await refreshedWeather;
    } on Object {
      // The provider keeps the weather error state, while the rest of the
      // schedule refresh remains successful and the details sheet can retry.
    }
  }

  @override
  void dispose() {
    _clockRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _chooseDay(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(
        selectedDay.year,
        selectedDay.month,
        selectedDay.day,
      ),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (selected != null) {
      onSelectedDateChanged(CivilDate.fromDateTime(selected));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(scheduleItemsProvider);
    final preferences = ref.watch(appPreferencesProvider).value;
    return items.when(
      loading: () => const _PageLoading(),
      error: (error, _) => _PageError(
        message: error.toString(),
        onRetry: () => ref.invalidate(scheduleItemsProvider),
      ),
      data: (allItems) {
        final compactLayout = MediaQuery.sizeOf(context).height < 500;
        final now = clock?.call() ?? DateTime.now();
        if (preferences?.weatherEnabled == true) {
          _lastWeatherRefreshAttempt ??= now;
        } else {
          _lastWeatherRefreshAttempt = null;
        }
        final queries = ref.read(scheduleQueriesProvider);
        final occurrences = queries.forDay(allItems, selectedDay);
        final analysis = queries.analyzeRange(
          allItems,
          selectedDay,
          selectedDay,
        );
        final conflictedIds = <String>{
          for (final conflict in analysis.conflicts) ...[
            conflict.first.item.id,
            conflict.second.item.id,
          ],
        };
        final issuesById = <String, List<ScheduleTimeIssue>>{};
        for (final issue in analysis.timeIssues) {
          (issuesById[issue.occurrence.item.id] ??= []).add(issue);
        }
        final use24 = preferenceUses24Hour(preferences, context);
        final weatherPreferences = preferences;
        final weatherReading = preferences?.weatherEnabled == true
            ? ref.watch(weatherReadingProvider)
            : const AsyncData<WeatherReading?>(null);
        final active = queries.currentlyHappening(allItems, now);
        final next = active ?? queries.nextUpcoming(allItems, now);
        final deviceZone = ref.watch(deviceTimeZoneIdProvider).value;
        final availabilityOccurrences = queries.forRange(
          allItems,
          selectedDay.addDays(-1),
          selectedDay.addDays(1),
        );
        final availability = deviceZone == null
            ? null
            : ref
                  .read(dayAvailabilityProvider)
                  .calculate(
                    occurrences: availabilityOccurrences,
                    date: selectedDay,
                    deviceTimeZoneId: deviceZone,
                    now: now,
                  );
        final localizations = MaterialLocalizations.of(context);
        final date = DateTime(
          selectedDay.year,
          selectedDay.month,
          selectedDay.day,
        );
        final today = CivilDate.fromDateTime(now);
        final isToday = selectedDay == today;
        final featuredNext =
            active ??
            (next != null &&
                    (occurrences.isEmpty ||
                        occurrences.every((entry) => entry.item.isDayOff) ||
                        CivilDate.fromDateTime(next.interval.start) == today)
                ? next
                : null);
        final nextEventDate = featuredNext == null
            ? null
            : CivilDate.fromDateTime(featuredNext.interval.start);
        final nextEventDateLabel =
            nextEventDate == null || nextEventDate == today
            ? null
            : localizations.formatMediumDate(
                DateTime(
                  nextEventDate.year,
                  nextEventDate.month,
                  nextEventDate.day,
                ),
              );

        final weatherReadingValue = weatherReading.asData?.value;
        ref.listen<AsyncValue<WeatherReading?>>(weatherReadingProvider, (
          _,
          next,
        ) {
          final pendingPlace = _pendingWeatherPlace;
          final loadedPlace = next.asData?.value?.place;
          if (pendingPlace != null &&
              loadedPlace != null &&
              _sameWeatherPlace(pendingPlace, loadedPlace)) {
            setState(() {
              _pendingWeatherPlace = null;
              _weatherPlaceUnavailable = false;
            });
          } else if (pendingPlace != null && next.hasError) {
            setState(() => _weatherPlaceUnavailable = true);
          }
        });
        final pendingPlace = _pendingWeatherPlace;
        final weatherPlaces = weatherPreferences?.weatherEnabled == true
            ? weatherPlacesFor(weatherPreferences!)
            : const <WeatherPlace>[];
        final activeWeatherPlace =
            pendingPlace ??
            weatherReadingValue?.place ??
            _savedWeatherPlace(weatherPreferences);
        final waitingForWeatherPlace =
            pendingPlace != null &&
            (weatherReadingValue == null ||
                !_sameWeatherPlace(pendingPlace, weatherReadingValue.place));
        final isNight = weatherReadingValue == null
            ? TodayHero.isNightForHour(now.hour)
            : !weatherReadingValue.snapshot.isDay;
        final greetingHour = weatherReadingValue == null
            ? now.hour
            : weatherReadingValue.snapshot.localClockAt(now).hour;
        final weatherSummary =
            isToday &&
                weatherPreferences != null &&
                weatherPreferences.weatherEnabled == true
            ? waitingForWeatherPlace
                  ? _WeatherLoadingSummary(
                      placeName: pendingPlace.name,
                      pageIndex: weatherPlaces.indexWhere(
                        (place) => _sameWeatherPlace(place, pendingPlace),
                      ),
                      pageCount: weatherPlaces.length,
                      unavailable: _weatherPlaceUnavailable,
                    )
                  : weatherReading.when(
                      loading: () => const _WeatherLoadingSummary(),
                      error: (_, _) => _WeatherSetupSummary(
                        onTap: () => _openWeatherSettings(context),
                      ),
                      data: (reading) => reading == null
                          ? _WeatherSetupSummary(
                              onTap: () => _openWeatherSettings(context),
                            )
                          : _TodayWeatherSummary(
                              reading: reading,
                              places: weatherPlaces,
                              onPlaceChanged: _selectWeatherPlace,
                              onTap: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                builder: (context) => SafeArea(
                                  child: SingleChildScrollView(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      0,
                                      16,
                                      20,
                                    ),
                                    child: _WeatherSummaryCard(
                                      reading: reading,
                                      use24Hour: use24,
                                      onRefresh: _invalidateWeatherReading,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    )
            : null;
        final weatherCaption = isToday && waitingForWeatherPlace
            ? _WeatherLoadingCaption(
                placeName: pendingPlace.name,
                enabled:
                    weatherPreferences?.showWeatherLocationAndCondition ?? true,
                unavailable: _weatherPlaceUnavailable,
              )
            : isToday && weatherReadingValue != null
            ? _TodayWeatherCaption(
                reading: weatherReadingValue,
                preferences: preferences!,
                places: weatherPlaces,
                use24Hour: use24,
                onPlaceChanged: _selectWeatherPlace,
                onTap: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (context) => SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      child: _WeatherSummaryCard(
                        reading: weatherReadingValue,
                        use24Hour: use24,
                        onRefresh: _invalidateWeatherReading,
                      ),
                    ),
                  ),
                ),
              )
            : null;

        return RefreshIndicator(
          onRefresh: _refreshToday,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              StudyShiftSpacing.pageMargin,
              StudyShiftSpacing.pageMargin,
              StudyShiftSpacing.pageMargin,
              112,
            ),
            children: [
              TodayHero(
                greeting: _greeting(
                  greetingHour,
                  weatherReadingValue?.snapshot.isDay,
                ),
                hour: greetingHour,
                dateLabel: localizations.formatFullDate(date),
                isToday: isToday,
                weatherPageKey: activeWeatherPlace == null
                    ? null
                    : '${activeWeatherPlace.latitude}:${activeWeatherPlace.longitude}',
                weatherSummary: weatherSummary,
                weatherCaption: weatherCaption,
                onWeatherSwipe:
                    weatherPreferences?.weatherEnabled != true ||
                        activeWeatherPlace == null ||
                        weatherPlaces.length < 2
                    ? null
                    : (direction) {
                        final place = cycleWeatherPlace(
                          weatherPreferences!,
                          activeWeatherPlace,
                          direction,
                        );
                        if (place != null) _selectWeatherPlace(place);
                      },
                featuredContent: isToday
                    ? featuredNext != null
                          ? _NextEventPanel(
                              item: featuredNext.occurrence.item,
                              time: formatMinute(
                                featuredNext.interval.start.hour * 60 +
                                    featuredNext.interval.start.minute,
                                use24Hour: use24,
                              ),
                              endTime: formatMinute(
                                featuredNext.interval.end.hour * 60 +
                                    featuredNext.interval.end.minute,
                                use24Hour: use24,
                              ),
                              countdown: _countdown(
                                active == null
                                    ? featuredNext.interval.start.difference(
                                        now,
                                      )
                                    : featuredNext.interval.end.difference(now),
                                ending: active != null,
                              ),
                              isInProgress: active != null,
                              dateLabel: nextEventDateLabel,
                              compact: compactLayout,
                              onTap: () => showScheduleDetails(
                                context,
                                ref,
                                featuredNext.occurrence.item,
                                occurrenceDate: featuredNext.occurrence.date,
                              ),
                            )
                          : _NextEventEmptyPanel(
                              compact: compactLayout,
                              hasEvents: occurrences.isNotEmpty,
                            )
                    : null,
                compact: compactLayout,
                onChooseDay: () => _chooseDay(context),
                onToday: () => onSelectedDateChanged(today),
              ),
              SizedBox(height: compactLayout ? 4 : 14),
              if (analysis.conflicts.isNotEmpty) ...[
                const SizedBox(height: 16),
                _ConflictSummaryPanel(
                  conflicts: analysis.conflicts,
                  onSelect: (occurrence) => showScheduleDetails(
                    context,
                    ref,
                    occurrence.item,
                    occurrenceDate: occurrence.date,
                  ),
                ),
              ],
              if (issuesById.isNotEmpty) ...[
                const SizedBox(height: 14),
                _TimeReviewPanel(
                  issues: analysis.timeIssues,
                  onSelect: (occurrence) => showScheduleDetails(
                    context,
                    ref,
                    occurrence.item,
                    occurrenceDate: occurrence.date,
                  ),
                ),
              ],
              SizedBox(height: compactLayout ? 8 : 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isToday ? 'Today’s schedule' : 'Schedule',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${occurrences.length} ${occurrences.length == 1 ? 'event' : 'events'}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              SizedBox(height: compactLayout ? 4 : 12),
              if (occurrences.isEmpty)
                _EmptyPanel(
                  compact: compactLayout,
                  icon: Icons.calendar_today_outlined,
                  title: isNight
                      ? 'A quiet night ahead'
                      : 'A little room in your day',
                  detail: 'Add a shift, class or plan whenever you’re ready.',
                )
              else
                for (var index = 0; index < occurrences.length; index++) ...[
                  ScheduleEventTile(
                    item: occurrences[index].item,
                    use24Hour: use24,
                    staggerIndex: index,
                    countdownLabel: deadlineCountdownLabel(
                      occurrences[index].item,
                      selectedDay,
                    ),
                    conflict: conflictedIds.contains(
                      occurrences[index].item.id,
                    ),
                    reviewTime: issuesById.containsKey(
                      occurrences[index].item.id,
                    ),
                    dateLabel:
                        occurrences[index].date.compareTo(selectedDay) < 0
                        ? 'Started ${localizations.formatShortDate(DateTime(occurrences[index].date.year, occurrences[index].date.month, occurrences[index].date.day))}'
                        : null,
                    onTap: () => showScheduleDetails(
                      context,
                      ref,
                      occurrences[index].item,
                      occurrenceDate: occurrences[index].date,
                    ),
                  ),
                  if (index < occurrences.length - 1)
                    const SizedBox(height: 10),
                ],
              const SizedBox(height: 22),
              if (availability != null && occurrences.isNotEmpty) ...[
                _AvailablePeriodsPanel(periods: availability, use24Hour: use24),
                const SizedBox(height: 22),
              ],
            ],
          ),
        );
      },
    );
  }

  String _greeting(int localHour, bool? isDay) =>
      greetingForWeather(localHour: localHour, isDay: isDay);

  void _openWeatherSettings(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const WeatherSettingsPage()),
    );
  }

  String _countdown(Duration remaining, {bool ending = false}) {
    if (remaining.isNegative) {
      return ending ? 'Ending now' : 'Starting now';
    }
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    if (hours == 0 && minutes == 0) {
      return ending ? 'Ending now' : 'Starting now';
    }
    final duration = hours == 0
        ? '${minutes}m'
        : minutes == 0
        ? '${hours}h'
        : '${hours}h ${minutes}m';
    return ending ? 'ends in $duration' : 'in $duration';
  }
}

class _TodayWeatherSummary extends StatelessWidget {
  const _TodayWeatherSummary({
    required this.reading,
    required this.places,
    required this.onPlaceChanged,
    required this.onTap,
  });

  final WeatherReading reading;
  final List<WeatherPlace> places;
  final ValueChanged<WeatherPlace> onPlaceChanged;
  final VoidCallback onTap;

  void _changePlace(int direction) {
    final activeIndex = places.indexWhere(
      (place) =>
          place.latitude == reading.place.latitude &&
          place.longitude == reading.place.longitude,
    );
    if (places.length < 2) return;
    final current = activeIndex < 0 ? 0 : activeIndex;
    onPlaceChanged(places[(current + direction) % places.length]);
  }

  @override
  Widget build(BuildContext context) {
    final weather = reading.snapshot;
    final description = weatherDescription(weather.weatherCode);
    final activeIndex = places.indexWhere(
      (place) =>
          place.latitude == reading.place.latitude &&
          place.longitude == reading.place.longitude,
    );
    final pageIndex = activeIndex < 0 ? 0 : activeIndex;
    return SizedBox(
      key: const ValueKey('today-weather-place-pager'),
      child: Semantics(
        button: true,
        explicitChildNodes: true,
        onIncrease: places.length < 2 ? null : () => _changePlace(1),
        onDecrease: places.length < 2 ? null : () => _changePlace(-1),
        label:
            'Weather in ${reading.place.name}: $description, ${weather.temperatureC.round()} degrees. Swipe to change location. Show details.',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: AnimatedSwitcher(
                key: const ValueKey('today-weather-summary-transition'),
                duration: AppMotion.duration(context, AppMotion.change),
                reverseDuration: AppMotion.duration(context, AppMotion.exit),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: AppMotion.sharedFadeSlide,
                child: Column(
                  key: ValueKey(
                    '${reading.place.latitude}:${reading.place.longitude}',
                  ),
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        WeatherConditionIcon(
                          code: weather.weatherCode,
                          isDay: weather.isDay,
                          windSpeedKmh: weather.windSpeedKmh,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${weather.temperatureC.round()}°',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (places.length > 1) ...[
                      const SizedBox(height: 4),
                      _WeatherPlaceIndicator(
                        pageIndex: pageIndex,
                        pageCount: places.length,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherPlaceIndicator extends StatelessWidget {
  const _WeatherPlaceIndicator({
    required this.pageIndex,
    required this.pageCount,
  });

  final int pageIndex;
  final int pageCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Weather location ${pageIndex + 1} of $pageCount',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < pageCount; index++) ...[
              if (index > 0) const SizedBox(width: 4),
              AnimatedContainer(
                key: ValueKey('today-weather-place-dot-$index'),
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: index == pageIndex ? 14 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: index == pageIndex
                      ? colors.primary
                      : colors.onSurfaceVariant.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayWeatherCaption extends StatelessWidget {
  const _TodayWeatherCaption({
    required this.reading,
    required this.preferences,
    required this.places,
    required this.use24Hour,
    required this.onPlaceChanged,
    required this.onTap,
  });

  final WeatherReading reading;
  final AppPreferences preferences;
  final List<WeatherPlace> places;
  final bool use24Hour;
  final ValueChanged<WeatherPlace> onPlaceChanged;
  final VoidCallback onTap;

  void _changePlace(int direction) {
    if (places.length < 2) return;
    final activeIndex = places.indexWhere(
      (place) =>
          place.latitude == reading.place.latitude &&
          place.longitude == reading.place.longitude,
    );
    final current = activeIndex < 0 ? 0 : activeIndex;
    onPlaceChanged(
      places[(current + direction + places.length) % places.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    final weather = reading.snapshot;
    final details = <String>[
      if (preferences.showWeatherFeelsLike)
        'Feels like ${weather.apparentTemperatureC.round()}°C',
      if (preferences.showWeatherRainChance &&
          weather.precipitationProbability != null)
        'Rain ${weather.precipitationProbability}%',
      if (preferences.showWeatherWindSpeed)
        'Wind ${weather.windSpeedKmh.round()} km/h',
      if (preferences.showWeatherSunriseSunset && weather.sunrise != null)
        'Sunrise ${formatMinute(weather.sunrise!.hour * 60 + weather.sunrise!.minute, use24Hour: use24Hour)}',
      if (preferences.showWeatherSunriseSunset && weather.sunset != null)
        'Sunset ${formatMinute(weather.sunset!.hour * 60 + weather.sunset!.minute, use24Hour: use24Hour)}',
      if (preferences.showWeatherLastUpdated)
        'Updated ${formatMinute(reading.fetchedAt.hour * 60 + reading.fetchedAt.minute, use24Hour: use24Hour)}',
    ];
    final caption = preferences.showWeatherLocationAndCondition
        ? '${reading.place.name} · ${weatherDescription(weather.weatherCode)}'
        : null;
    if (caption == null &&
        (preferences.effectiveWeatherLayout != WeatherLayout.moreDetails ||
            details.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Semantics(
      button: true,
      onIncrease: places.length < 2 ? null : () => _changePlace(1),
      onDecrease: places.length < 2 ? null : () => _changePlace(-1),
      label:
          'Weather details for ${reading.place.name}. Swipe to change location.',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: AnimatedSwitcher(
              key: const ValueKey('today-weather-caption-transition'),
              duration: AppMotion.duration(context, AppMotion.change),
              reverseDuration: AppMotion.duration(context, AppMotion.exit),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: AppMotion.sharedFadeSlide,
              child: Column(
                key: ValueKey(
                  '${reading.place.latitude}:${reading.place.longitude}',
                ),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (caption != null)
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  if (preferences.effectiveWeatherLayout ==
                          WeatherLayout.moreDetails &&
                      details.isNotEmpty)
                    Text(
                      details.join('  ·  '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WeatherLoadingSummary extends StatelessWidget {
  const _WeatherLoadingSummary({
    this.placeName,
    this.pageIndex = 0,
    this.pageCount = 0,
    this.unavailable = false,
  });

  final String? placeName;
  final int pageIndex;
  final int pageCount;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => Semantics(
    label: placeName == null
        ? 'Loading local weather'
        : unavailable
        ? 'Weather unavailable for $placeName'
        : 'Updating weather for $placeName',
    liveRegion: true,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_outlined,
              color: Theme.of(context).colorScheme.secondary,
              size: 24,
            ),
            const SizedBox(width: 4),
            Text(
              '—°',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        if (placeName != null)
          Text(
            unavailable ? 'Weather unavailable' : placeName!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          )
        else
          Text(
            'Loading weather',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        if (pageCount > 1) ...[
          const SizedBox(height: 4),
          _WeatherPlaceIndicator(pageIndex: pageIndex, pageCount: pageCount),
        ],
      ],
    ),
  );
}

class _WeatherLoadingCaption extends StatelessWidget {
  const _WeatherLoadingCaption({
    required this.placeName,
    required this.enabled,
    required this.unavailable,
  });

  final String placeName;
  final bool enabled;
  final bool unavailable;

  @override
  Widget build(BuildContext context) => enabled
      ? ExcludeSemantics(
          child: Text(
            '$placeName · ${unavailable ? 'Weather unavailable' : 'Updating weather'}',
            key: const ValueKey('today-weather-updating-caption'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        )
      : const SizedBox.shrink();
}

class _WeatherSetupSummary extends StatelessWidget {
  const _WeatherSetupSummary({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onTap,
    icon: const Icon(Icons.cloud_off_outlined),
    label: const Text('Set up weather'),
  );
}

class _WeatherSummaryCard extends StatelessWidget {
  const _WeatherSummaryCard({
    required this.reading,
    required this.use24Hour,
    required this.onRefresh,
  });

  final WeatherReading reading;
  final bool use24Hour;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weather = reading.snapshot;
    final icon = weatherIconFor(
      code: weather.weatherCode,
      isDay: weather.isDay,
      windSpeedKmh: weather.windSpeedKmh,
    );
    final iconColor = weatherIconColorFor(
      code: weather.weatherCode,
      isDay: weather.isDay,
      windSpeedKmh: weather.windSpeedKmh,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    final secondary = <String>[
      if (weather.precipitationProbability != null)
        'Rain ${weather.precipitationProbability}%',
      'Wind ${weather.windSpeedKmh.round()} km/h',
    ].join('  ·  ');
    final daylight = <String>[
      if (weather.sunrise != null)
        'Sunrise ${formatMinute(weather.sunrise!.hour * 60 + weather.sunrise!.minute, use24Hour: use24Hour)}',
      if (weather.sunset != null)
        'Sunset ${formatMinute(weather.sunset!.hour * 60 + weather.sunset!.minute, use24Hour: use24Hour)}',
    ].join('  ·  ');

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    reading.place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh weather',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '${weather.temperatureC.round()}°',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          weatherDescription(weather.weatherCode),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          'Feels like ${weather.apparentTemperatureC.round()}°C',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(secondary, style: theme.textTheme.bodySmall),
            ],
            if (daylight.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(daylight, style: theme.textTheme.bodySmall),
            ],
            if (weather.hourlyForecast.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Coming up',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 102,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: weather.hourlyForecast.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final forecast = weather.hourlyForecast[index];
                    final forecastIcon = weatherIconFor(
                      code: forecast.weatherCode,
                      isDay: forecast.isDay,
                      windSpeedKmh: forecast.windSpeedKmh,
                    );
                    final forecastColor = weatherIconColorFor(
                      code: forecast.weatherCode,
                      isDay: forecast.isDay,
                      windSpeedKmh: forecast.windSpeedKmh,
                      isDark: Theme.of(context).brightness == Brightness.dark,
                    );
                    return Container(
                      width: 82,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatMinute(
                              forecast.localTime.hour * 60 +
                                  forecast.localTime.minute,
                              use24Hour: use24Hour,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                          Icon(forecastIcon, color: forecastColor, size: 20),
                          Text(
                            '${forecast.temperatureC.round()}°',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Rain ${forecast.precipitationProbability}%',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
            if (reading.isCached) ...[
              const SizedBox(height: 6),
              Text(
                'Saved weather · may be out of date',
                style: theme.textTheme.labelSmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class WeekPage extends ConsumerStatefulWidget {
  const WeekPage({
    super.key,
    required this.focusDate,
    required this.onFocusDateChanged,
  });

  final CivilDate focusDate;
  final ValueChanged<CivilDate> onFocusDateChanged;

  @override
  ConsumerState<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends ConsumerState<WeekPage> {
  bool _monthView = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final focusDate = widget.focusDate;
    final weekStart = _mondayOf(focusDate);
    final items = ref.watch(scheduleItemsProvider);
    final preferences = ref.watch(appPreferencesProvider).value;
    return items.when(
      loading: () => const _PageLoading(),
      error: (error, _) => _PageError(
        message: error.toString(),
        onRetry: () => ref.invalidate(scheduleItemsProvider),
      ),
      data: (allItems) {
        final compactHeight = MediaQuery.sizeOf(context).height < 500;
        final queries = ref.read(scheduleQueriesProvider);
        final monthStart = CivilDate(focusDate.year, focusDate.month, 1);
        final monthGridStart = _mondayOf(monthStart);
        final rangeStart = _monthView ? monthGridStart : weekStart;
        final rangeEnd = _monthView
            ? monthGridStart.addDays(41)
            : weekStart.addDays(6);
        final occurrences = queries.forRange(allItems, rangeStart, rangeEnd);
        final analysis = queries.analyzeRange(allItems, rangeStart, rangeEnd);
        final conflicts = <String>{
          for (final conflict in analysis.conflicts) ...[
            conflict.first.item.id,
            conflict.second.item.id,
          ],
        };
        final use24 = preferenceUses24Hour(preferences, context);
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                compactHeight ? 2 : 6,
                16,
                compactHeight ? 2 : 8,
              ),
              child: Row(
                key: const ValueKey('week-range-navigation-header'),
                children: [
                  IconButton(
                    tooltip: _monthView ? 'Previous month' : 'Previous week',
                    onPressed: () => widget.onFocusDateChanged(
                      _monthView
                          ? _shiftMonth(focusDate, -1)
                          : focusDate.addDays(-7),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.change),
                      reverseDuration: AppMotion.duration(
                        context,
                        AppMotion.exit,
                      ),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: AppMotion.sharedFadeSlide,
                      child: KeyedSubtree(
                        key: ValueKey(weekStart),
                        child: Text(
                          _monthView
                              ? MaterialLocalizations.of(context)
                                    .formatMonthYear(
                                      DateTime(focusDate.year, focusDate.month),
                                    )
                              : formatWeekRange(
                                  MaterialLocalizations.of(context),
                                  weekStart,
                                ),
                          textAlign: TextAlign.center,
                          key: const Key('week-range-label'),
                          maxLines: 2,
                          softWrap: true,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          semanticsLabel: _monthView
                              ? MaterialLocalizations.of(context)
                                    .formatMonthYear(
                                      DateTime(focusDate.year, focusDate.month),
                                    )
                              : formatWeekRange(
                                  MaterialLocalizations.of(context),
                                  weekStart,
                                ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: _monthView ? 'Next month' : 'Next week',
                    onPressed: () => widget.onFocusDateChanged(
                      _monthView
                          ? _shiftMonth(focusDate, 1)
                          : focusDate.addDays(7),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                  TextButton(
                    onPressed: () => widget.onFocusDateChanged(
                      CivilDate.fromDateTime(DateTime.now()),
                    ),
                    child: const Text('Today'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, compactHeight ? 2 : 8),
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Week'),
                    icon: ShiftIcon('calendar-range'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Month'),
                    icon: ShiftIcon('calendar-days'),
                  ),
                ],
                selected: {_monthView},
                onSelectionChanged: (selection) =>
                    setState(() => _monthView = selection.first),
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    final scheme = Theme.of(context).colorScheme;
                    return states.contains(WidgetState.selected)
                        ? scheme.primary
                        : Colors.transparent;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    final scheme = Theme.of(context).colorScheme;
                    return states.contains(WidgetState.selected)
                        ? scheme.onPrimary
                        : scheme.onSurface;
                  }),
                  side: WidgetStateProperty.resolveWith((states) {
                    final scheme = Theme.of(context).colorScheme;
                    return BorderSide(
                      color: states.contains(WidgetState.selected)
                          ? scheme.primary
                          : scheme.outlineVariant,
                    );
                  }),
                ),
              ),
            ),
            if (!_monthView && occurrences.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: StudyShiftSpacing.pageMargin,
                  vertical: compactHeight ? 2 : StudyShiftSpacing.x2,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_view_week_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: StudyShiftSpacing.x3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'This week is open',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (!compactHeight)
                            Text(
                              'Add a shift, class or plan to start filling in your week.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _monthView
                  ? _MonthCalendar(
                      firstDay: monthGridStart,
                      month: monthStart,
                      focusDate: focusDate,
                      occurrences: occurrences,
                      selectedOccurrences: queries.forDay(allItems, focusDate),
                      conflictedIds: conflicts,
                      use24Hour: use24,
                      onSelectDate: widget.onFocusDateChanged,
                      onSelectEvent: (occurrence) => showScheduleDetails(
                        context,
                        ref,
                        occurrence.item,
                        occurrenceDate: occurrence.date,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: AppMotion.duration(context, AppMotion.change),
                      reverseDuration: AppMotion.duration(
                        context,
                        AppMotion.exit,
                      ),
                      switchInCurve: Curves.easeInOutCubic,
                      switchOutCurve: Curves.easeInOutCubic,
                      transitionBuilder: AppMotion.sharedFadeSlide,
                      child: WeekGrid(
                        key: ValueKey(weekStart),
                        weekStart: weekStart,
                        focusDate: focusDate,
                        occurrences: occurrences,
                        conflictedIds: conflicts,
                        use24Hour: use24,
                        onFocusDateChanged: widget.onFocusDateChanged,
                        onSelect: (occurrence) => showScheduleDetails(
                          context,
                          ref,
                          occurrence.item,
                          occurrenceDate: occurrence.date,
                        ),
                      ),
                    ),
            ),
            if (analysis.timeIssues.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: _TimeReviewPanel(
                  issues: analysis.timeIssues,
                  onSelect: (occurrence) => showScheduleDetails(
                    context,
                    ref,
                    occurrence.item,
                    occurrenceDate: occurrence.date,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.firstDay,
    required this.month,
    required this.focusDate,
    required this.occurrences,
    required this.selectedOccurrences,
    required this.conflictedIds,
    required this.use24Hour,
    required this.onSelectDate,
    required this.onSelectEvent,
  });

  final CivilDate firstDay;
  final CivilDate month;
  final CivilDate focusDate;
  final List<EventOccurrence> occurrences;
  final List<EventOccurrence> selectedOccurrences;
  final Set<String> conflictedIds;
  final bool use24Hour;
  final ValueChanged<CivilDate> onSelectDate;
  final ValueChanged<EventOccurrence> onSelectEvent;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SchedulePalette>()!;
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    final localizations = MaterialLocalizations.of(context);
    final dayEvents = <CivilDate, List<EventOccurrence>>{};
    final monthOccurrences = occurrences
        .where(
          (entry) =>
              entry.date.year == month.year && entry.date.month == month.month,
        )
        .toList(growable: false);
    final monthSummary = _monthSummary(monthOccurrences);
    for (final day in List.generate(42, (index) => firstDay.addDays(index))) {
      dayEvents[day] = occurrences.where((entry) {
        if (entry.item.hasNoTime) return entry.date == day;
        return entry.item.intervals.any((interval) {
          final start = entry.date.addDays(interval.startDayOffset);
          final end = entry.date.addDays(interval.endDayOffset);
          return day.compareTo(start) >= 0 &&
              (day.compareTo(end) < 0 ||
                  (day == end && interval.endMinute > 0));
        });
      }).toList();
    }
    final dateLabel = localizations.formatFullDate(
      DateTime(focusDate.year, focusDate.month, focusDate.day),
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              for (final weekday in weekdays)
                Expanded(
                  child: Center(
                    child: Text(
                      weekday,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.05,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          children: [
            for (var index = 0; index < 42; index++)
              Builder(
                builder: (context) {
                  final day = firstDay.addDays(index);
                  final events = dayEvents[day]!;
                  final inMonth =
                      day.month == month.month && day.year == month.year;
                  return Semantics(
                    button: true,
                    selected: day == focusDate,
                    label:
                        '${localizations.formatFullDate(DateTime(day.year, day.month, day.day))}, ${events.length} events',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelectDate(day),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: day == focusDate
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${day.day}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: !inMonth
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant
                                              .withValues(alpha: .55)
                                        : day == focusDate
                                        ? Theme.of(context)
                                              .colorScheme
                                              .onPrimary
                                        : null,
                                    fontWeight: day == focusDate
                                        ? FontWeight.w700
                                        : null,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final kind
                                    in ScheduleKind.values
                                        .where(
                                          (kind) => events.any(
                                            (event) => event.item.kind == kind,
                                          ),
                                        )
                                        .take(3))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: switch (kind) {
                                        ScheduleKind.work => palette.work,
                                        ScheduleKind.classSession =>
                                          palette.school,
                                        ScheduleKind.personal =>
                                          palette.personal,
                                        ScheduleKind.deadline =>
                                          palette.deadline,
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        Padding(
          key: const Key('month-workload-summary'),
          padding: const EdgeInsets.fromLTRB(
            StudyShiftSpacing.pageMargin,
            4,
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.x2,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              monthSummary.isEmpty
                  ? 'No events this month yet'
                  : 'This month · ${monthSummary.join(' · ')}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.x3,
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.x2,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              dateLabel,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
        Expanded(
          child: selectedOccurrences.isEmpty
              ? Center(
                  child: Text(
                    'No events on this day',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  itemCount: selectedOccurrences.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final occurrence = selectedOccurrences[index];
                    return ScheduleEventTile(
                      item: occurrence.item,
                      use24Hour: use24Hour,
                      conflict: conflictedIds.contains(occurrence.item.id),
                      onTap: () => onSelectEvent(occurrence),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

List<String> _monthSummary(List<EventOccurrence> occurrences) {
  final summary = <String>[];
  for (final category in WorkCategory.values) {
    final count = occurrences
        .where(
          (entry) =>
              entry.item.kind == ScheduleKind.work &&
              entry.item.workCategory == category,
        )
        .length;
    if (count == 0) continue;
    final label = switch (category) {
      WorkCategory.shift => count == 1 ? 'shift' : 'shifts',
      WorkCategory.training =>
        count == 1 ? 'training session' : 'training sessions',
      WorkCategory.restDay => count == 1 ? 'rest day' : 'rest days',
      WorkCategory.leave => count == 1 ? 'leave day' : 'leave days',
      WorkCategory.dayOff => count == 1 ? 'day off' : 'days off',
      WorkCategory.overtime => count == 1 ? 'overtime duty' : 'overtime duties',
    };
    summary.add('$count $label');
  }
  final classes = occurrences
      .where((entry) => entry.item.kind == ScheduleKind.classSession)
      .length;
  if (classes > 0) {
    summary.add('$classes ${classes == 1 ? 'class' : 'classes'}');
  }
  for (final type in DeadlineType.values) {
    final count = occurrences
        .where(
          (entry) =>
              entry.item.kind == ScheduleKind.deadline &&
              entry.item.deadlineType == type,
        )
        .length;
    if (count == 0) continue;
    final label = switch (type) {
      DeadlineType.assignment => count == 1 ? 'assignment' : 'assignments',
      DeadlineType.examination => count == 1 ? 'exam' : 'exams',
    };
    summary.add('$count $label');
  }
  final plans = occurrences
      .where((entry) => entry.item.kind == ScheduleKind.personal)
      .length;
  if (plans > 0) {
    summary.add('$plans ${plans == 1 ? 'plan' : 'plans'}');
  }
  return summary;
}

class _ScheduleCollectionPage extends ConsumerStatefulWidget {
  const _ScheduleCollectionPage({
    required this.kind,
    required this.emptyTitle,
    required this.emptyDetail,
    this.kinds,
    this.clock,
    this.afterWorkSummary,
  });
  final ScheduleKind kind;
  final Set<ScheduleKind>? kinds;
  final String emptyTitle;
  final String emptyDetail;
  final DateTime Function()? clock;
  final Widget? afterWorkSummary;

  @override
  ConsumerState<_ScheduleCollectionPage> createState() =>
      _ScheduleCollectionPageState();
}

class _ScheduleCollectionPageState
    extends ConsumerState<_ScheduleCollectionPage>
    with WidgetsBindingObserver {
  String? _selectedFilter;
  bool _showAllClasses = false;
  bool _showAllWork = false;
  bool _showAllPastShifts = false;
  Timer? _clockRefresh;

  DateTime _now() => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleClockRefresh();
  }

  void _scheduleClockRefresh() {
    final now = DateTime.now();
    final delay =
        const Duration(minutes: 1) -
        Duration(seconds: now.second, milliseconds: now.millisecond);
    _clockRefresh = Timer(delay, () {
      if (!mounted) return;
      setState(() {});
      _scheduleClockRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    _clockRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Widget _buildEmptyPanel({
    required BuildContext context,
    required WidgetRef ref,
    required bool compact,
    required String? activeFilter,
    required List<EventOccurrence> upcomingDeadlines,
    required List<EventOccurrence> allUpcoming,
  }) {
    var title = upcomingDeadlines.isNotEmpty
        ? 'No classes this week'
        : allUpcoming.isEmpty
        ? widget.emptyTitle
        : 'Nothing in this filter';
    var detail = upcomingDeadlines.isNotEmpty
        ? 'Your assignments and exams are listed below.'
        : allUpcoming.isEmpty
        ? widget.emptyDetail
        : 'Choose another filter to see more of your schedule.';
    String? actionLabel;
    ScheduleKind? addKind;
    DeadlineType? deadlineType;

    if (widget.kind == ScheduleKind.work && activeFilter != null) {
      final workEmptyState = switch (activeFilter) {
        'Shifts' => (
          'No upcoming shifts',
          'Your next work shifts will appear here.',
        ),
        'Days Off' => (
          'No days off scheduled',
          'Scheduled rest days and days off will appear here.',
        ),
        'Overtime' => (
          'No overtime entries yet',
          'Overtime entries appear here when you record extra hours.',
        ),
        'Leave' => (
          'No leave scheduled',
          'Your upcoming leave will appear here.',
        ),
        'Training' => (
          'No training scheduled',
          'Your upcoming training sessions will appear here.',
        ),
        _ => null,
      };
      if (workEmptyState != null) {
        title = workEmptyState.$1;
        detail = workEmptyState.$2;
      }
    }

    if (widget.kind == ScheduleKind.classSession) {
      switch (activeFilter) {
        case 'Classes':
          if (upcomingDeadlines.isEmpty) {
            title = 'No upcoming classes';
            detail = 'Add your classes to build your weekly timetable.';
            actionLabel = 'Add class';
            addKind = ScheduleKind.classSession;
          }
          break;
        case 'Assignments':
          title = 'No upcoming assignments';
          detail = "You're all caught up. Add an assignment when you have something due.";
          actionLabel = 'Add assignment';
          addKind = ScheduleKind.deadline;
          deadlineType = DeadlineType.assignment;
          break;
        case 'Exams':
          title = 'No upcoming exams';
          detail = 'Keep exam dates here so you can plan ahead.';
          actionLabel = 'Add exam';
          addKind = ScheduleKind.deadline;
          deadlineType = DeadlineType.examination;
          break;
      }
    }

    return _EmptyPanel(
      compact: compact,
      icon: scheduleKindIcon(widget.kind),
      title: title,
      detail: detail,
      actionLabel: actionLabel,
      onAction: addKind == null
          ? null
          : () => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => EventEditorPage(
                  kind: addKind!,
                  initialDeadlineType: deadlineType,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(scheduleItemsProvider);
    final preferences = ref.watch(appPreferencesProvider).value;
    return items.when(
      loading: () => const _PageLoading(),
      error: (error, _) => _PageError(
        message: error.toString(),
        onRetry: () => ref.invalidate(scheduleItemsProvider),
      ),
      data: (allItems) {
        final overtimeAdjustments =
            ref.watch(workOvertimeAdjustmentsProvider).asData?.value ??
            const <WorkOvertimeAdjustment>[];
        final overtimeByOccurrence = {
          for (final adjustment in overtimeAdjustments)
            '${adjustment.shiftItemId}|${adjustment.occurrenceDate}':
                adjustment.minutes,
        };
        int overtimeFor(EventOccurrence occurrence) =>
            overtimeByOccurrence['${occurrence.item.id}|${occurrence.date}'] ??
            0;
        bool hasOvertime(EventOccurrence occurrence) =>
            occurrence.item.workCategory == WorkCategory.overtime ||
            (occurrence.item.workCategory == WorkCategory.shift &&
                overtimeFor(occurrence) > 0);
        final queries = ref.read(scheduleQueriesProvider);
        String? overtimeHoursLabel(EventOccurrence occurrence) {
          if (_selectedFilter != 'Overtime' ||
              occurrence.item.workCategory != WorkCategory.shift) {
            return null;
          }
          final employer =
              preferences?.overtimeEmployerFor(
                employer: occurrence.item.employerName,
                title: occurrence.item.title,
              ) ??
              occurrence.item.employerName?.trim();
          final sameDayRows = queries.forRange(
            allItems,
            occurrence.date,
            occurrence.date,
          );
          final dailyShifts = sameDayRows
              .where((entry) {
                if (entry.date != occurrence.date ||
                    entry.item.kind != ScheduleKind.work ||
                    entry.item.workCategory != WorkCategory.shift) {
                  return false;
                }
                if (employer == null || employer.isEmpty) {
                  return entry.item.id == occurrence.item.id;
                }
                final rowEmployer =
                    preferences?.overtimeEmployerFor(
                      employer: entry.item.employerName,
                      title: entry.item.title,
                    ) ??
                    entry.item.employerName?.trim();
                return rowEmployer?.toLowerCase() == employer.toLowerCase();
              })
              .toList(growable: false);
          final extraMinutes = dailyShifts.fold<int>(
            0,
            (total, entry) => total + overtimeFor(entry),
          );
          if (extraMinutes <= 0) return null;
          final rosteredMinutes = dailyShifts.fold<int>(
            0,
            (total, entry) =>
                total +
                WorkHoursSummary.sumIntervalMinutes(entry.item.intervals),
          );
          final threshold = preferences?.overtimeThresholdForEmployer(employer);
          final summary = WorkHoursSummary.fromMinutes(
            scheduledMinutes: rosteredMinutes,
            overtimeMinutes: extraMinutes,
            standardDayMinutes: threshold,
          );
          final totals =
              'Rostered: ${_hoursLabel(rosteredMinutes)} · '
              'Extra logged: ${_hoursLabel(extraMinutes)} · '
              'Total: ${_hoursLabel(summary.totalMinutes)}';
          if (threshold == null) return totals;
          return '$totals · Top-up to standard: '
              '${_hoursLabel(summary.standardRateTopUpMinutes)}'
              ' · Above threshold: '
              '${_hoursLabel(summary.premiumEligibleMinutes)}';
        }

        final now = _now();
        final today = CivilDate.fromDateTime(now);
        final through = today.addDays(90);
        final weekStart = today.addDays(1 - today.weekday);
        final weekThrough = weekStart.addDays(6);
        final showOvertimeByOccurrence =
            widget.kind == ScheduleKind.work && _selectedFilter == 'Overtime';
        final occurrences = queries
            .forRange(allItems, today, through)
            .where(
              (entry) =>
                  (widget.kinds ?? {widget.kind}).contains(entry.item.kind),
            )
            .toList();
        final seen = <String>{};
        final allUpcoming = occurrences
            .where((entry) {
              if (entry.item.hasNoTime) return true;
              final resolution = queries.resolveOccurrence(entry);
              if (resolution.issues.isNotEmpty ||
                  resolution.intervals.isEmpty) {
                return true;
              }
              return resolution.intervals.any(
                (interval) => interval.end.isAfter(now),
              );
            })
            .where(
              (entry) => seen.add(
                showOvertimeByOccurrence
                    ? '${entry.item.id}|${entry.date}'
                    : entry.item.id,
              ),
            )
            .toList();
        final workFilters = const [
          'Shifts',
          'Days Off',
          'Overtime',
          'Leave',
          'Training',
        ];
        final studyFilters = const ['Classes', 'Assignments', 'Exams'];
        final filters = widget.kind == ScheduleKind.work
            ? workFilters
            : widget.kind == ScheduleKind.classSession
            ? studyFilters
            : const <String>[];
        final activeFilter =
            _selectedFilter != null && filters.contains(_selectedFilter)
            ? _selectedFilter!
            : filters.isNotEmpty
            ? filters.first
            : null;
        final activeDuties = widget.kind == ScheduleKind.work
            ? queries.currentlyHappeningEntries(allItems, now)
            : const <UpcomingScheduleEntry>[];
        final visibleActiveDuties = activeDuties.where((entry) {
          if (activeFilter == null) return true;
          return switch (activeFilter) {
            'Shifts' =>
              entry.occurrence.item.workCategory == WorkCategory.shift,
            'Overtime' => hasOvertime(entry.occurrence),
            'Training' =>
              entry.occurrence.item.workCategory == WorkCategory.training,
            _ => false,
          };
        }).toList();
        final visibleActiveDutyIds = visibleActiveDuties
            .map((entry) => entry.occurrence.item.id)
            .toSet();
        final visibleActiveDutyOccurrences = visibleActiveDuties
            .map(
              (entry) => '${entry.occurrence.item.id}|${entry.occurrence.date}',
            )
            .toSet();
        final upcoming = allUpcoming.where((entry) {
          if (showOvertimeByOccurrence) {
            if (visibleActiveDutyOccurrences.contains(
              '${entry.item.id}|${entry.date}',
            )) {
              return false;
            }
          } else if (visibleActiveDutyIds.contains(entry.item.id)) {
            return false;
          }
          if (activeFilter == null) return true;
          if (widget.kind == ScheduleKind.work) {
            return switch (activeFilter) {
              'Shifts' => entry.item.workCategory == WorkCategory.shift,
              'Days Off' =>
                entry.item.workCategory == WorkCategory.dayOff ||
                    entry.item.workCategory == WorkCategory.restDay,
              'Overtime' => hasOvertime(entry),
              'Leave' => entry.item.workCategory == WorkCategory.leave,
              'Training' => entry.item.workCategory == WorkCategory.training,
              _ => true,
            };
          }
          return switch (activeFilter) {
            'Classes' =>
              entry.item.kind == ScheduleKind.classSession &&
                  (_showAllClasses || entry.date.compareTo(weekThrough) <= 0),
            'Assignments' =>
              entry.item.kind == ScheduleKind.deadline &&
                  entry.item.deadlineType == DeadlineType.assignment,
            'Exams' =>
              entry.item.kind == ScheduleKind.deadline &&
                  entry.item.deadlineType == DeadlineType.examination,
            _ => true,
          };
        }).toList();
        final upcomingDeadlines =
            widget.kind == ScheduleKind.classSession &&
                activeFilter == 'Classes'
            ? allUpcoming
                  .where((entry) => entry.item.kind == ScheduleKind.deadline)
                  .toList()
            : const <EventOccurrence>[];
        final visibleUpcoming =
            widget.kind == ScheduleKind.work &&
                !_showAllWork &&
                upcoming.length > 3
            ? upcoming.take(3).toList()
            : upcoming;
        final shiftItems = allItems
            .where(
              (item) =>
                  item.kind == ScheduleKind.work &&
                  (item.workCategory == WorkCategory.shift ||
                      item.workCategory == WorkCategory.overtime),
            )
            .toList();
        final firstShiftDate = shiftItems.isEmpty
            ? null
            : shiftItems
                  .map((item) => item.startDate)
                  .reduce(
                    (first, next) => first.compareTo(next) <= 0 ? first : next,
                  );
        final recentPastStart = today.addDays(-30);
        final historyStart = _showAllPastShifts || firstShiftDate == null
            ? firstShiftDate ?? today
            : firstShiftDate.compareTo(recentPastStart) > 0
            ? firstShiftDate
            : recentPastStart;
        final activeOccurrenceKeys = queries
            .currentlyHappeningEntries(allItems, now)
            .map(
              (entry) => '${entry.occurrence.item.id}|${entry.occurrence.date}',
            )
            .toSet();
        bool matchesPastFilter(EventOccurrence occurrence) =>
            switch (activeFilter) {
              'Shifts' => occurrence.item.workCategory == WorkCategory.shift,
              'Overtime' => hasOvertime(occurrence),
              _ => false,
            };
        bool hasEnded(EventOccurrence occurrence) {
          // This section records roster dates before today. A shift that ended
          // earlier today remains in today's schedule unless its overtime was
          // explicitly logged, in which case it belongs in overtime history.
          if (occurrence.date.compareTo(today) < 0) return true;
          if (occurrence.date != today ||
              activeFilter != 'Overtime' ||
              !hasOvertime(occurrence)) {
            return false;
          }
          final occurrenceKey = '${occurrence.item.id}|${occurrence.date}';
          if (activeOccurrenceKeys.contains(occurrenceKey)) return false;
          final resolution = queries.resolveOccurrence(occurrence);
          return resolution.issues.isEmpty &&
              resolution.intervals.isNotEmpty &&
              resolution.intervals.every(
                (interval) => !interval.end.isAfter(now),
              );
        }

        final pastShifts =
            widget.kind != ScheduleKind.work ||
                firstShiftDate == null ||
                historyStart.compareTo(today) > 0
            ? <EventOccurrence>[]
            : queries
                  .forRange(allItems, historyStart, today)
                  .where(
                    (entry) =>
                        entry.item.kind == ScheduleKind.work &&
                        matchesPastFilter(entry) &&
                        hasEnded(entry) &&
                        !activeOccurrenceKeys.contains(
                          '${entry.item.id}|${entry.date}',
                        ),
                  )
                  .toList();
        pastShifts.sort((left, right) {
          final dateOrder = right.date.compareTo(left.date);
          if (dateOrder != 0) return dateOrder;
          final leftStart = left.item.intervals.first.startEpochMinute;
          final rightStart = right.item.intervals.first.startEpochMinute;
          return rightStart.compareTo(leftStart);
        });
        final hasOlderPastShifts =
            firstShiftDate != null &&
            firstShiftDate.compareTo(recentPastStart) < 0;
        final issues = queries
            .analyzeRange(allItems, today, through)
            .timeIssues
            .map((issue) => issue.occurrence.item.id)
            .toSet();
        final conflicts = <String>{
          for (final conflict in queries.conflictsForRange(
            allItems,
            today,
            through,
          )) ...[conflict.first.item.id, conflict.second.item.id],
        };
        final use24 = preferenceUses24Hour(preferences, context);
        final localizations = MaterialLocalizations.of(context);
        final compactLayout = MediaQuery.sizeOf(context).height < 500;
        final monthStart = CivilDate(now.year, now.month, 1);
        final monthThrough = today.addDays(-1);
        final monthItems = monthThrough.compareTo(monthStart) < 0
            ? <EventOccurrence>[]
            : queries
                  .forRange(allItems, monthStart, monthThrough)
                  .where((entry) => entry.item.kind == ScheduleKind.work)
                  .toList();
        var scheduledMinutes = 0;
        var overtimeMinutes = 0;
        var premiumEligibleMinutes = 0;
        var standardRateTopUpMinutes = 0;
        var shiftCount = 0;
        var trainingCount = 0;
        var trainingMinutes = 0;
        final countedShiftOccurrences = <String>{};
        final dailyShiftMinutes = <String, List<int>>{};
        final dailyEmployerNames = <String, String>{};
        String overtimeEmployerFor(EventOccurrence entry) =>
            preferences?.overtimeEmployerFor(
              employer: entry.item.employerName,
              title: entry.item.title,
            ) ??
            (entry.item.employerName?.trim() ?? '');
        String dailyEmployerKey(EventOccurrence entry) {
          final employer = overtimeEmployerFor(entry);
          final normalizedEmployer = employer.toLowerCase().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
          return '${entry.date}|$normalizedEmployer';
        }

        final daysWithLoggedOvertime = {
          for (final entry in monthItems)
            if (entry.item.workCategory == WorkCategory.shift &&
                overtimeFor(entry) > 0)
              dailyEmployerKey(entry),
        };
        for (final entry in monthItems) {
          final category = entry.item.workCategory;
          if (category == WorkCategory.shift) {
            final employer = overtimeEmployerFor(entry);
            final normalizedEmployer = employer.toLowerCase().replaceAll(
              RegExp(r'\s+'),
              ' ',
            );
            final code = entry.item.code?.trim().toUpperCase() ?? '';
            final occurrenceKey = code.isEmpty
                ? '${entry.date}|$normalizedEmployer|${entry.item.id}'
                : '${entry.date}|$normalizedEmployer|$code';
            if (countedShiftOccurrences.add(occurrenceKey)) shiftCount++;
            final loggedOvertime = overtimeFor(entry);
            final dailyKey = dailyEmployerKey(entry);
            final intervals = daysWithLoggedOvertime.contains(dailyKey)
                ? entry.item.intervals
                : entry.item.actualIntervals ?? entry.item.intervals;
            final baseMinutes = WorkHoursSummary.sumIntervalMinutes(intervals);
            scheduledMinutes += baseMinutes;
            overtimeMinutes += loggedOvertime;
            final dailyMinutes = dailyShiftMinutes.putIfAbsent(
              dailyKey,
              () => [0, 0],
            );
            dailyMinutes[0] += baseMinutes;
            dailyMinutes[1] += loggedOvertime;
            dailyEmployerNames[dailyKey] = employer;
          } else if (category == WorkCategory.overtime) {
            overtimeMinutes += WorkHoursSummary.sumIntervalMinutes(
              entry.item.actualIntervals ?? entry.item.intervals,
            );
          } else if (category == WorkCategory.training) {
            trainingCount++;
            trainingMinutes += WorkHoursSummary.sumIntervalMinutes(
              entry.item.intervals,
            );
          }
        }
        for (final entry in dailyShiftMinutes.entries) {
          final employer = dailyEmployerNames[entry.key] ?? '';
          final dailySummary = WorkHoursSummary.fromMinutes(
            scheduledMinutes: entry.value[0],
            overtimeMinutes: entry.value[1],
            standardDayMinutes: preferences?.overtimeThresholdForEmployer(
              employer,
            ),
          );
          premiumEligibleMinutes += dailySummary.premiumEligibleMinutes;
          standardRateTopUpMinutes += dailySummary.standardRateTopUpMinutes;
        }
        final totalWorkMinutes = scheduledMinutes + overtimeMinutes;
        final monthTitle = localizations.formatMonthYear(now);
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            StudyShiftSpacing.pageMargin,
            StudyShiftSpacing.x3,
            StudyShiftSpacing.pageMargin,
            112,
          ),
          children: [
            if (widget.kind == ScheduleKind.work) ...[
              Text(
                'Work overview · $monthTitle',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _WorkSummary(
                      label: 'Hours + extra',
                      value: (totalWorkMinutes / 60).toStringAsFixed(
                        totalWorkMinutes % 60 == 0 ? 0 : 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WorkSummary(label: 'Shifts', value: '$shiftCount'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _WorkSummary(
                      label: 'Training',
                      value: _hoursLabel(trainingMinutes),
                      detail:
                          '$trainingCount '
                          '${trainingCount == 1 ? 'session' : 'sessions'}',
                    ),
                  ),
                ],
              ),
              if (activeFilter == 'Overtime' &&
                  (standardRateTopUpMinutes > 0 ||
                      premiumEligibleMinutes > 0)) ...[
                const SizedBox(height: 8),
                Text(
                  'Top-up to standard: ${_hoursLabel(standardRateTopUpMinutes)}'
                  ' · Above threshold: ${_hoursLabel(premiumEligibleMinutes)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
            if (widget.kind == ScheduleKind.work &&
                widget.afterWorkSummary != null) ...[
              widget.afterWorkSummary!,
              const SizedBox(height: 20),
            ],
            if (filters.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (var index = 0; index < filters.length; index++) ...[
                      if (index > 0)
                        const SizedBox(width: StudyShiftSpacing.x2),
                      ChoiceChip(
                        label: Text(filters[index]),
                        selected: activeFilter == filters[index],
                        selectedColor: Theme.of(context).colorScheme.primary,
                        labelStyle: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(
                              color: activeFilter == filters[index]
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                            ),
                        onSelected: (_) => setState(() {
                          _selectedFilter = filters[index];
                          _showAllWork = false;
                          _showAllPastShifts = false;
                        }),
                        showCheckmark: false,
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.kind == ScheduleKind.work) ...[
                const SizedBox(height: 8),
                Text(
                  'Shifts and overtime are timed duties.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 16),
            ],
            if (visibleActiveDuties.isNotEmpty) ...[
              Text(
                'Happening now',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < visibleActiveDuties.length;
                index++
              ) ...[
                ScheduleEventTile(
                  item: visibleActiveDuties[index].occurrence.item,
                  use24Hour: use24,
                  showExtendedWorkDetails: widget.kind != ScheduleKind.work,
                  statusLabel: 'HAPPENING NOW',
                  workHoursLabel: overtimeHoursLabel(
                    visibleActiveDuties[index].occurrence,
                  ),
                  conflict: conflicts.contains(
                    visibleActiveDuties[index].occurrence.item.id,
                  ),
                  reviewTime: issues.contains(
                    visibleActiveDuties[index].occurrence.item.id,
                  ),
                  dateLabel: localizations.formatMediumDate(
                    DateTime(
                      visibleActiveDuties[index].occurrence.date.year,
                      visibleActiveDuties[index].occurrence.date.month,
                      visibleActiveDuties[index].occurrence.date.day,
                    ),
                  ),
                  onTap: () => showScheduleDetails(
                    context,
                    ref,
                    visibleActiveDuties[index].occurrence.item,
                    occurrenceDate: visibleActiveDuties[index].occurrence.date,
                  ),
                ),
                if (index < visibleActiveDuties.length - 1)
                  const SizedBox(height: 10),
              ],
              const SizedBox(height: 20),
            ],
            if (widget.kind == ScheduleKind.work) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activeFilter == 'Days Off'
                          ? 'Upcoming days off'
                          : activeFilter == null
                          ? 'Upcoming shifts'
                          : 'Upcoming ${activeFilter.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (upcoming.length > 3)
                    TextButton(
                      onPressed: () => setState(() {
                        _showAllWork = !_showAllWork;
                      }),
                      child: Text(_showAllWork ? 'Show less' : 'See all'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (widget.kind != ScheduleKind.work) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activeFilter == null
                          ? 'Upcoming'
                          : activeFilter == 'Days Off'
                          ? 'Upcoming days off'
                          : activeFilter == 'Classes'
                          ? _showAllClasses
                                ? 'Upcoming classes'
                                : 'This week’s classes'
                          : 'Upcoming ${activeFilter.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (widget.kind == ScheduleKind.classSession &&
                      activeFilter == 'Classes' &&
                      upcoming.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showAllClasses = !_showAllClasses),
                      child: Text(_showAllClasses ? 'This week' : 'See all'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            if (upcoming.isEmpty &&
                visibleActiveDuties.isEmpty &&
                activeFilter == 'Overtime' &&
                pastShifts.isNotEmpty) ...[
              _EmptyPanel(
                compact: compactLayout,
                icon: Icons.more_time_rounded,
                title: 'No upcoming overtime',
                detail: 'Logged overtime from completed shifts is below.',
              ),
            ] else if (upcoming.isEmpty && visibleActiveDuties.isEmpty)
              _buildEmptyPanel(
                context: context,
                ref: ref,
                compact: compactLayout,
                activeFilter: activeFilter,
                upcomingDeadlines: upcomingDeadlines,
                allUpcoming: allUpcoming,
              )
            else
              for (var index = 0; index < visibleUpcoming.length; index++) ...[
                ScheduleEventTile(
                  item: visibleUpcoming[index].item,
                  use24Hour: use24,
                  showExtendedWorkDetails: widget.kind != ScheduleKind.work,
                  workHoursLabel: overtimeHoursLabel(visibleUpcoming[index]),
                  staggerIndex: index,
                  countdownLabel: deadlineCountdownLabel(
                    visibleUpcoming[index].item,
                    today,
                  ),
                  conflict: conflicts.contains(visibleUpcoming[index].item.id),
                  reviewTime: issues.contains(visibleUpcoming[index].item.id),
                  dateLabel: localizations.formatMediumDate(
                    DateTime(
                      visibleUpcoming[index].date.year,
                      visibleUpcoming[index].date.month,
                      visibleUpcoming[index].date.day,
                    ),
                  ),
                  onTap: () => showScheduleDetails(
                    context,
                    ref,
                    visibleUpcoming[index].item,
                    occurrenceDate: visibleUpcoming[index].date,
                  ),
                ),
                if (index < visibleUpcoming.length - 1)
                  const SizedBox(height: 10),
              ],
            if (widget.kind == ScheduleKind.work &&
                activeFilter == 'Overtime' &&
                pastShifts.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Past overtime',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < pastShifts.length; index++) ...[
                ScheduleEventTile(
                  item: pastShifts[index].item,
                  use24Hour: use24,
                  showExtendedWorkDetails: false,
                  workHoursLabel: overtimeHoursLabel(pastShifts[index]),
                  conflict: conflicts.contains(pastShifts[index].item.id),
                  reviewTime: issues.contains(pastShifts[index].item.id),
                  dateLabel: localizations.formatMediumDate(
                    DateTime(
                      pastShifts[index].date.year,
                      pastShifts[index].date.month,
                      pastShifts[index].date.day,
                    ),
                  ),
                  onTap: () => showScheduleDetails(
                    context,
                    ref,
                    pastShifts[index].item,
                    occurrenceDate: pastShifts[index].date,
                  ),
                ),
                if (index < pastShifts.length - 1) const SizedBox(height: 10),
              ],
            ],
            if (widget.kind == ScheduleKind.work &&
                pastShifts.isNotEmpty &&
                activeFilter != 'Overtime') ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      activeFilter == 'Overtime'
                          ? 'Past overtime'
                          : 'Past shifts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  if (hasOlderPastShifts)
                    TextButton(
                      onPressed: () => setState(
                        () => _showAllPastShifts = !_showAllPastShifts,
                      ),
                      child: Text(
                        _showAllPastShifts
                            ? 'Show recent shifts'
                            : 'Show all past shifts',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                activeFilter == 'Overtime'
                    ? 'Logged extra hours are shown separately from rostered shift times.'
                    : 'Dates alone do not mark a shift as completed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < pastShifts.length; index++) ...[
                ScheduleEventTile(
                  item: pastShifts[index].item,
                  use24Hour: use24,
                  showExtendedWorkDetails: false,
                  workHoursLabel: overtimeHoursLabel(pastShifts[index]),
                  conflict: conflicts.contains(pastShifts[index].item.id),
                  reviewTime: issues.contains(pastShifts[index].item.id),
                  dateLabel: localizations.formatMediumDate(
                    DateTime(
                      pastShifts[index].date.year,
                      pastShifts[index].date.month,
                      pastShifts[index].date.day,
                    ),
                  ),
                  onTap: () => showScheduleDetails(
                    context,
                    ref,
                    pastShifts[index].item,
                    occurrenceDate: pastShifts[index].date,
                  ),
                ),
                if (index < pastShifts.length - 1) const SizedBox(height: 10),
              ],
            ],
            if (upcomingDeadlines.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Deadlines',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              for (
                var index = 0;
                index < upcomingDeadlines.length;
                index++
              ) ...[
                ScheduleEventTile(
                  item: upcomingDeadlines[index].item,
                  use24Hour: use24,
                  staggerIndex: index,
                  countdownLabel: deadlineCountdownLabel(
                    upcomingDeadlines[index].item,
                    today,
                  ),
                  conflict: conflicts.contains(
                    upcomingDeadlines[index].item.id,
                  ),
                  reviewTime: issues.contains(upcomingDeadlines[index].item.id),
                  dateLabel: localizations.formatMediumDate(
                    DateTime(
                      upcomingDeadlines[index].date.year,
                      upcomingDeadlines[index].date.month,
                      upcomingDeadlines[index].date.day,
                    ),
                  ),
                  onTap: () => showScheduleDetails(
                    context,
                    ref,
                    upcomingDeadlines[index].item,
                    occurrenceDate: upcomingDeadlines[index].date,
                  ),
                ),
                if (index < upcomingDeadlines.length - 1)
                  const SizedBox(height: 10),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _WorkSummary extends StatelessWidget {
  const _WorkSummary({required this.label, required this.value, this.detail});

  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 100,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (detail != null) ...[
              const SizedBox(height: 2),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class WorkPage extends StatelessWidget {
  const WorkPage({super.key, this.clock});
  final DateTime Function()? clock;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(
        child: _ScheduleCollectionPage(
          kind: ScheduleKind.work,
          emptyTitle: 'Your work roster starts here',
          emptyDetail: 'Add a shift, training, rest day, leave or day off.',
          clock: clock,
          afterWorkSummary: Card(
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Shift legend'),
              subtitle: const Text('Time windows, flights and assignments'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const WorkCodeLegendPage(),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

class StudyPage extends StatelessWidget {
  const StudyPage({super.key});
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Card(
          child: ListTile(
            leading: const Icon(Icons.school_outlined),
            title: const Text('Academic terms'),
            subtitle: const Text('Institutions and semester dates'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const AcademicTermsPage(),
              ),
            ),
          ),
        ),
      ),
      const Expanded(
        child: _ScheduleCollectionPage(
          kind: ScheduleKind.classSession,
          kinds: {ScheduleKind.classSession, ScheduleKind.deadline},
          emptyTitle: 'Your timetable starts here',
          emptyDetail: 'Add a class, assignment or examination.',
        ),
      ),
    ],
  );
}

class PlansPage extends StatelessWidget {
  const PlansPage({super.key});
  @override
  Widget build(BuildContext context) => const _ScheduleCollectionPage(
    kind: ScheduleKind.personal,
    emptyTitle: 'Make room for your plans',
    emptyDetail:
        'Add appointments and the personal events you want to remember.',
  );
}

class _NextEventPanel extends StatelessWidget {
  const _NextEventPanel({
    required this.item,
    required this.time,
    required this.endTime,
    required this.countdown,
    required this.isInProgress,
    required this.dateLabel,
    required this.onTap,
    this.compact = false,
  });
  final ScheduleItem item;
  final String time;
  final String endTime;
  final String countdown;
  final bool isInProgress;
  final String? dateLabel;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    const foreground = Colors.white;
    final palette = _todayFeaturePalette(context);
    return Card(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [palette.featuredStart, palette.featuredEnd],
            ),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: compact ? 84 : 112),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _FeaturedCardWavePainter(
                        color: palette.featuredWave,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(compact ? 12 : 16),
                  child: Row(
                    children: [
                      IconTheme(
                        data: const IconThemeData(color: foreground),
                        child: ShiftIcon(
                          scheduleKindIconAsset(item.kind),
                          size: compact ? 20 : 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${isInProgress ? 'Happening now' : 'Next up'}${dateLabel == null || isInProgress ? '' : ' · $dateLabel'}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge
                                        ?.copyWith(color: foreground),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  countdown,
                                  style: Theme.of(context).textTheme.labelLarge
                                      ?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (compact
                                          ? Theme.of(context)
                                                .textTheme
                                                .titleSmall
                                          : Theme.of(context)
                                                .textTheme
                                                .titleMedium)
                                      ?.copyWith(
                                        color: foreground,
                                        fontWeight: FontWeight.w700,
                                      ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$time – $endTime${item.location?.trim().isNotEmpty == true ? ' · ${item.location!.trim()}' : ''}',
                              maxLines: compact ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  (compact
                                          ? Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                          : Theme.of(context)
                                                .textTheme
                                                .bodyMedium)
                                      ?.copyWith(
                                        color: foreground.withValues(alpha: .9),
                                      ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: foreground,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NextEventEmptyPanel extends StatelessWidget {
  const _NextEventEmptyPanel({this.compact = false, this.hasEvents = false});

  final bool compact;
  final bool hasEvents;

  @override
  Widget build(BuildContext context) {
    const foreground = Colors.white;
    final palette = _todayFeaturePalette(context);
    return Card(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [palette.featuredStart, palette.featuredEnd],
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 84 : 112),
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _FeaturedCardWavePainter(
                      color: palette.featuredWave,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(compact ? 12 : 16),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      color: foreground,
                      size: compact ? 20 : 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Next up',
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: foreground),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasEvents
                                ? 'Nothing else scheduled today'
                                : 'Nothing scheduled yet',
                            style:
                                (compact
                                        ? Theme.of(context).textTheme.titleSmall
                                        : Theme.of(context)
                                              .textTheme
                                              .titleMedium)
                                    ?.copyWith(
                                      color: foreground,
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            hasEvents
                                ? 'Your events for today are listed below.'
                                : 'Your next shift, class or plan will show here.',
                            maxLines: compact ? 1 : null,
                            overflow: compact ? TextOverflow.ellipsis : null,
                            style:
                                (compact
                                        ? Theme.of(context).textTheme.bodySmall
                                        : Theme.of(context)
                                              .textTheme
                                              .bodyMedium)
                                    ?.copyWith(
                                      color: foreground.withValues(alpha: .9),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturedCardWavePainter extends CustomPainter {
  const _FeaturedCardWavePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rear = Path()
      ..moveTo(size.width * .55, size.height * .91)
      ..cubicTo(
        size.width * .72,
        size.height * .70,
        size.width * .82,
        size.height * 1.08,
        size.width,
        size.height * .76,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(size.width * .55, size.height)
      ..close();
    canvas.drawPath(rear, Paint()..color = color.withValues(alpha: .34));

    final front = Path()
      ..moveTo(size.width * .76, size.height)
      ..cubicTo(
        size.width * .86,
        size.height * .79,
        size.width * .93,
        size.height * 1.05,
        size.width,
        size.height * .88,
      )
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(front, Paint()..color = color.withValues(alpha: .62));
  }

  @override
  bool shouldRepaint(covariant _FeaturedCardWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _ConflictSummaryPanel extends StatelessWidget {
  const _ConflictSummaryPanel({
    required this.conflicts,
    required this.onSelect,
  });

  final List<ScheduleConflict> conflicts;
  final ValueChanged<EventOccurrence> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const PageStorageKey<String>('today-conflict-summary'),
        leading: Icon(
          Icons.warning_amber_rounded,
          color: theme.colorScheme.onErrorContainer,
        ),
        title: Text(
          '${conflicts.length} schedule conflict${conflicts.length == 1 ? '' : 's'}',
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          'Some events overlap. Review conflicts →',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final conflict in conflicts)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${conflict.first.item.title} overlaps with ${conflict.second.item.title}.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => onSelect(conflict.first),
                        child: Text('Open ${conflict.first.item.title}'),
                      ),
                      TextButton(
                        onPressed: () => onSelect(conflict.second),
                        child: Text('Open ${conflict.second.item.title}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeReviewPanel extends StatelessWidget {
  const _TimeReviewPanel({required this.issues, required this.onSelect});
  final List<ScheduleTimeIssue> issues;
  final ValueChanged<EventOccurrence> onSelect;

  @override
  Widget build(BuildContext context) {
    final uniqueOccurrences = <String, EventOccurrence>{};
    for (final issue in issues) {
      final occurrence = issue.occurrence;
      uniqueOccurrences['${occurrence.item.id}-${occurrence.date}'] =
          occurrence;
    }
    final occurrences = uniqueOccurrences.values.toList();
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  color: Theme.of(context).colorScheme.onTertiaryContainer,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${occurrences.length} ${occurrences.length == 1 ? 'event time needs' : 'event times need'} review. Open an event for time-zone and daylight-saving details.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            for (final occurrence in occurrences)
              TextButton.icon(
                onPressed: () => onSelect(occurrence),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  '${occurrence.item.title} · ${MaterialLocalizations.of(context).formatShortDate(DateTime(occurrence.date.year, occurrence.date.month, occurrence.date.day))}',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.detail,
    this.compact = false,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String detail;
  final bool compact;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (compact ||
          (constraints.maxHeight.isFinite && constraints.maxHeight < 230)) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (actionLabel != null && onAction != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
                ),
            ],
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 18),
        child: Column(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      );
    },
  );
}

class _AvailablePeriodsPanel extends StatelessWidget {
  const _AvailablePeriodsPanel({
    required this.periods,
    required this.use24Hour,
  });

  final List<AvailablePeriod> periods;
  final bool use24Hour;

  @override
  Widget build(BuildContext context) {
    if (periods.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final shown = periods.take(4).toList(growable: false);
    return Card(
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Text(
                  'Available periods',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final period in shown)
                  Chip(
                    avatar: const Icon(Icons.schedule_rounded, size: 16),
                    label: Text(
                      '${formatMinute(period.start.hour * 60 + period.start.minute, use24Hour: use24Hour)} – ${period.end.hour == 0 && period.end.minute == 0 ? 'midnight' : formatMinute(period.end.hour * 60 + period.end.minute, use24Hour: use24Hour)}',
                    ),
                  ),
                if (periods.length > shown.length)
                  Chip(label: Text('+${periods.length - shown.length} more')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PageLoading extends StatelessWidget {
  const _PageLoading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _PageError extends StatelessWidget {
  const _PageError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 36),
          const SizedBox(height: 12),
          Text(
            'Couldn’t load saved events',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          const Text('Your local data has not been changed. Try again.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'),
          ),
          if (!const bool.fromEnvironment('dart.vm.product'))
            Text(message, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

CivilDate _mondayOf(CivilDate date) => date.addDays(1 - date.weekday);

CivilDate _shiftMonth(CivilDate date, int amount) {
  final shifted = DateTime(date.year, date.month + amount, 1);
  return CivilDate(shifted.year, shifted.month, shifted.day);
}
