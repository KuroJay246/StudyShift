import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/preferences_repository.dart';
import 'package:shift_study/platform/device_time_zone.dart';
import 'package:shift_study/presentation/app.dart';
import 'package:shift_study/presentation/app_theme.dart';
import 'package:shift_study/presentation/widgets/navigation_page_track.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('primary swipe navigation stays responsive in both directions', (
    tester,
  ) async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [
        scheduleDatabaseProvider.overrideWith((ref) {
          ref.onDispose(database.close);
          return database;
        }),
        deviceTimeZoneProvider.overrideWith((ref) => _TestTimeZone()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ScheduleShell(
            mode: ScheduleMode.workAndSchool,
            clock: () => DateTime(2026, 11, 17, 10),
          ),
        ),
      ),
    );
    // Today has a repeating hero glow, so pump a bounded frame instead of
    // waiting for the whole app to become idle.
    await tester.pump(const Duration(milliseconds: 32));

    // Destination swipes use the app bar handle so Calendar's own schedule
    // gestures stay local to its week/month controls.
    final swipeHandle = find.byKey(const Key('schedule-primary-swipe-handle'));
    final navigation = find.byType(NavigationBar);
    final destinations = <(String, int, Offset)>[
      ('Week', 1, const Offset(-320, 0)),
      ('Work', 2, const Offset(-320, 0)),
      ('Study', 3, const Offset(-320, 0)),
      ('More', 4, const Offset(-320, 0)),
      ('Study', 3, const Offset(320, 0)),
      ('Work', 2, const Offset(320, 0)),
      ('Week', 1, const Offset(320, 0)),
      ('Today', 0, const Offset(320, 0)),
    ];

    // Prime page transitions and renderer resources before measuring warm
    // swipes, so the first-use shader/route costs are not mixed into them.
    for (final (label, index, offset) in destinations) {
      await tester.fling(swipeHandle, offset, 1800);
      for (var frame = 0; frame < 16; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        tester.widget<NavigationBar>(navigation).selectedIndex,
        index,
        reason: 'The warm-up swipe should select $label.',
      );
    }

    for (var round = 0; round < 3; round++) {
      for (var step = 0; step < destinations.length; step++) {
        final (label, index, offset) = destinations[step];
        final reportKey = 'primary_swipe_${round + 1}_${step + 1}';
        await binding.watchPerformance(() async {
          await tester.fling(swipeHandle, offset, 1800);
          for (var frame = 0; frame < 16; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(
            tester.widget<NavigationBar>(navigation).selectedIndex,
            index,
            reason: 'A swipe should select $label.',
          );
        }, reportKey: reportKey);

        final result = binding.reportData![reportKey] as Map<String, dynamic>;
        debugPrint(
          'PRIMARY_SWIPE_PERFORMANCE '
          '${jsonEncode({'round': round + 1, 'step': step + 1, 'destination': label, ...result})}',
        );
        expect(result['frame_count'], greaterThan(0));
        expect(
          result['90th_percentile_frame_build_time_millis'] as double,
          lessThanOrEqualTo(16.67),
          reason: '$label swipe should keep p90 UI build time within 60 FPS.',
        );
        debugPrint(
          'PRIMARY_SWIPE_RASTER_DIAGNOSTIC '
          'round=${round + 1} '
          'destination=$label '
          'p90=${result['90th_percentile_frame_rasterizer_time_millis']}ms '
          'rasterRisk=${result['missed_frame_rasterizer_budget_count']}/'
          '${result['frame_count']}',
        );
      }
    }
  });

  testWidgets('solid retained-page raster baseline', (tester) async {
    final position = ValueNotifier<double>(0);
    addTearDown(position.dispose);
    final pages = List<Widget>.generate(
      5,
      (index) => ColoredBox(
        color: Colors.primaries[index],
        child: Center(child: Text('Page $index')),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: LayoutBuilder(
          builder: (context, constraints) => NavigationPageTrack(
            pagePosition: position,
            pageWidth: constraints.maxWidth,
            selectedIndex: 0,
            pages: pages,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 32));

    const reportKey = 'solid_page_baseline';
    await binding.watchPerformance(() async {
      for (var frame = 1; frame <= 20; frame++) {
        position.value = frame / 20;
        await tester.pump(const Duration(milliseconds: 16));
      }
    }, reportKey: reportKey);

    final result = binding.reportData![reportKey] as Map<String, dynamic>;
    debugPrint('SOLID_PAGE_RASTER_BASELINE ${jsonEncode(result)}');
    expect(result['frame_count'], greaterThan(0));
  });
}

class _TestTimeZone implements DeviceTimeZone {
  @override
  Future<String> getLocalIanaId() async => 'America/Barbados';
}
