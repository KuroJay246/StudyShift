import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../domain/schedule.dart';
import '../schedule_format.dart';
import '../widgets/schedule_details_sheet.dart';
import '../widgets/schedule_event_tile.dart';

enum _SearchScope { all, work, school, personal }

class ScheduleSearchPage extends ConsumerStatefulWidget {
  const ScheduleSearchPage({super.key});

  @override
  ConsumerState<ScheduleSearchPage> createState() => _ScheduleSearchPageState();
}

class _ScheduleSearchPageState extends ConsumerState<ScheduleSearchPage> {
  final _query = TextEditingController();
  _SearchScope _scope = _SearchScope.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final items = ref.watch(scheduleItemsProvider);
    final use24Hour = preferenceUses24Hour(preferences, context);
    return Scaffold(
      appBar: AppBar(title: const Text('Find an event')),
      body: items.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Your schedule could not be loaded.'),
              TextButton(
                onPressed: () => ref.invalidate(scheduleItemsProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
        data: (allItems) {
          final matches = allItems.where(_matches).toList()
            ..sort((a, b) {
              final dateOrder = a.startDate.compareTo(b.startDate);
              return dateOrder == 0 ? a.title.compareTo(b.title) : dateOrder;
            });
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              TextField(
                controller: _query,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Search your schedule',
                  hintText: 'Name, course code, location or note',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _query.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final scope in _SearchScope.values) ...[
                      ChoiceChip(
                        label: Text(_scopeLabel(scope)),
                        selected: _scope == scope,
                        onSelected: (_) => setState(() => _scope = scope),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (matches.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 56),
                  child: Column(
                    children: [
                      Icon(
                        _query.text.isEmpty && _scope == _SearchScope.all
                            ? Icons.event_note_outlined
                            : Icons.search_off_rounded,
                        size: 34,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _query.text.isEmpty && _scope == _SearchScope.all
                            ? 'No saved events yet'
                            : 'No matching events',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _query.text.isEmpty && _scope == _SearchScope.all
                            ? 'Add a shift, class or plan to start your schedule.'
                            : 'Try another word or schedule category.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  '${matches.length} ${matches.length == 1 ? 'event' : 'events'}',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < matches.length; index++) ...[
                  ScheduleEventTile(
                    item: matches[index],
                    use24Hour: use24Hour,
                    dateLabel: MaterialLocalizations.of(context)
                        .formatMediumDate(
                          DateTime(
                            matches[index].startDate.year,
                            matches[index].startDate.month,
                            matches[index].startDate.day,
                          ),
                        ),
                    staggerIndex: index,
                    onTap: () =>
                        showScheduleDetails(context, ref, matches[index]),
                  ),
                  if (index < matches.length - 1) const SizedBox(height: 10),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  bool _matches(ScheduleItem item) {
    final inScope = switch (_scope) {
      _SearchScope.all => true,
      _SearchScope.work => item.kind == ScheduleKind.work,
      _SearchScope.school =>
        item.kind == ScheduleKind.classSession ||
            item.kind == ScheduleKind.deadline,
      _SearchScope.personal => item.kind == ScheduleKind.personal,
    };
    if (!inScope) return false;
    final query = _query.text.trim().toLowerCase();
    if (query.isEmpty) return true;
    final fields = [
      item.title,
      item.code ?? '',
      item.codeMeaning ?? '',
      item.location ?? '',
      item.notes ?? '',
      item.reportingInstruction ?? '',
      item.startDate.toString(),
      scheduleKindName(item.kind),
      if (item.workCategory != null) workCategoryName(item.workCategory!),
      if (item.deadlineType != null) deadlineTypeName(item.deadlineType!),
    ];
    return fields.any((value) => value.toLowerCase().contains(query));
  }

  String _scopeLabel(_SearchScope scope) => switch (scope) {
    _SearchScope.all => 'All',
    _SearchScope.work => 'Work',
    _SearchScope.school => 'School',
    _SearchScope.personal => 'Personal',
  };
}
