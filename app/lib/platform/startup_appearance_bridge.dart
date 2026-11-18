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
  static StartupAppearance? _lastSynced;

  /// Parses the appearance snapshot passed by Android before Dart starts.
  /// This keeps the saved theme on the first Flutter frame without a startup
  /// method-channel round trip.
  static StartupAppearance? fromEntrypointArgs(List<String> args) {
    if (args.length < 2) return null;
    final appearance = StartupAppearance(
      theme: _enumValue(ThemePreference.values, args[0]),
      accentTheme: _enumValue(AccentTheme.values, args[1]),
    );
    if (appearance.theme == null && appearance.accentTheme == null) return null;
    _lastSynced = appearance;
    return appearance;
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
