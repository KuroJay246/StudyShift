import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/platform/startup_appearance_bridge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/launcher_icon');

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    StartupAppearanceBridge.resetForTesting();
  });

  test('parses the saved appearance passed to the Dart entrypoint', () {
    final appearance = StartupAppearanceBridge.fromEntrypointArgs([
      'light',
      'red',
    ]);
    expect(appearance?.theme, ThemePreference.light);
    expect(appearance?.accentTheme, AccentTheme.red);
    expect(StartupAppearanceBridge.fromEntrypointArgs(const []), isNull);
    final partial = StartupAppearanceBridge.fromEntrypointArgs([
      'unknown',
      'teal',
    ]);
    expect(partial?.theme, isNull);
    expect(partial?.accentTheme, AccentTheme.teal);
  });

  test('syncs changed appearance choices to Android startup storage', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });

    await StartupAppearanceBridge.sync(
      const AppPreferences(
        theme: ThemePreference.dark,
        accentTheme: AccentTheme.violet,
      ),
    );

    expect(calls.single.method, 'syncStartupAppearance');
    expect(calls.single.arguments, {'theme': 'dark', 'accentTheme': 'violet'});
  });

  test(
    'does not sync the Android appearance cache on other platforms',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      var called = false;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (_) async {
            called = true;
            return <String, String>{};
          });

      await StartupAppearanceBridge.sync(
        const AppPreferences(
          theme: ThemePreference.system,
          accentTheme: AccentTheme.studyShiftBlue,
        ),
      );
      expect(called, isFalse);
    },
  );
}
