import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shift_study/data/schedule_database.dart';
import 'package:shift_study/data/supervisor_repository.dart';
import 'package:shift_study/domain/supervisor_profile.dart';

void main() {
  test('supervisor profiles persist, update, sort, and delete', () async {
    final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final repository = SupervisorRepository(database);
    const acting = SupervisorProfile(
      id: 'synthetic-supervisor-b',
      name: 'Morgan Sample',
      type: SupervisorType.acting,
      phone: '555-0102',
      notes: 'Synthetic QA contact',
    );
    const permanent = SupervisorProfile(
      id: 'synthetic-supervisor-a',
      name: 'Alex Example',
      type: SupervisorType.permanent,
    );

    await repository.save(acting);
    await repository.save(permanent);
    await repository.save(acting.copyWith(phone: '555-0103'));

    expect(await repository.getItems(), [
      permanent,
      acting.copyWith(phone: '555-0103'),
    ]);
    await expectLater(
      repository.save(const SupervisorProfile(id: 'bad', name: '')),
      throwsA(isA<FormatException>()),
    );
    await repository.delete(acting.id);
    expect(await repository.getItems(), [permanent]);
  });

  test(
    'restore merges existing profiles and replace removes old profiles',
    () async {
      final database = ScheduleDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final repository = SupervisorRepository(database);
      const oldProfile = SupervisorProfile(
        id: 'synthetic-old-supervisor',
        name: 'Old Sample',
      );
      const newProfile = SupervisorProfile(
        id: 'synthetic-new-supervisor',
        name: 'New Sample',
      );
      await repository.save(oldProfile);

      await repository.restoreItems([newProfile], replaceExisting: false);
      expect(await repository.getItems(), [newProfile, oldProfile]);
      await repository.restoreItems([newProfile], replaceExisting: true);
      expect(await repository.getItems(), [newProfile]);
    },
  );
}
