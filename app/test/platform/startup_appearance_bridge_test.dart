import 'dart:async';

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

  test(
    'loads saved light appearance and accent before the first frame',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'loadStartupAppearance');
            return {'theme': 'light', 'accentTheme': 'red'};
          });

      final appearance = await StartupAppearanceBridge.load();

      expect(appearance?.theme, ThemePreference.light);
      expect(appearance?.accentTheme, AccentTheme.red);
    },
  );

  test('keeps a saved accent when the cold-start native reply is delayed', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          return {'theme': 'light', 'accentTheme': 'violet'};
        });

    final appearance = await StartupAppearanceBridge.load();

    expect(appearance?.theme, ThemePreference.light);
    expect(appearance?.accentTheme, AccentTheme.violet);
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

  test('does not call Android appearance cache on other platforms', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var called = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          called = true;
          return <String, String>{};
        });

    expect(await StartupAppearanceBridge.load(), isNull);
    expect(called, isFalse);
  });

  test('falls back promptly if Android startup appearance never responds', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) => Completer<Object?>().future);

    await expectLater(
      StartupAppearanceBridge.load().timeout(const Duration(milliseconds: 2100)),
      completion(isNull),
    );
  });
}
