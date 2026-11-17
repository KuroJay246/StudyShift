import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../application/dependencies.dart';
import '../../data/schedule_backup.dart';
import '../../data/schedule_repository.dart';
import '../../platform/schedule_backup_file_bridge.dart';
import '../design/studyshift_spacing.dart';

enum _RestoreChoice { merge, replace }

class BackupRestorePage extends ConsumerStatefulWidget {
  const BackupRestorePage({super.key});

  @override
  ConsumerState<BackupRestorePage> createState() => _BackupRestorePageState();
}

class _BackupRestorePageState extends ConsumerState<BackupRestorePage> {
  final _codec = const ScheduleBackupCodec();
  final _files = const ScheduleBackupFileBridge();
  bool _working = false;
  String? _message;
  bool _messageIsError = false;

  Future<void> _createBackup() async {
    final passphrase = await _askForPassphrase(confirm: true);
    if (passphrase == null || !mounted) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      final items = await ref.read(scheduleRepositoryProvider).getItems();
      final legends = await ref
          .read(workCodeLegendRepositoryProvider)
          .getItems();
      final terms = await ref.read(academicTermRepositoryProvider).getItems();
      final supervisors = await ref
          .read(supervisorRepositoryProvider)
          .getItems();
      final bytes = await _codec.encode(
        items,
        passphrase: passphrase,
        workCodeLegends: legends,
        academicTerms: terms,
        supervisors: supervisors,
      );
      final now = DateTime.now();
      final saved = await _files.save(
        bytes,
        fileName:
            'shift-study-${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.ssbackup',
      );
      if (!mounted) return;
      _showMessage(
        saved
            ? 'Encrypted backup saved. Keep the passphrase somewhere safe; it cannot be recovered.'
            : 'Backup save cancelled.',
      );
    } on Object catch (error) {
      if (mounted) _showMessage(_safeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() {
      _working = true;
      _message = null;
    });
    Uint8List? bytes;
    try {
      bytes = await _files.open();
      if (bytes == null || !mounted) return;
    } catch (error) {
      if (mounted) _showMessage(_safeError(error), isError: true);
      return;
    } finally {
      if (mounted) setState(() => _working = false);
    }

    final passphrase = await _askForPassphrase(confirm: false);
    if (passphrase == null || !mounted) return;
    setState(() => _working = true);
    try {
      final backup = await _codec.decode(bytes, passphrase: passphrase);
      if (!mounted) return;
      final choice = await _chooseRestore(
        backup.items.length,
        backup.workCodeLegends.length,
        backup.academicTerms.length,
        backup.supervisors.length,
        backup.createdAt,
      );
      if (choice == null || !mounted) return;
      late final ScheduleRestoreResult result;
      await ref.read(scheduleDatabaseProvider).transaction(() async {
        final termIds = await ref
            .read(academicTermRepositoryProvider)
            .restoreItems(
              backup.academicTerms,
              replaceExisting: choice == _RestoreChoice.replace,
            );
        final restoredItems = backup.items
            .map((item) {
              final termId = item.academicTermId;
              return termId == null
                  ? item
                  : item.copyWith(academicTermId: termIds[termId]);
            })
            .toList(growable: false);
        result = await ref
            .read(scheduleRepositoryProvider)
            .restoreItems(
              restoredItems,
              replaceExisting: choice == _RestoreChoice.replace,
            );
        await ref
            .read(workCodeLegendRepositoryProvider)
            .restoreItems(
              backup.workCodeLegends,
              replaceExisting: choice == _RestoreChoice.replace,
            );
        await ref
            .read(supervisorRepositoryProvider)
            .restoreItems(
              backup.supervisors,
              replaceExisting: choice == _RestoreChoice.replace,
            );
      });
      ref.invalidate(scheduleItemsProvider);
      ref.invalidate(workCodeLegendsProvider);
      ref.invalidate(academicTermsProvider);
      ref.invalidate(supervisorProfilesProvider);
      if (mounted) {
        _showMessage(_restoreSummary(result, choice));
      }
    } on Object catch (error) {
      if (mounted) _showMessage(_safeError(error), isError: true);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _resetAppData() async {
    final firstConfirmation = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Reset StudyShift?'),
        content: const Text(
          'This permanently clears all StudyShift events, shift codes, supervisors, academic terms, import history and preferences stored on this device. External calendar entries are not changed. Create a backup first if you may need this data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (firstConfirmation != true || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _FactoryResetConfirmDialog(),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _working = true;
      _message = null;
    });
    try {
      await ref.read(scheduleDatabaseProvider).resetLocalData();
      ref.invalidate(appPreferencesProvider);
      ref.invalidate(scheduleItemsProvider);
      ref.invalidate(workCodeLegendsProvider);
      ref.invalidate(supervisorProfilesProvider);
      ref.invalidate(academicTermsProvider);
      ref.invalidate(scheduleImportHistoryProvider);
      if (mounted) {
        _showMessage(
          'StudyShift was reset on this device. External calendar entries were not changed.',
        );
      }
    } on Object catch (_) {
      if (mounted) {
        _showMessage(
          'The reset could not be completed. Your local data was not cleared.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<String?> _askForPassphrase({required bool confirm}) =>
      showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (context) => _PassphraseDialog(confirm: confirm),
      );

  Future<_RestoreChoice?> _chooseRestore(
    int count,
    int legendCount,
    int termCount,
    int supervisorCount,
    DateTime createdAt,
  ) => showDialog<_RestoreChoice>(
    context: context,
    builder: (context) {
      final date = MaterialLocalizations.of(context)
          .formatMediumDate(createdAt.toLocal());
      return AlertDialog(
        title: const Text('Review this backup'),
        content: Text(
          'Created $date · $count ${count == 1 ? 'event' : 'events'} · $termCount ${termCount == 1 ? 'academic term' : 'academic terms'} · $legendCount ${legendCount == 1 ? 'roster code' : 'roster codes'} · $supervisorCount ${supervisorCount == 1 ? 'supervisor' : 'supervisors'}. Nothing changes until you choose.\n\nMerge adds new IDs and keeps anything already saved. Replace deletes every event, academic term, roster code and supervisor contact on this device, then installs the backup. This cannot be undone in the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _RestoreChoice.merge),
            child: const Text('Merge new events'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, _RestoreChoice.replace),
            child: const Text('Replace schedule'),
          ),
        ],
      );
    },
  );

  void _showMessage(String message, {bool isError = false}) {
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
  }

  String _safeError(Object error) {
    if (error is FormatException) return error.message;
    if (error is PlatformException) {
      return error.message ?? 'The backup file could not be accessed.';
    }
    return 'The backup could not be completed. Your saved schedule is unchanged.';
  }

  String _restoreSummary(ScheduleRestoreResult result, _RestoreChoice choice) {
    if (choice == _RestoreChoice.replace) {
      return 'Schedule replaced: ${result.inserted} ${result.inserted == 1 ? 'event' : 'events'} restored.';
    }
    return 'Backup merged: ${result.inserted} added; ${result.skipped} already saved and kept unchanged.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & restore')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            'Keep a safe copy',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Backups stay under your control. Choose where the file is saved or opened with the Android document picker.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline_rounded, size: 26),
                  const SizedBox(height: 12),
                  Text(
                    'Encrypted schedule backup',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your event details are encrypted with a passphrase before the file picker opens. The passphrase is never stored.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _working ? null : _createBackup,
                    icon: const Icon(Icons.save_alt_rounded),
                    label: const Text('Create backup'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.restore_rounded, size: 26),
                  const SizedBox(height: 12),
                  Text(
                    'Restore a schedule',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'The backup is checked and unlocked before any saved event changes. Review it, then merge new events or replace the schedule.',
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _restoreBackup,
                    icon: const Icon(Icons.folder_open_rounded),
                    label: const Text('Choose backup file'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            color: palette.errorContainer.withValues(alpha: .35),
            child: Padding(
              padding: const EdgeInsets.all(StudyShiftSpacing.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.restart_alt_rounded, color: palette.error),
                  const SizedBox(height: 12),
                  Text(
                    'Start over',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Reset StudyShift on this device. This removes your saved schedule, codes, supervisor contacts, terms, import history and preferences.',
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _working ? null : _resetAppData,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Reset app data'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: palette.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_working) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Working with your local backup…'),
          ],
          if (_message != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Card(
                color: _messageIsError
                    ? palette.errorContainer
                    : palette.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_message!),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.key_outlined),
            title: Text('Keep the passphrase safe'),
            subtitle: Text(
              'It cannot be recovered. A backup file without its passphrase cannot be restored.',
            ),
          ),
        ],
      ),
    );
  }
}

class _FactoryResetConfirmDialog extends StatefulWidget {
  const _FactoryResetConfirmDialog();

  @override
  State<_FactoryResetConfirmDialog> createState() =>
      _FactoryResetConfirmDialogState();
}

class _FactoryResetConfirmDialogState
    extends State<_FactoryResetConfirmDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Confirm factory reset'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Type StudyShift to confirm.'),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmation,
          autofocus: true,
          autocorrect: false,
          enableSuggestions: false,
          decoration: const InputDecoration(
            labelText: 'Type StudyShift to confirm',
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: Theme.of(context).colorScheme.onError,
        ),
        onPressed: _confirmation.text == 'StudyShift'
            ? () => Navigator.pop(context, true)
            : null,
        child: const Text('Reset permanently'),
      ),
    ],
  );
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.confirm});

  final bool confirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passphrase = TextEditingController();
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _passphrase.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirm ? 'Protect your backup' : 'Unlock your backup'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _passphrase,
            autofocus: true,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Passphrase',
              helperText: widget.confirm ? 'Use at least 12 characters.' : null,
            ),
            validator: (value) {
              final length = value?.trim().length ?? 0;
              if (length < 12) return 'Use at least 12 characters.';
              if ((value?.length ?? 0) > 256) {
                return 'Use 256 characters or fewer.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (!widget.confirm && _formKey.currentState!.validate()) {
                Navigator.pop(context, _passphrase.text);
              }
            },
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmation,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Confirm passphrase',
              ),
              validator: (value) => value != _passphrase.text
                  ? 'Passphrases do not match.'
                  : null,
              onFieldSubmitted: (_) {
                if (_formKey.currentState!.validate()) {
                  Navigator.pop(context, _passphrase.text);
                }
              },
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_formKey.currentState!.validate()) {
            Navigator.pop(context, _passphrase.text);
          }
        },
        child: Text(widget.confirm ? 'Create encrypted file' : 'Unlock'),
      ),
    ],
  );
}
