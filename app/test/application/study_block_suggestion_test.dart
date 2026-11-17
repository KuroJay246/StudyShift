import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/application/day_availability.dart';
import 'package:shift_study/application/study_block_suggestion.dart';

void main() {
  test(
    'suggestion starts at a full minute and stays inside available time',
    () {
      final start = DateTime(2026, 11, 16, 9, 0, 15);
      final suggestion = StudyBlockSuggestion.firstIn([
        AvailablePeriod(
          start: start,
          end: start.add(const Duration(minutes: 90)),
        ),
      ]);

      expect(suggestion, isNotNull);
      expect(suggestion!.startMinute, 9 * 60 + 1);
      expect(suggestion.endMinute, 10 * 60 + 1);
    },
  );

  test('no suggestion is made when no available period fits one hour', () {
    final start = DateTime(2026, 11, 16, 9);

    expect(
      StudyBlockSuggestion.firstIn([
        AvailablePeriod(
          start: start,
          end: start.add(const Duration(minutes: 59)),
        ),
      ]),
      isNull,
    );
  });
}
