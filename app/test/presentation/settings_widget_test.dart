import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/platform/local_reminders.dart';
import 'package:shift_study/platform/startup_appearance_bridge.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/screens/settings_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/widget');
  const appVersionChannel = MethodChannel('app.shiftstudy/app_version');
  const startupAppearanceChannel = MethodChannel(
    'app.shiftstudy/launcher_icon',
  );
  const notificationSettingsChannel = MethodChannel('app.shiftstudy/settings');
  var requestCount = 0;
  var settingsOpenCount = 0;
  var notificationWasRequested = false;

  tearDown(() {
    requestCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appVersionChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(startupAppearanceChannel, null);
    StartupAppearanceBridge.resetForTesting();
    settingsOpenCount = 0;
    notificationWasRequested = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(notificationSettingsChannel, null);
  });

  testWidgets('More uses concise helper text for its planning tools', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Search your schedule'), findsOneWidget);
    expect(find.text('Add or configure a widget'), findsOneWidget);
    expect(find.text('Manage reminders'), findsOneWidget);
    expect(find.text('Import ICS or CSV'), findsOneWidget);
    expect(find.text('Export as an iCalendar file'), findsOneWidget);
    expect(find.text('Location and Today’s forecast'), findsOneWidget);
  });

  testWidgets('More opens the privacy-limited import history page', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Import calendar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Import history'));
    await tester.pumpAndSettle();

    expect(find.text('No accepted imports yet'), findsOneWidget);
    expect(
      find.textContaining('Only the 50 most recent summaries'),
      findsOneWidget,
    );
    expect(find.text('Import history'), findsOneWidget);
  });

  testWidgets(
    'Notifications shows permission state before requesting or opening settings',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(notificationSettingsChannel, (call) async {
            switch (call.method) {
              case 'wasNotificationPermissionRequested':
                return notificationWasRequested;
              case 'recordNotificationPermissionRequest':
                notificationWasRequested = true;
                return true;
              case 'openNotificationSettings':
              case 'openExactAlarmSettings':
                settingsOpenCount++;
                return true;
              default:
                return null;
            }
          });
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
          localReminderServiceProvider.overrideWith(
            (ref) => _PermissionPrompt(
              onRequest: () => requestCount++,
              permissions: const ReminderPermissionResult(
                notificationsAllowed: false,
                exactTimingAllowed: false,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: Scaffold(
              body: SettingsPage(mode: ScheduleMode.workAndSchool),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Notifications'));
      await tester.pumpAndSettle();
      expect(find.text('Notifications'), findsWidgets);
      expect(find.text('Not enabled yet'), findsOneWidget);
      expect(find.text('Exact timing is off'), findsOneWidget);
      expect(find.text('Allow notifications'), findsOneWidget);
      expect(find.text('Open notification settings'), findsNothing);
      expect(find.text('Open exact alarm settings'), findsOneWidget);
      expect(requestCount, 0);
      expect(settingsOpenCount, 0);

      await tester.tap(find.text('Open exact alarm settings'));
      await tester.pumpAndSettle();
      expect(settingsOpenCount, 1);

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      expect(requestCount, 1);
      expect(find.text('Open notification settings'), findsOneWidget);
      expect(settingsOpenCount, 1);
      await tester.tap(find.text('Open notification settings'));
      await tester.pumpAndSettle();
      expect(settingsOpenCount, 2);
    },
  );

  testWidgets('More opens the opt-in weather settings route', (tester) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weather & location'));
    await tester.pumpAndSettle();

    expect(find.text('Local weather'), findsOneWidget);
    expect(find.text('Show weather on Today'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.text('Choose a place manually'), findsOneWidget);
  });

  testWidgets('More groups schedule, calendar, and daily tools separately', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Plan & organize'), findsOneWidget);
    expect(find.text('Calendar'), findsOneWidget);
    expect(find.text('Notifications & weather'), findsOneWidget);

    final planCard = find
        .ancestor(of: find.text('Find an event'), matching: find.byType(Card))
        .first;
    expect(tester.getSize(planCard).height, lessThan(220));
    expect(
      find.descendant(of: planCard, matching: find.text('Home-screen widget')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: planCard, matching: find.text('Import calendar')),
      findsNothing,
    );

    final calendarCard = find
        .ancestor(of: find.text('Import calendar'), matching: find.byType(Card))
        .first;
    expect(tester.getSize(calendarCard).height, lessThan(220));
    expect(
      find.descendant(of: calendarCard, matching: find.text('Export calendar')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: calendarCard,
        matching: find.text('Weather & location'),
      ),
      findsNothing,
    );

    final dailyToolsCard = find
        .ancestor(of: find.text('Notifications'), matching: find.byType(Card))
        .first;
    expect(
      find.descendant(
        of: dailyToolsCard,
        matching: find.text('Weather & location'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('color theme selection persists its selected palette', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Color theme'));
    await tester.tap(find.byType(DropdownButton<AccentTheme?>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stylish Teal').last);
    await tester.pumpAndSettle();

    expect(
      (await PreferencesRepository(database).load()).accentTheme,
      AccentTheme.teal,
    );
    expect(find.text('Stylish Teal'), findsNWidgets(2));
  });

  testWidgets(
    'appearance changes sync to the native launch screen before leaving',
    (tester) async {
      final synced = <Map<Object?, Object?>>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(startupAppearanceChannel, (call) async {
            expect(call.method, 'syncStartupAppearance');
            synced.add(Map<Object?, Object?>.from(call.arguments as Map));
            return true;
          });

      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          scheduleDatabaseProvider.overrideWith((ref) {
            ref.onDispose(database.close);
            return database;
          }),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
            home: const Scaffold(
              body: SettingsPage(mode: ScheduleMode.workAndSchool),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButton<ThemePreference?>));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<ThemePreference?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Light').last);
      await tester.pumpAndSettle();

      expect(synced, isNotEmpty);
      expect(synced.last['theme'], 'light');
      expect(synced.last['accentTheme'], isNull);
      expect(
        (await PreferencesRepository(database).load()).theme,
        ThemePreference.light,
      );
    },
  );

  testWidgets('More lets the owner choose which widget to pin', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestPin');
          expect(call.arguments, {'family': 'week'});
          requestCount++;
          return true;
        });

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.android),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Home-screen widget'));
    await tester.pumpAndSettle();
    expect(find.text('Add a StudyShift widget'), findsOneWidget);
    expect(find.text('Next event'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    await tester.tap(find.text('This week').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(requestCount, 1);
    expect(
      find.text('Finish adding the widget in your launcher.'),
      findsOneWidget,
    );
  });

  testWidgets('Home-screen widget action is hidden off Android', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light().copyWith(platform: TargetPlatform.iOS),
          home: const Scaffold(
            body: SettingsPage(mode: ScheduleMode.workAndSchool),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home-screen widget'), findsNothing);
  });

  testWidgets('More opens About with the installed app version', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(appVersionChannel, (call) async {
          expect(call.method, 'getAppVersion');
          return {'name': '0.1.0', 'code': 47};
        });

    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    await PreferencesRepository(database).setAccentTheme(AccentTheme.violet);
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: SettingsPage(mode: ScheduleMode.workAndSchool)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.dragUntilVisible(
      find.text('About StudyShift'),
      find.byType(ListView),
      const Offset(0, -240),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('About StudyShift'));
    await tester.pumpAndSettle();

    expect(find.text('Version 0.1.0 (47)'), findsOneWidget);
    expect(find.text('Created by Jaylan Maynard'), findsOneWidget);
    expect(find.text('Private by design'), findsNothing);
    expect(
      (tester.widget<Image>(find.byType(Image).first).image as AssetImage)
          .assetName,
      'assets/branding/studyshift-symbol-violet.png',
    );
  });
}

class _PermissionPrompt extends LocalReminderService {
  _PermissionPrompt({required this.onRequest, required this.permissions});
  final void Function() onRequest;
  final ReminderPermissionResult permissions;

  @override
  Future<ReminderPermissionResult> currentPermissions() async => permissions;

  @override
  Future<bool> requestNotificationPermission() async {
    onRequest();
    return false;
  }
}
