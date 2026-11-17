import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../../domain/academic_term.dart';
import '../../domain/schedule.dart';

class AcademicTermsPage extends ConsumerWidget {
  const AcademicTermsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final termsAsync = ref.watch(academicTermsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Academic terms')),
      floatingActionButton: termsAsync.maybeWhen(
        data: (terms) => terms.isEmpty
            ? null
            : FloatingActionButton(
                onPressed: () => _edit(context, ref),
                tooltip: 'Add term',
                child: const Icon(Icons.add_rounded),
              ),
        orElse: () => null,
      ),
      body: termsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _TermError(
          message: 'Your academic terms could not be loaded.',
          onRetry: () => ref.invalidate(academicTermsProvider),
        ),
        data: (terms) => terms.isEmpty
            ? _TermEmptyState(onAdd: () => _edit(context, ref))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 104),
                itemCount: terms.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final term = terms[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.school_outlined),
                      title: Text(term.name),
                      subtitle: Text(
                        '${term.institution}\n${_dateRange(context, term)}',
                      ),
                      isThreeLine: true,
                      onTap: () => _edit(context, ref, existing: term),
                      trailing: PopupMenuButton<String>(
                        tooltip: 'Term actions',
                        onSelected: (action) {
                          if (action == 'edit') {
                            _edit(context, ref, existing: term);
                          } else if (action == 'delete') {
                            _delete(context, ref, term);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'delete', child: Text('Delete')),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref, {
    AcademicTerm? existing,
  }) async {
    final term = await showDialog<AcademicTerm>(
      context: context,
      builder: (_) => _AcademicTermEditor(existing: existing),
    );
    if (term == null || !context.mounted) return;
    try {
      await ref.read(academicTermRepositoryProvider).save(term);
      ref.invalidate(academicTermsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('${term.name} saved.')));
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_errorMessage(error))));
      }
    }
  }

  static Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AcademicTerm term,
  ) async {
    final items = await ref.read(scheduleRepositoryProvider).getItems();
    if (!context.mounted) return;
    final linked = items.where((item) => item.academicTermId == term.id).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: Text('Delete ${term.name}?'),
        content: Text(
          linked == 0
              ? 'This term will be removed from this device.'
              : '$linked saved ${linked == 1 ? 'event' : 'events'} will remain, but will no longer be linked to this term.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep term'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete term'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(academicTermRepositoryProvider).delete(term.id);
    ref.invalidate(academicTermsProvider);
    ref.invalidate(scheduleItemsProvider);
  }

  static String _dateRange(BuildContext context, AcademicTerm term) {
    final localizations = MaterialLocalizations.of(context);
    return '${localizations.formatMediumDate(DateTime(term.startDate.year, term.startDate.month, term.startDate.day))} – ${localizations.formatMediumDate(DateTime(term.endDate.year, term.endDate.month, term.endDate.day))}';
  }

  static String _errorMessage(Object error) => error is FormatException
      ? error.message
      : 'The term could not be saved. Your schedule is unchanged.';
}

class _AcademicTermEditor extends StatefulWidget {
  const _AcademicTermEditor({this.existing});

  final AcademicTerm? existing;

  @override
  State<_AcademicTermEditor> createState() => _AcademicTermEditorState();
}

class _AcademicTermEditorState extends State<_AcademicTermEditor> {
  final _formKey = GlobalKey<FormState>();
  late final _institution = TextEditingController(
    text: widget.existing?.institution ?? '',
  );
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late CivilDate _start =
      widget.existing?.startDate ?? CivilDate.fromDateTime(DateTime.now());
  late CivilDate _end =
      widget.existing?.endDate ??
      CivilDate.fromDateTime(DateTime.now().add(const Duration(days: 120)));
  String? _error;

  @override
  void dispose() {
    _institution.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick(bool start) async {
    final value = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(value.year, value.month, value.day),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (start) {
        _start = CivilDate.fromDateTime(picked);
      } else {
        _end = CivilDate.fromDateTime(picked);
      }
      _error = null;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    try {
      final term = AcademicTerm(
        id:
            widget.existing?.id ??
            'term-${DateTime.now().microsecondsSinceEpoch}',
        institution: _institution.text,
        name: _name.text,
        startDate: _start,
        endDate: _end,
      );
      Navigator.pop(context, term);
    } on ArgumentError catch (error) {
      setState(() => _error = error.message?.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    String format(CivilDate date) => localizations.formatMediumDate(
      DateTime(date.year, date.month, date.day),
    );
    return AlertDialog(
      scrollable: true,
      title: Text(
        widget.existing == null ? 'Add academic term' : 'Edit academic term',
      ),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _institution,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 512,
                decoration: const InputDecoration(labelText: 'Institution'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter an institution.'
                    : null,
              ),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                maxLength: 256,
                decoration: const InputDecoration(
                  labelText: 'Term or semester',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a term name.'
                    : null,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: const Text('Starts'),
                subtitle: Text(format(_start)),
                onTap: () => _pick(true),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Ends'),
                subtitle: Text(format(_end)),
                onTap: () => _pick(false),
              ),
              if (_error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save term')),
      ],
    );
  }
}

class _TermEmptyState extends StatelessWidget {
  const _TermEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Add your academic term',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Terms keep recurring classes within the right semester. You can still add classes without a term.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onAdd,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add term'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _TermError extends StatelessWidget {
  const _TermError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded),
        const SizedBox(height: 8),
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}
