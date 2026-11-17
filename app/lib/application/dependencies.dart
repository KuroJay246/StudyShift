import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/widgets.dart';

import '../data/preferences_repository.dart';
import '../data/academic_term_repository.dart';
import '../data/schedule_database.dart';
import '../data/schedule_repository.dart';
import '../data/schedule_import_history_repository.dart';
import '../data/supervisor_repository.dart';
import '../data/work_code_legend_repository.dart';
import '../data/weather_repository.dart';
import '../data/open_meteo_weather_service.dart';
import '../domain/schedule.dart';
import '../domain/supervisor_profile.dart';
import '../domain/academic_term.dart';
import '../domain/schedule_engine.dart';
import '../platform/widget_snapshot_publisher.dart';
import '../platform/widget_snapshot_store.dart';
import '../platform/widget_launch_destination.dart';
import '../platform/device_time_zone.dart';
import '../platform/approximate_location_bridge.dart';
import '../platform/local_reminders.dart';
import 'schedule_queries.dart';
import 'day_availability.dart';

final scheduleDatabaseProvider = Provider<ScheduleDatabase>((ref) {
  final database = ScheduleDatabase();
  ref.onDispose(database.close);
  return database;
});

final scheduleRepositoryProvider = Provider<ScheduleRepository>(
  (ref) => ScheduleRepository(ref.watch(scheduleDatabaseProvider)),
);

final scheduleImportHistoryRepositoryProvider =
    Provider<ScheduleImportHistoryRepository>(
      (ref) =>
          ScheduleImportHistoryRepository(ref.watch(scheduleDatabaseProvider)),
    );

final scheduleImportHistoryProvider =
    StreamProvider<List<ScheduleImportHistoryEntry>>(
      (ref) =>
          ref.watch(scheduleImportHistoryRepositoryProvider).watchEntries(),
    );

final workCodeLegendRepositoryProvider = Provider<WorkCodeLegendRepository>(
  (ref) => WorkCodeLegendRepository(ref.watch(scheduleDatabaseProvider)),
);

final workCodeLegendsProvider = StreamProvider(
  (ref) => ref.watch(workCodeLegendRepositoryProvider).watchItems(),
);

final supervisorRepositoryProvider = Provider<SupervisorRepository>(
  (ref) => SupervisorRepository(ref.watch(scheduleDatabaseProvider)),
);

final supervisorProfilesProvider = StreamProvider<List<SupervisorProfile>>(
  (ref) => ref.watch(supervisorRepositoryProvider).watchItems(),
);

final academicTermRepositoryProvider = Provider<AcademicTermRepository>(
  (ref) => AcademicTermRepository(ref.watch(scheduleDatabaseProvider)),
);

final academicTermsProvider = StreamProvider<List<AcademicTerm>>(
  (ref) => ref.watch(academicTermRepositoryProvider).watchItems(),
);

final preferencesRepositoryProvider = Provider<PreferencesRepository>(
  (ref) => PreferencesRepository(ref.watch(scheduleDatabaseProvider)),
);

final openMeteoWeatherServiceProvider = Provider<OpenMeteoWeatherService>(
  (ref) => OpenMeteoWeatherService(),
);

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => WeatherRepository(
    preferences: ref.watch(preferencesRepositoryProvider),
    service: ref.watch(openMeteoWeatherServiceProvider),
  ),
);

final weatherReadingProvider = FutureProvider<WeatherReading?>((ref) async {
  final preferences = await ref.watch(appPreferencesProvider.future);
  return ref.read(weatherRepositoryProvider).load(preferences);
});

final approximateWeatherLocationProvider = Provider(
  (ref) => const ApproximateWeatherLocationBridge(),
);

final appPreferencesProvider = FutureProvider<AppPreferences>(
  (ref) => ref.watch(preferencesRepositoryProvider).load(),
);

final widgetLaunchDestinationProvider = FutureProvider<String?>(
  (ref) => const WidgetLaunchDestinationBridge().getInitialDestination(),
);

final deviceTimeZoneProvider = Provider<DeviceTimeZone>(
  (ref) => const AndroidDeviceTimeZone(),
);

final scheduleQueriesProvider = Provider<ScheduleQueries>(
  (ref) => ScheduleQueries(ref.watch(scheduleEngineProvider)),
);

final scheduleEngineProvider = Provider<ScheduleEngine>(
  (ref) => const ScheduleEngine(),
);

final dayAvailabilityProvider = Provider<DayAvailability>(
  (ref) => DayAvailability(ref.watch(scheduleEngineProvider)),
);

final deviceTimeZoneIdProvider = FutureProvider<String>(
  (ref) => ref.watch(deviceTimeZoneProvider).getLocalIanaId(),
);

final scheduleItemsProvider = StreamProvider<List<ScheduleItem>>(
  (ref) => ref.watch(scheduleRepositoryProvider).watchItems(),
);

final widgetSnapshotStoreProvider = Provider<WidgetSnapshotStore>(
  (ref) => WidgetSnapshotStore(),
);

final widgetSnapshotPublisherProvider = Provider<WidgetSnapshotPublisher>(
  (ref) => WidgetSnapshotPublisher(
    queries: ref.watch(scheduleQueriesProvider),
    store: ref.watch(widgetSnapshotStoreProvider),
  ),
);

/// Keep the native widget projection current while the application is open.
/// The native widget's supported refresh cycle handles later time-based changes.
final widgetSnapshotSyncProvider = Provider<void>((ref) {
  final publisher = ref.watch(widgetSnapshotPublisherProvider);
  final subscription = ref
      .watch(scheduleRepositoryProvider)
      .watchItems()
      .listen((items) {
        unawaited(
          publisher.publish(items, DateTime.now()).catchError((
            Object error,
            StackTrace stackTrace,
          ) {
            FlutterError.reportError(
              FlutterErrorDetails(
                exception: error,
                stack: stackTrace,
                library: 'widget snapshot synchronization',
              ),
            );
          }),
        );
      });
  ref.onDispose(() => unawaited(subscription.cancel()));
});

final localReminderServiceProvider = Provider<LocalReminderService>(
  (ref) => LocalReminderService(),
);

final reminderDestinationsProvider = StreamProvider<ReminderDestination>(
  (ref) => ref.watch(localReminderServiceProvider).destinations,
);

/// Reconciles Android's scheduled notifications with the local event database.
/// It also refreshes after returning from system notification settings.
final localReminderSyncProvider = Provider<void>((ref) {
  final service = ref.watch(localReminderServiceProvider);
  final repository = ref.watch(scheduleRepositoryProvider);
  final subscription = repository.watchItems().listen((items) {
    unawaited(
      service.reconcile(items).catchError((Object error, StackTrace stack) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'local reminder synchronization',
          ),
        );
      }),
    );
  });
  final lifecycle = AppLifecycleListener(
    onResume: () {
      unawaited(
        repository.getItems().then(service.reconcile).catchError((
          Object error,
          StackTrace stack,
        ) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'local reminder refresh',
            ),
          );
        }),
      );
    },
  );
  ref.onDispose(() {
    lifecycle.dispose();
    unawaited(subscription.cancel());
  });
});
