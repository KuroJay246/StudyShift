import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/dependencies.dart';
import 'data/preferences_repository.dart';
import 'platform/startup_appearance_bridge.dart';
import 'presentation/app.dart';
import 'presentation/app_theme.dart';
import 'presentation/startup_launch_gate.dart';

void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  final startupAppearance = StartupAppearanceBridge.fromEntrypointArgs(args);
  runApp(ProviderScope(child: MainApp(startupAppearance: startupAppearance)));
}

class MainApp extends ConsumerWidget {
  const MainApp({super.key, this.startupAppearance});

  final StartupAppearance? startupAppearance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSnapshotSyncProvider);
    ref.watch(localReminderSyncProvider);
    final preferences = ref.watch(appPreferencesProvider);
    final scheduleItems = ref.watch(scheduleItemsProvider);
    final widgetLaunchDestination = ref.watch(widgetLaunchDestinationProvider);
    final startupError = preferences.hasError
        ? preferences.error
        : scheduleItems.hasError
        ? scheduleItems.error
        : null;
    final loadedPreferences = preferences.value;
    if (loadedPreferences != null) {
      unawaited(StartupAppearanceBridge.sync(loadedPreferences));
    }
    final accentTheme = loadedPreferences == null
        ? startupAppearance?.accentTheme ?? AccentTheme.studyShiftBlue
        : loadedPreferences.accentTheme ?? AccentTheme.studyShiftBlue;
    final themePreference = loadedPreferences == null
        ? startupAppearance?.theme
        : loadedPreferences.theme;
    // Schedule pages render their own loading and retry states. Keep their
    // first frame responsive instead of making the splash wait for the entire
    // local schedule stream to emit.
    final ready = loadedPreferences != null && widgetLaunchDestination.hasValue;
    final destination = startupError != null
        ? StartupFailureScreen(
            message: startupError.toString(),
            onRetry: () {
              ref.invalidate(appPreferencesProvider);
              ref.invalidate(scheduleItemsProvider);
            },
          )
        : !ready
        ? const StartupLoadingScreen()
        : loadedPreferences.scheduleMode == null
        ? const ModeSetupPage()
        : ScheduleShell(
            mode: loadedPreferences.scheduleMode!,
            initialDestination: widgetLaunchDestination.value ?? 'today',
          );
    return MaterialApp(
      title: 'StudyShift',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(
        accentTheme: accentTheme,
        preferences: loadedPreferences,
      ),
      darkTheme: AppTheme.dark(
        accentTheme: accentTheme,
        preferences: loadedPreferences,
      ),
      themeMode: switch (themePreference) {
        ThemePreference.light => ThemeMode.light,
        ThemePreference.dark => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      home: StartupLaunchGate(
        ready: ready,
        finished: ready || startupError != null,
        accentTheme: accentTheme,
        child: destination,
      ),
    );
  }
}
