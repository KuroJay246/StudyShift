import 'package:flutter/material.dart';

import '../../platform/clock_alarm_bridge.dart';

/// A user-triggered handoff to a compatible Android Clock app.
class ClockAlarmAction extends StatelessWidget {
  const ClockAlarmAction({
    super.key,
    required this.eventStart,
    required this.label,
  });

  final DateTime eventStart;
  final String label;

  Future<void> _open(BuildContext context) async {
    try {
      final opened = await const ClockAlarmBridge().openAlarm(
        eventStart: eventStart,
        label: label,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Review and confirm the alarm in your Clock app.'
                : 'No clock app can create an alarm.',
          ),
        ),
      );
    } on Object {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open a clock app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!canOfferClockAlarm(eventStart)) return const SizedBox.shrink();
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.alarm_add_outlined),
        label: const Text('Set alarm in Clock'),
      ),
    );
  }
}
