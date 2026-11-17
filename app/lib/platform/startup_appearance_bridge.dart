import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/preferences_repository.dart';

class StartupAppearance {
  const StartupAppearance({this.theme, this.accentTheme});

  final ThemePreference? theme;
  final AccentTheme? accentTheme;
}

/// Holds only the appearance choices needed before SQLite finishes opening.
/// The local database remains the source of truth after startup.
class StartupAppearanceBridge {
  StartupAppearanceBridge._();

  static const MethodChannel _channel = MethodChannel(
    'app.shiftstudy/launcher_icon',
  );
  static const Duration _startupReadTimeout = Duration(seconds: 2);
  static StartupAppearance? _lastSynced;

  static Future<StartupAppearance?> load() async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      final values = await _channel.invokeMapMethod<String, Object?>(
        'loadStartupAppearance',
      ).timeout(_startupReadTimeout);
      if (values == null) return null;
      final appearance = StartupAppearance(
        theme: _enumValue(ThemePreference.values, values['theme']),
        accentTheme: _enumValue(AccentTheme.values, values['accentTheme']),
      );
      _lastSynced = appearance;
      return appearance;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on TimeoutException {
      // The appearance cache is only a startup hint; SQLite remains authoritative.
      return null;
    }
  }

  static Future<void> sync(AppPreferences preferences) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final appearance = StartupAppearance(
      theme: preferences.theme,
      accentTheme: preferences.accentTheme,
    );
    if (_sameAppearance(_lastSynced, appearance)) return;
    try {
      await _channel.invokeMethod<bool>('syncStartupAppearance', {
        'theme': appearance.theme?.name,
        'accentTheme': appearance.accentTheme?.name,
      });
      _lastSynced = appearance;
    } on MissingPluginException {
      // Older builds can still load from SQLite without the startup cache.
    } on PlatformException {
      // Keep SQLite as the source of truth if the platform cache is unavailable.
    }
  }

  @visibleForTesting
  static void resetForTesting() => _lastSynced = null;

  static bool _sameAppearance(
    StartupAppearance? left,
    StartupAppearance right,
  ) => left?.theme == right.theme && left?.accentTheme == right.accentTheme;

  static T? _enumValue<T extends Enum>(List<T> values, Object? value) {
    for (final item in values) {
      if (item.name == value) return item;
    }
    return null;
  }
}
