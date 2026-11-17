import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shift_study/application/dependencies.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/platform/widget_pin_requester.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android app database and widget bridge persist a synthetic shift',
    (tester) async {
      final ready = Completer<ProviderContainer>();
      await tester.pumpWidget(ProviderScope(child: _Harness(ready: ready)));
      final container = await ready.future.timeout(const Duration(seconds: 10));
      final repository = container.read(scheduleRepositoryProvider);
      final now = DateTime.now();
      const itemId = 'synthetic-device-shift';
      final item = ScheduleItem(
        id: itemId,
        kind: ScheduleKind.work,
        title: 'Synthetic split overnight shift',
        startDate: CivilDate.fromDateTime(now),
        timeZoneId: 'America/Barbados',
        intervals: [
          EventInterval(
            startDayOffset: 0,
            startMinute: 8 * 60,
            endDayOffset: 0,
            endMinute: 10 * 60,
            startFoldChoice: CivilTimeFoldChoice.later,
          ),
          EventInterval.overnight(startMinute: 22 * 60, endMinute: 6 * 60),
        ],
        code: 'TEST',
        location: 'Synthetic location',
        notes: 'Automated Android integration fixture',
      );

      await repository.save(item);
      final persisted = (await repository.getItems()).singleWhere(
        (saved) => saved.id == itemId,
      );
      expect(persisted.id, itemId);
      expect(persisted.intervals, orderedEquals(item.intervals));
      expect(persisted.intervals.last.endDayOffset, 1);
      expect(persisted.timeZoneId, 'America/Barbados');
      await container
          .read(widgetSnapshotPublisherProvider)
          .publish(await repository.getItems(), DateTime.now());

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Recreate the app's local provider scope against the same Android app
      // database file, proving the saved schedule survives database close/open.
      final reopened = Completer<ProviderContainer>();
      await tester.pumpWidget(ProviderScope(child: _Harness(ready: reopened)));
      final reopenedContainer = await reopened.future.timeout(
        const Duration(seconds: 10),
      );
      final afterReopen =
          (await reopenedContainer.read(scheduleRepositoryProvider).getItems())
              .singleWhere((saved) => saved.id == itemId);
      expect(afterReopen.id, itemId);
      expect(afterReopen.intervals, orderedEquals(item.intervals));
      expect(afterReopen.timeZoneId, 'America/Barbados');
      await reopenedContainer
          .read(widgetSnapshotPublisherProvider)
          .publish(
            await reopenedContainer.read(scheduleRepositoryProvider).getItems(),
            DateTime.now(),
          );
      final widgetPin = WidgetPinRequester();
      if (await widgetPin.installedInstanceCount() == 0) {
        // The launcher may show confirmation; true only means that it accepted
        // the request for presentation, not that the widget has been pinned.
        expect(await widgetPin.requestPin(WidgetFamily.nextEvent), isTrue);
      }
      final updatedTitle =
          'Refreshed shift ${DateTime.now().millisecondsSinceEpoch}';
      await reopenedContainer
          .read(scheduleRepositoryProvider)
          .save(item.copyWith(title: updatedTitle));
      await reopenedContainer
          .read(widgetSnapshotPublisherProvider)
          .publish(
            await reopenedContainer.read(scheduleRepositoryProvider).getItems(),
            DateTime.now(),
          );
      await reopenedContainer.read(scheduleRepositoryProvider).delete(itemId);
      expect(
        (await reopenedContainer.read(scheduleRepositoryProvider).getItems())
            .where((saved) => saved.id == itemId),
        isEmpty,
      );
      await reopenedContainer
          .read(widgetSnapshotPublisherProvider)
          .publish(
            await reopenedContainer.read(scheduleRepositoryProvider).getItems(),
            DateTime.now(),
          );
    },
  );
}

class _Harness extends ConsumerWidget {
  const _Harness({required this.ready});

  final Completer<ProviderContainer> ready;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(widgetSnapshotSyncProvider);
    if (!ready.isCompleted) {
      ready.complete(ProviderScope.containerOf(context, listen: false));
    }
    return const MaterialApp(home: SizedBox.shrink());
  }
}
