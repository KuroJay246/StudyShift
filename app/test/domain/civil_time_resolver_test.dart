import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/domain/civil_time_resolver.dart';
import 'package:shift_study/domain/schedule.dart';

void main() {
  final resolver = CivilTimeResolver();

  test('ordinary daylight and standard times each resolve exactly once', () {
    expect(
      resolver
          .resolve(CivilDate(2026, 3, 1), 9 * 60, 'America/New_York')
          .candidates,
      hasLength(1),
    );
    expect(
      resolver
          .resolve(CivilDate(2026, 12, 1), 9 * 60, 'America/New_York')
          .candidates,
      hasLength(1),
    );
  });

  test('spring-forward wall time is marked nonexistent', () {
    final resolution = resolver.resolve(
      CivilDate(2026, 3, 8),
      2 * 60 + 30,
      'America/New_York',
    );
    expect(resolution.status, CivilTimeStatus.nonexistent);
    expect(resolution.candidates, isEmpty);
  });

  test('fall-back wall time exposes both valid instants', () {
    final resolution = resolver.resolve(
      CivilDate(2026, 11, 1),
      1 * 60 + 30,
      'America/New_York',
    );
    expect(resolution.status, CivilTimeStatus.ambiguous);
    expect(resolution.candidates, hasLength(2));
    expect(
      resolution.candidates[1].difference(resolution.candidates[0]),
      const Duration(hours: 1),
    );
    expect(resolution.select(null), isNull);
    expect(
      resolution.select(CivilTimeFoldChoice.earlier),
      resolution.candidates.first,
    );
    expect(
      resolution.select(CivilTimeFoldChoice.later),
      resolution.candidates.last,
    );
  });

  test('invalid IANA zones are returned as data errors', () {
    final resolution = resolver.resolve(
      CivilDate(2026, 11, 2),
      9 * 60,
      'Synthetic/Not_A_Zone',
    );
    expect(resolution.status, CivilTimeStatus.invalidTimeZone);
    expect(resolution.candidates, isEmpty);
  });
}
