import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../application/dependencies.dart';
import '../../data/open_meteo_weather_service.dart';
import '../../data/preferences_repository.dart';
import '../../data/weather_repository.dart';
import '../design/studyshift_spacing.dart';
import '../weather_condition_icon.dart';

class WeatherSettingsPage extends ConsumerStatefulWidget {
  const WeatherSettingsPage({super.key});

  @override
  ConsumerState<WeatherSettingsPage> createState() =>
      _WeatherSettingsPageState();
}

class _WeatherSettingsPageState extends ConsumerState<WeatherSettingsPage> {
  final _searchController = TextEditingController();
  final _pageController = ScrollController();
  final _firstPlaceResultKey = GlobalKey();
  List<WeatherPlace> _places = const [];
  bool _searching = false;
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _searchController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final enabled = preferences?.weatherEnabled == true;
    final locationJson = preferences?.weatherLocationJson;
    final location = _decodeSavedLocation(locationJson);
    final savedPlaces = _savedPlaces(preferences);
    final reading = enabled && location != null
        ? ref.watch(weatherReadingProvider)
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Local weather')),
      body: ListView(
        controller: _pageController,
        padding: const EdgeInsets.all(StudyShiftSpacing.pageMargin),
        children: [
          Text(
            'Your greeting, your way',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how local weather appears on Today. Weather stays optional.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Approximate coordinates are sent only when you choose a place or '
            'refresh weather. StudyShift never uses background location.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show weather on Today'),
            subtitle: const Text('Turn on only the forecast summary you want.'),
            value: enabled,
            onChanged: _saving
                ? null
                : (value) async {
                    await ref
                        .read(preferencesRepositoryProvider)
                        .setWeatherEnabled(value);
                    ref.invalidate(appPreferencesProvider);
                    ref.invalidate(weatherReadingProvider);
                  },
          ),
          if (enabled && reading != null) ...[
            const SizedBox(height: 8),
            reading.when(
              loading: () => const _WeatherPreviewLoading(),
              error: (_, _) => const _WeatherPreviewUnavailable(),
              data: (value) => value == null
                  ? const _WeatherPreviewUnavailable()
                  : _WeatherTodayPreview(
                      reading: value,
                      preferences: preferences!,
                    ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionHeading(context, 'Location'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.my_location_rounded),
                  title: const Text('Use my location'),
                  subtitle: const Text('Approximate location · one time only'),
                  trailing: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator.adaptive(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _saving ? null : _useCurrentLocation,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.search_rounded),
                  title: const Text('Choose a place manually'),
                  subtitle: const Text('Search towns and cities'),
                  trailing: const Icon(Icons.add_rounded),
                  onTap: _saving ? null : _search,
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (savedPlaces.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Saved places',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            RadioGroup<String>(
              groupValue: location == null ? null : _placeKey(location),
              onChanged: (key) {
                if (_saving || key == null) return;
                final selected = savedPlaces.where(
                  (place) => _placeKey(place) == key,
                );
                if (selected.isNotEmpty) {
                  _activatePlace(selected.first);
                }
              },
              child: Column(
                children: [
                  for (final place in savedPlaces)
                    Card(
                      child: RadioListTile<String>(
                        value: _placeKey(place),
                        title: Text(place.name),
                        subtitle: Text(place.label),
                        secondary: IconButton(
                          tooltip: 'Remove ${place.name}',
                          onPressed: _saving
                              ? null
                              : () => _removeSavedPlace(place),
                          icon: const Icon(Icons.remove_circle_outline_rounded),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _saving ? null : _search,
              icon: const Icon(Icons.search_rounded),
              label: const Text('Choose a place'),
            ),
          ],
          if (_searching) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Searching places…'),
          ],
          if (_places.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Choose the matching place',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _places.length; index++)
              Card(
                key: index == 0 ? _firstPlaceResultKey : null,
                child: ListTile(
                  title: Text(_places[index].name),
                  subtitle: Text(_places[index].label),
                  trailing: const Icon(Icons.add_location_alt_outlined),
                  onTap: _saving ? null : () => _selectPlace(_places[index]),
                ),
              ),
          ],
          if (location != null && enabled) ...[
            const SizedBox(height: 12),
            reading!.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, _) => Text(
                'Weather could not be refreshed. Your saved schedule is unaffected.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              data: (value) => value == null
                  ? const SizedBox.shrink()
                  : Text(
                      '${value.snapshot.temperatureC.round()}°C · '
                      '${weatherDescription(value.snapshot.weatherCode)}'
                      '${value.isCached ? ' · saved conditions' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => ref.invalidate(weatherReadingProvider),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Refresh weather'),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _sectionHeading(context, 'Display options'),
          Text(
            'Choose what appears with the greeting. Tap the weather on Today '
            'to open the full forecast details.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                _metricSwitch(
                  'Location & condition',
                  WeatherMetric.locationAndCondition,
                  preferences?.showWeatherLocationAndCondition ?? true,
                ),
                _metricSwitch(
                  'Feels-like temperature',
                  WeatherMetric.feelsLike,
                  preferences?.showWeatherFeelsLike ?? false,
                ),
                _metricSwitch(
                  'Rain chance',
                  WeatherMetric.rainChance,
                  preferences?.showWeatherRainChance ?? true,
                ),
                _metricSwitch(
                  'Wind speed',
                  WeatherMetric.windSpeed,
                  preferences?.showWeatherWindSpeed ?? false,
                ),
                _metricSwitch(
                  'Sunrise & sunset',
                  WeatherMetric.sunriseSunset,
                  preferences?.showWeatherSunriseSunset ?? false,
                ),
                _metricSwitch(
                  'Last updated time',
                  WeatherMetric.lastUpdated,
                  preferences?.showWeatherLastUpdated ?? true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Layout', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<WeatherLayout>(
            segments: const [
              ButtonSegment(
                value: WeatherLayout.compact,
                label: Text('Compact'),
                icon: Icon(Icons.view_agenda_outlined),
              ),
              ButtonSegment(
                value: WeatherLayout.moreDetails,
                label: Text('More details'),
                icon: Icon(Icons.view_agenda_rounded),
              ),
            ],
            selected: {
              preferences?.effectiveWeatherLayout ?? WeatherLayout.compact,
            },
            onSelectionChanged: _saving
                ? null
                : (selection) => _setLayout(selection.single),
          ),
          const SizedBox(height: 24),
          Text(
            'Weather data by Open-Meteo · open-meteo.com · CC BY 4.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            'Forecasts are informational and may be delayed or unavailable. '
            'Do not use them as airport or operational safety guidance.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.location_searching_rounded),
        title: const Text('Choose a town or city'),
        content: TextField(
          controller: _searchController,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Town or city',
            hintText: 'For example, Bridgetown',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _searchController.text.trim()),
            child: const Text('Search'),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;
    if (entered.length < 2) {
      setState(() => _message = 'Enter at least two characters.');
      return;
    }
    setState(() {
      _searching = true;
      _message = null;
      _places = const [];
    });
    try {
      final results = await ref
          .read(openMeteoWeatherServiceProvider)
          .searchPlaces(entered);
      if (!mounted) return;
      setState(() {
        _places = results;
        _message = results.isEmpty ? 'No matching places found.' : null;
      });
      if (results.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final resultContext = _firstPlaceResultKey.currentContext;
          if (resultContext != null && mounted) {
            Scrollable.ensureVisible(
              resultContext,
              alignment: 0.16,
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    } on Object {
      if (!mounted) return;
      setState(
        () => _message = 'Places could not be searched. Try again later.',
      );
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _selectPlace(WeatherPlace place) async {
    await _savePlace(place, activate: true);
    if (mounted) setState(() => _places = const []);
  }

  Future<void> _savePlace(WeatherPlace place, {required bool activate}) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      final current = ref.read(appPreferencesProvider).value;
      final places = _savedPlaces(current);
      final next = [
        for (final saved in places)
          if (_placeKey(saved) != _placeKey(place)) saved,
        place,
      ];
      await repository.setWeatherLocations(
        jsonEncode(next.map(_placeToJson).toList()),
      );
      if (activate) {
        await repository.setWeatherLocation(jsonEncode(_placeToJson(place)));
      }
      await repository.setWeatherEnabled(true);
      ref.invalidate(appPreferencesProvider);
      ref.invalidate(weatherReadingProvider);
      if (mounted) setState(() => _places = const []);
    } on Object {
      if (mounted) {
        setState(() => _message = 'The weather place could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    final use = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.my_location_rounded),
        title: const Text('Use approximate location?'),
        content: const Text(
          'StudyShift requests approximate location once, only when you tap Use. '
          'The coordinates are sent to Open-Meteo to get the forecast. '
          'StudyShift does not track you in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Use location'),
          ),
        ],
      ),
    );
    if (use != true || !mounted) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final place = await ref
          .read(approximateWeatherLocationProvider)
          .currentPlace();
      if (!mounted) return;
      await _savePlace(place, activate: true);
    } on PlatformException catch (error) {
      if (mounted) {
        final message = switch (error.code) {
          'location_permission_denied' =>
            'Approximate location permission was denied. '
                'You can choose a place manually.',
          'location_unavailable' || 'location_timeout' =>
            'The device could not get a location fix. Check Location is on, '
                'or choose a place manually.',
          _ => 'Could not use the device location. Choose a place manually '
              'or try again.',
        };
        setState(() => _message = message);
      }
    } on FormatException {
      if (mounted) {
        setState(
          () => _message =
              'The device returned an invalid location. '
              'You can choose a place manually.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _activatePlace(WeatherPlace place) async {
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.setWeatherLocation(jsonEncode(_placeToJson(place)));
      await repository.setWeatherEnabled(true);
      ref.invalidate(appPreferencesProvider);
      ref.invalidate(weatherReadingProvider);
    } on Object {
      if (mounted) {
        setState(() => _message = 'That place could not be selected.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removeSavedPlace(WeatherPlace place) async {
    setState(() => _saving = true);
    try {
      final preferences = await ref.read(appPreferencesProvider.future);
      final places = _savedPlaces(preferences)
          .where((saved) => _placeKey(saved) != _placeKey(place))
          .toList();
      final repository = ref.read(preferencesRepositoryProvider);
      await repository.setWeatherLocations(
        jsonEncode(places.map(_placeToJson).toList()),
      );
      final active = _decodeSavedLocation(preferences.weatherLocationJson);
      if (active != null && _placeKey(active) == _placeKey(place)) {
        if (places.isEmpty) {
          await repository.clearWeatherLocation();
          await repository.clearWeatherSnapshot();
        } else {
          await repository.setWeatherLocation(
            jsonEncode(_placeToJson(places.first)),
          );
        }
      }
      ref.invalidate(appPreferencesProvider);
      ref.invalidate(weatherReadingProvider);
    } on Object {
      if (mounted) {
        setState(() => _message = 'The saved place could not be removed.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setMetric(WeatherMetric metric, bool value) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(preferencesRepositoryProvider)
          .setWeatherMetric(metric, value);
      ref.invalidate(appPreferencesProvider);
    } on Object {
      if (mounted) {
        setState(() => _message = 'The weather option could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _setLayout(WeatherLayout value) async {
    setState(() => _saving = true);
    try {
      await ref.read(preferencesRepositoryProvider).setWeatherLayout(value);
      ref.invalidate(appPreferencesProvider);
    } on Object {
      if (mounted) {
        setState(() => _message = 'The weather layout could not be saved.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _metricSwitch(String title, WeatherMetric metric, bool value) =>
      SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        title: Text(title),
        value: value,
        onChanged: _saving ? null : (next) => _setMetric(metric, next),
      );

  Widget _sectionHeading(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: Theme.of(context).textTheme.titleMedium),
  );

  List<WeatherPlace> _savedPlaces(AppPreferences? preferences) {
    final raw = preferences?.weatherLocationsJson;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final places = decoded
              .whereType<Map<String, dynamic>>()
              .map(_decodePlaceMap)
              .whereType<WeatherPlace>()
              .toList();
          final active = _decodeSavedLocation(preferences?.weatherLocationJson);
          if (active != null &&
              !places.any((p) => _placeKey(p) == _placeKey(active))) {
            places.insert(0, active);
          }
          return places;
        }
      } on FormatException {
        // A malformed optional place list falls back to the valid active place.
      }
    }
    final legacy = _decodeSavedLocation(preferences?.weatherLocationJson);
    return legacy == null ? const [] : [legacy];
  }

  WeatherPlace? _decodePlaceMap(Map<String, dynamic> value) {
    if (value['name'] is! String ||
        value['label'] is! String ||
        value['latitude'] is! num ||
        value['longitude'] is! num) {
      return null;
    }
    return WeatherPlace(
      name: value['name'] as String,
      label: value['label'] as String,
      latitude: (value['latitude'] as num).toDouble(),
      longitude: (value['longitude'] as num).toDouble(),
    );
  }

  Map<String, Object> _placeToJson(WeatherPlace place) => {
    'name': place.name,
    'label': place.label,
    'latitude': place.latitude,
    'longitude': place.longitude,
  };

  String _placeKey(WeatherPlace place) =>
      '${place.latitude.toStringAsFixed(4)},${place.longitude.toStringAsFixed(4)}';

  WeatherPlace? _decodeSavedLocation(String? json) {
    if (json == null) return null;
    try {
      final value = jsonDecode(json);
      if (value is! Map<String, dynamic> ||
          value['name'] is! String ||
          value['label'] is! String ||
          value['latitude'] is! num ||
          value['longitude'] is! num) {
        return null;
      }
      return WeatherPlace(
        name: value['name'] as String,
        label: value['label'] as String,
        latitude: (value['latitude'] as num).toDouble(),
        longitude: (value['longitude'] as num).toDouble(),
      );
    } on FormatException {
      return null;
    }
  }
}

class _WeatherTodayPreview extends StatelessWidget {
  const _WeatherTodayPreview({
    required this.reading,
    required this.preferences,
  });

  final WeatherReading reading;
  final AppPreferences preferences;

  @override
  Widget build(BuildContext context) {
    final weather = reading.snapshot;
    final secondary = preferences.showWeatherLocationAndCondition
        ? '${reading.place.name} · ${weatherDescription(weather.weatherCode)}'
        : weatherDescription(weather.weatherCode);
    final details = <String>[
      if (preferences.showWeatherFeelsLike)
        'Feels like ${weather.apparentTemperatureC.round()}°C',
      if (preferences.showWeatherRainChance &&
          weather.precipitationProbability != null)
        'Rain ${weather.precipitationProbability}%',
      if (preferences.showWeatherWindSpeed)
        'Wind ${weather.windSpeedKmh.round()} km/h',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Today preview', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        greetingForWeather(
                          localHour: DateTime.now().hour,
                          isDay: reading.snapshot.isDay,
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (preferences.effectiveWeatherLayout ==
                          WeatherLayout.moreDetails)
                        Text(secondary, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                WeatherConditionIcon(
                  code: weather.weatherCode,
                  isDay: weather.isDay,
                  windSpeedKmh: weather.windSpeedKmh,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  '${weather.temperatureC.round()}°',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (preferences.effectiveWeatherLayout == WeatherLayout.compact)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(secondary, style: Theme.of(context).textTheme.bodySmall),
              ),
            if (preferences.effectiveWeatherLayout == WeatherLayout.moreDetails &&
                details.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(details.join('  ·  '), style: Theme.of(context).textTheme.bodySmall),
            ],
            if (reading.isCached)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Saved conditions · may be out of date',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WeatherPreviewLoading extends StatelessWidget {
  const _WeatherPreviewLoading();

  @override
  Widget build(BuildContext context) => const Card(
    child: ListTile(
      leading: SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
      ),
      title: Text('Today preview'),
      subtitle: Text('Loading your local forecast…'),
    ),
  );
}

class _WeatherPreviewUnavailable extends StatelessWidget {
  const _WeatherPreviewUnavailable();

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.cloud_off_outlined),
      title: const Text('Today preview'),
      subtitle: const Text('Weather is unavailable. Try refreshing later.'),
      subtitleTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
    ),
  );
}

String weatherDescription(int code) => switch (code) {
  0 => 'Clear sky',
  1 => 'Mainly clear',
  2 => 'Partly cloudy',
  3 => 'Overcast',
  45 || 48 => 'Foggy',
  51 || 53 || 55 => 'Drizzle',
  56 || 57 => 'Freezing drizzle',
  61 || 63 || 65 => 'Rain',
  66 || 67 => 'Freezing rain',
  71 || 73 || 75 || 77 => 'Snow',
  80 || 81 || 82 => 'Rain showers',
  85 || 86 => 'Snow showers',
  95 || 96 || 99 => 'Thunderstorms',
  _ => 'Conditions unavailable',
};
