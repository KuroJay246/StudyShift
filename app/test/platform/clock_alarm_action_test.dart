import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/presentation/widgets/clock_alarm_action.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('app.shiftstudy/clock_alarm');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  testWidgets('offers Clock handoff and reports unavailable Clock apps', (
    tester,
  ) async {
    messenger.setMockMethodCallHandler(channel, (_) async => false);
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClockAlarmAction(
            eventStart: DateTime.now().add(const Duration(hours: 1)),
            label: 'Synthetic class',
          ),
        ),
      ),
    );

    expect(find.text('Set alarm in Clock'), findsOneWidget);
    await tester.tap(find.text('Set alarm in Clock'));
    await tester.pump();
    expect(find.text('No clock app can create an alarm.'), findsOneWidget);
  });
}
