import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/startup_launch_gate.dart';
import 'package:shift_study/presentation/startup_splash.dart';
import 'package:shift_study/presentation/widgets/studyshift_brand_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  testWidgets('first Flutter splash frame already shows the brand icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: StudyShiftSplash(ready: false)),
    );

    final icon = find.byType(StudyShiftBrandIcon);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: icon, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, greaterThanOrEqualTo(.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('splash reveals the StudyShift brand and local loading message', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: StudyShiftSplash(ready: false)),
    );
    await tester.pump(const Duration(milliseconds: 1400));

    expect(find.text('StudyShift'), findsOneWidget);
    expect(find.text('WORK  •  STUDY  •  PLAN'), findsOneWidget);
    expect(find.text('Loading your schedule…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready state and reduced motion remain readable in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: const StudyShiftSplash(ready: true),
      ),
    );
    await tester.pump();

    expect(find.text('Ready!'), findsOneWidget);
    expect(find.text('StudyShift'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready transition never stacks loading and ready messages', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const StudyShiftSplash(ready: true),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1100));

    expect(find.text('Ready!'), findsOneWidget);
    expect(find.text('Loading your schedule…'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final accentTheme in AccentTheme.values) {
    testWidgets('$accentTheme colors the splash with its selected accent', (
      tester,
    ) async {
      final theme = AppTheme.light(accentTheme: accentTheme);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: StudyShiftSplash(ready: false, accentTheme: accentTheme),
        ),
      );
      await tester.pump(const Duration(milliseconds: 800));

      final indicator = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(indicator.valueColor!.value, theme.colorScheme.primary);
      final rasterMark = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName.startsWith(
                'assets/branding/studyshift-symbol-',
              ),
        ),
      );
      expect(rasterMark.fit, BoxFit.contain);
      expect(
        (rasterMark.image as AssetImage).assetName,
        'assets/branding/studyshift-symbol-${switch (accentTheme) {
          AccentTheme.studyShiftBlue => 'blue',
          AccentTheme.teal => 'teal',
          AccentTheme.violet => 'violet',
          AccentTheme.amber => 'amber',
          AccentTheme.red => 'red',
        }}.png',
      );
      expect(find.byType(ColorFiltered), findsNothing);
    });
  }

  testWidgets('slow local startup keeps the branded loading screen visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StartupLaunchGate(
          ready: false,
          finished: false,
          child: Text('Schedule ready'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 2600));

    expect(find.byType(StudyShiftBrandIcon), findsOneWidget);
    expect(find.text('Loading your schedule…'), findsOneWidget);
    expect(find.text('Still loading your schedule…'), findsNothing);
    expect(find.text('Your schedule could not be opened'), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(
      const MaterialApp(
        home: StartupLaunchGate(
          ready: true,
          finished: true,
          child: Text('Schedule ready'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Schedule ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready schedules still show the branded first Flutter frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: StartupLaunchGate(
          ready: true,
          finished: true,
          child: const Text('Today screen'),
        ),
      ),
    );

    expect(find.text('StudyShift'), findsOneWidget);
    expect(find.text('Today screen'), findsNothing);

    await tester.pump(const Duration(milliseconds: 1799));
    expect(find.text('StudyShift'), findsOneWidget);
    expect(find.text('Today screen'), findsNothing);

    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text('Today screen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
