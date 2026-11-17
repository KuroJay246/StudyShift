import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/schedule.dart';
import 'package:shift_study/presentation/schedule_format.dart';

void main() {
  group('deadline countdown labels', () {
    const today = CivilDate(2026, 11, 13);

    ScheduleItem deadline({
      required CivilDate date,
      required DeadlineType type,
      bool completed = false,
    }) => ScheduleItem(
      id: 'deadline-${type.name}-$date',
      kind: ScheduleKind.deadline,
      title: 'Synthetic deadline',
      startDate: date,
      intervals: type == DeadlineType.assignment
          ? const []
          : const [
              EventInterval(
                startDayOffset: 0,
                startMinute: 600,
                endDayOffset: 0,
                endMinute: 660,
              ),
            ],
      deadlineType: type,
      isCompleted: completed,
    );

    test('uses civil-day labels for exam and assignment', () {
      expect(
        deadlineCountdownLabel(
          deadline(date: today, type: DeadlineType.examination),
          today,
        ),
        'Exam today',
      );
      expect(
        deadlineCountdownLabel(
          deadline(date: today.addDays(1), type: DeadlineType.assignment),
          today,
        ),
        'Due tomorrow',
      );
      expect(
        deadlineCountdownLabel(
          deadline(date: today.addDays(8), type: DeadlineType.examination),
          today,
        ),
        'Exam in 8 days',
      );
    });

    test('distinguishes overdue assignments and dates that have passed', () {
      expect(
        deadlineCountdownLabel(
          deadline(date: today.addDays(-2), type: DeadlineType.assignment),
          today,
        ),
        'Overdue by 2 days',
      );
      expect(
        deadlineCountdownLabel(
          deadline(date: today.addDays(-1), type: DeadlineType.examination),
          today,
        ),
        'Exam date passed yesterday',
      );
    });

    test('completed deadlines do not show a countdown', () {
      expect(
        deadlineCountdownLabel(
          deadline(
            date: today.addDays(2),
            type: DeadlineType.assignment,
            completed: true,
          ),
          today,
        ),
        isNull,
      );
    });
  });

  test('overtime is labeled as a timed work category', () {
    expect(WorkCategory.overtime.isAllDay, isFalse);
    expect(workCategoryName(WorkCategory.overtime), 'Overtime');
  });

  testWidgets('week range stays compact on narrow phone headers', (
    tester,
  ) async {
    late MaterialLocalizations localizations;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en', 'US'),
        home: Builder(
          builder: (context) {
            localizations = MaterialLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(
      formatWeekRange(localizations, const CivilDate(2026, 11, 9)),
      'Nov 9 – 15, 2026',
    );
    expect(
      formatWeekRange(localizations, const CivilDate(2026, 11, 30)),
      'Nov 30 – Dec 6, 2026',
    );
  });
}
