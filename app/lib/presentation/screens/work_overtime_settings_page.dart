import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/dependencies.dart';
import '../design/studyshift_spacing.dart';

class WorkOvertimeSettingsPage extends ConsumerWidget {
  const WorkOvertimeSettingsPage({super.key});

  Future<void> _editRule(
    BuildContext context,
    WidgetRef ref, {
    String? employer,
    int? thresholdMinutes,
  }) async {
    final value = await showDialog<_OvertimeRuleValue>(
      context: context,
      builder: (_) => _OvertimeRuleDialog(
        employer: employer,
        thresholdMinutes: thresholdMinutes,
      ),
    );
    if (value == null) return;
    await ref
        .read(preferencesRepositoryProvider)
        .setOvertimeThreshold(value.employer, value.thresholdMinutes);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> _removeRule(
    BuildContext context,
    WidgetRef ref,
    String employer,
  ) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove overtime rule?'),
        content: Text('Premium-hour estimates for $employer will be hidden.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep rule'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove rule'),
          ),
        ],
      ),
    );
    if (remove != true) return;
    await ref
        .read(preferencesRepositoryProvider)
        .clearOvertimeThreshold(employer);
    ref.invalidate(appPreferencesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(appPreferencesProvider).value;
    final rules = preferences?.overtimeThresholdsByEmployer.entries.toList()
      ?..sort((left, right) => left.key.compareTo(right.key));
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Work overtime rules'),
        actions: [
          IconButton(
            tooltip: 'Add employer rule',
            onPressed: () => _editRule(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          StudyShiftSpacing.pageMargin,
          StudyShiftSpacing.x3,
          StudyShiftSpacing.pageMargin,
          StudyShiftSpacing.x8,
        ),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(StudyShiftSpacing.x4),
              child: Text(
                'Set a standard-hours threshold for each employer. StudyShift '
                'uses it only for that employer’s roster when showing daily '
                'hour breakdowns. Without a saved rule, the app records extra '
                'time but does not estimate premium hours or pay.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: StudyShiftSpacing.x3),
          if (rules == null || rules.isEmpty)
            _EmptyOvertimeRules(onAdd: () => _editRule(context, ref))
          else ...[
            Text(
              'Employer rules',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: StudyShiftSpacing.x2),
            for (final rule in rules)
              Card(
                child: ListTile(
                  title: Text(
                    preferences?.overtimeEmployerLabel(rule.key) ?? rule.key,
                  ),
                  subtitle: Text(
                    '${_hoursLabel(rule.value)} standard hours per day',
                  ),
                  onTap: () => _editRule(
                    context,
                    ref,
                    employer:
                        preferences?.overtimeEmployerLabel(rule.key) ??
                        rule.key,
                    thresholdMinutes: rule.value,
                  ),
                  trailing: PopupMenuButton<String>(
                    tooltip:
                        'Manage ${preferences?.overtimeEmployerLabel(rule.key) ?? rule.key} rule',
                    onSelected: (choice) {
                      if (choice == 'edit') {
                        _editRule(
                          context,
                          ref,
                          employer:
                              preferences?.overtimeEmployerLabel(rule.key) ??
                              rule.key,
                          thresholdMinutes: rule.value,
                        );
                      } else if (choice == 'remove') {
                        _removeRule(
                          context,
                          ref,
                          preferences?.overtimeEmployerLabel(rule.key) ??
                              rule.key,
                        );
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static String _hoursLabel(int minutes) {
    final hours = minutes / 60;
    return hours == hours.roundToDouble()
        ? hours.toStringAsFixed(0)
        : hours.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
  }
}

class _OvertimeRuleValue {
  const _OvertimeRuleValue(this.employer, this.thresholdMinutes);

  final String employer;
  final int thresholdMinutes;
}

class _OvertimeRuleDialog extends StatefulWidget {
  const _OvertimeRuleDialog({this.employer, this.thresholdMinutes});

  final String? employer;
  final int? thresholdMinutes;

  @override
  State<_OvertimeRuleDialog> createState() => _OvertimeRuleDialogState();
}

class _OvertimeRuleDialogState extends State<_OvertimeRuleDialog> {
  late final TextEditingController _employerController;
  late final TextEditingController _hoursController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _employerController = TextEditingController(text: widget.employer ?? '');
    _hoursController = TextEditingController(
      text: widget.thresholdMinutes == null
          ? '8'
          : (widget.thresholdMinutes! / 60).toString(),
    );
  }

  @override
  void dispose() {
    _employerController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final minutes = (double.parse(_hoursController.text.trim()) * 60).round();
    Navigator.of(context)
        .pop(_OvertimeRuleValue(_employerController.text.trim(), minutes));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.employer == null ? 'Add employer rule' : 'Edit rule'),
    content: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _employerController,
            autofocus: widget.employer == null,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Employer name',
              hintText: 'e.g. CAH',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter an employer name'
                : null,
          ),
          const SizedBox(height: StudyShiftSpacing.x2),
          TextFormField(
            controller: _hoursController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Standard hours per day',
              suffixText: 'hours',
            ),
            validator: (value) {
              final hours = double.tryParse(value?.trim() ?? '');
              if (hours == null || hours <= 0 || hours > 24) {
                return 'Enter a value greater than 0, up to 24';
              }
              return null;
            },
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save rule')),
    ],
  );
}

class _EmptyOvertimeRules extends StatelessWidget {
  const _EmptyOvertimeRules({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(StudyShiftSpacing.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No employer rules saved',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: StudyShiftSpacing.x1),
          const Text(
            'Extra hours will still be recorded. Add a rule only when you '
            'know the standard-hours threshold for your roster.',
          ),
          const SizedBox(height: StudyShiftSpacing.x3),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add employer rule'),
          ),
        ],
      ),
    ),
  );
}
