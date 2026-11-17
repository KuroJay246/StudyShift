import '../application/schedule_queries.dart';
import '../domain/schedule.dart';
import 'widget_snapshot.dart';
import 'widget_snapshot_store.dart';

/// Uses the same Today/next-event queries as application views before handing
/// the result to the native Android storage adapter.
class WidgetSnapshotPublisher {
  const WidgetSnapshotPublisher({required this.queries, required this.store});

  final ScheduleQueries queries;
  final WidgetSnapshotStore store;

  Future<void> publish(Iterable<ScheduleItem> items, DateTime now) {
    final snapshot = WidgetSnapshot.forSchedule(
      items: items,
      queries: queries,
      now: now,
    );
    return store.save(snapshot.encode());
  }
}
