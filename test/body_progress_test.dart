import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/body_progress.dart';
import 'package:future_project/services/body_progress_service.dart';

void main() {
  final baseline = BodyProgressBaseline(
    measurements: measurements(80),
    establishedAt: DateTime(2026, 8, 1),
  );

  test('check history records parse and preserve newest-first ordering', () {
    final rows = [
      checkRow('new', 79, DateTime.utc(2026, 8, 30, 12)),
      checkRow('old', 80, DateTime.utc(2026, 8, 9, 12)),
    ];
    final history = rows.map(BodyProgressCheck.fromMap).toList();

    expect(history, hasLength(2));
    expect(history.first.id, 'new');
    expect(history.first.measurements.waistCm, 84);
    expect(history.first.checkedAt.isAfter(history.last.checkedAt), isTrue);
    expect(history.first.updatedAt, DateTime.utc(2026, 8, 30, 12));
  });

  test('numeric values returned as Postgres strings are parsed safely', () {
    final check = BodyProgressCheck.fromMap({
      'id': 'string-numeric',
      'user_id': 'user',
      'weight': '78.0',
      'waist': '88',
      'chest': '110',
      'hips': '100',
      'arm': '39',
      'thigh': '60',
      'neck': '40',
      'checked_at': '2026-08-30T12:00:00Z',
      'created_at': '2026-08-30T12:00:00Z',
      'updated_at': '2026-08-30T12:00:00Z',
    });

    expect(check.measurements.weightKg, 78);
    expect(check.measurements.chestCm, 110);
    expect(check.measurements.armCm, 39);
  });

  group('Body Progress cycle', () {
    final baselineAt = DateTime(2026, 8, 1);

    test('is upcoming before entering week four', () {
      final cycle = BodyProgressCycle.calculate(
        baselineAt: baselineAt,
        now: DateTime(2026, 8, 21),
      );
      expect(cycle.status, BodyProgressCycleStatus.upcoming);
      expect(cycle.dueAt, DateTime(2026, 8, 22));
      expect(cycle.windowEndsAt, DateTime(2026, 8, 27));
    });

    test('becomes due when entering week four', () {
      final cycle = BodyProgressCycle.calculate(
        baselineAt: baselineAt,
        now: DateTime(2026, 8, 22),
      );
      expect(cycle.status, BodyProgressCycleStatus.due);
    });

    test('submission resets cycle from submitted date', () {
      final cycle = BodyProgressCycle.calculate(
        baselineAt: baselineAt,
        latestCheckAt: DateTime(2026, 8, 24),
        now: DateTime(2026, 8, 25),
      );
      expect(cycle.status, BodyProgressCycleStatus.completed);
      expect(cycle.dueAt, DateTime(2026, 9, 14));
      expect(cycle.windowEndsAt, DateTime(2026, 9, 19));
    });
  });

  group('current-cycle persistence', () {
    test('first check creates one persisted record', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);

      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(79),
        now: DateTime(2026, 8, 22),
      );

      expect(store.insertCount, 1);
      expect(store.updateCount, 0);
      expect(await service.loadHistory(), hasLength(1));
    });

    test('editing current-cycle check updates instead of inserting', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);
      final original = await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: const [],
        measurements: measurements(79),
        note: 'Original',
        now: DateTime(2026, 8, 22),
      );

      final edited = await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(78.5),
        note: 'Edited',
        now: DateTime(2026, 8, 23),
      );

      expect(store.insertCount, 1);
      expect(store.updateCount, 1);
      expect(await service.loadHistory(), hasLength(1));
      expect(edited.id, original.id);
      expect(edited.measurements.weightKg, 78.5);
      expect(edited.checkedAt, original.checkedAt);
      expect(edited.updatedAt.isAfter(original.updatedAt), isTrue);
    });

    test('editing does not reset the next due date', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);
      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: const [],
        measurements: measurements(79),
        now: DateTime(2026, 8, 22),
      );
      final beforeEdit = service.resolveCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        now: DateTime(2026, 8, 23),
      );

      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(78),
        now: DateTime(2026, 8, 25),
      );
      final afterEdit = service.resolveCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        now: DateTime(2026, 8, 25),
      );

      expect(afterEdit.cycle.status, BodyProgressCycleStatus.completed);
      expect(afterEdit.cycle.dueAt, beforeEdit.cycle.dueAt);
      expect(afterEdit.cycle.dueAt, DateTime(2026, 9, 12));
    });

    test('first check compares against My Foundation', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);
      final first = await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: const [],
        measurements: measurements(79),
        now: DateTime(2026, 8, 22),
      );

      final comparison = service.comparisonForCheck(
        check: first,
        history: await service.loadHistory(),
        baseline: baseline,
      );

      expect(comparison.weightKg, baseline.measurements.weightKg);
    });

    test('later check compares against the previous cycle check', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);
      final first = await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: const [],
        measurements: measurements(79),
        now: DateTime(2026, 8, 22),
      );
      final second = await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(77),
        now: DateTime(2026, 9, 12),
      );

      final comparison = service.comparisonForCheck(
        check: second,
        history: await service.loadHistory(),
        baseline: baseline,
      );

      expect(comparison.weightKg, first.measurements.weightKg);
    });

    test('repeated edits keep one history item per cycle', () async {
      final store = FakeBodyProgressStore(baseline);
      final service = BodyProgressService(store: store);
      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: const [],
        measurements: measurements(79),
        now: DateTime(2026, 8, 22),
      );
      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(78.5),
        now: DateTime(2026, 8, 23),
      );
      await service.saveCheckForCurrentCycle(
        baseline: baseline,
        history: await service.loadHistory(),
        measurements: measurements(78),
        now: DateTime(2026, 8, 24),
      );

      expect(await service.loadHistory(), hasLength(1));
      expect(store.insertCount, 1);
      expect(store.updateCount, 2);
    });

    test(
      'stale concurrent creates reuse one deterministic cycle key',
      () async {
        final store = FakeBodyProgressStore(baseline);
        final service = BodyProgressService(store: store);
        const staleHistory = <BodyProgressCheck>[];

        final first = await service.saveCheckForCurrentCycle(
          baseline: baseline,
          history: staleHistory,
          measurements: measurements(79),
          now: DateTime(2026, 8, 22),
        );
        final raced = await service.saveCheckForCurrentCycle(
          baseline: baseline,
          history: staleHistory,
          measurements: measurements(78.5),
          now: DateTime(2026, 8, 23),
        );

        expect(store.insertAttemptCount, 2);
        expect(store.insertCount, 1);
        expect(store.updateCount, 1);
        expect(await service.loadHistory(), hasLength(1));
        expect(raced.id, first.id);
        expect(raced.checkedAt, first.checkedAt);
        expect(raced.measurements.weightKg, 78.5);
      },
    );

    test('cycle-key migration preserves legacy duplicates', () {
      final sql = File(
        'supabase/migrations/202608300002_add_body_progress_cycle_key.sql',
      ).readAsStringSync().toLowerCase();

      expect(sql, contains("'legacy:' || id::text"));
      expect(sql, contains('create unique index'));
      expect(sql, contains('(user_id, cycle_key)'));
      expect(sql, isNot(contains('delete from')));
    });

    test('legacy cleanup targets only the inspected duplicate', () {
      final sql = File(
        'supabase/migrations/202608310001_cleanup_known_legacy_body_progress_duplicate.sql',
      ).readAsStringSync().toLowerCase();

      expect(sql, contains('7ef231f3-17d1-4a13-bbba-b2f0a3f3a8b1'));
      expect(sql, contains('3e6f0ca9-578b-4d1b-8723-28aa0311df3b'));
      expect(sql, contains("note = 'test progress check'"));
      expect(sql, contains('duplicate.note is null'));
      expect(sql, contains('duplicate.user_id ='));
      expect(sql, contains('delete from public.body_progress_checks'));
      expect(sql, contains('deleted_count <> 1'));
      expect(sql, isNot(contains('duplicate.updated_at')));
    });
  });
}

BodyMeasurements measurements(double weight) => BodyMeasurements(
  weightKg: weight,
  waistCm: weight + 5,
  chestCm: 100,
  hipsCm: 95,
  armCm: 35,
  thighCm: 58,
  neckCm: 38,
);

Map<String, dynamic> checkRow(String id, double weight, DateTime checkedAt) => {
  'id': id,
  'user_id': 'user',
  'weight': weight,
  'waist': 84,
  'chest': 101,
  'hips': 96,
  'arm': 35,
  'thigh': 58,
  'neck': 38,
  'checked_at': checkedAt.toIso8601String(),
  'created_at': checkedAt.toIso8601String(),
  'updated_at': checkedAt.toIso8601String(),
};

class FakeBodyProgressStore implements BodyProgressStore {
  final BodyProgressBaseline baseline;
  final List<BodyProgressCheck> _history = [];
  final Map<String, String> _cycleKeysByCheckId = {};
  int insertAttemptCount = 0;
  int insertCount = 0;
  int updateCount = 0;

  FakeBodyProgressStore(this.baseline);

  @override
  Future<BodyProgressBaseline?> loadBaseline() async => baseline;

  @override
  Future<List<BodyProgressCheck>> loadHistory() async =>
      List.unmodifiable(_history);

  @override
  Future<BodyProgressCheck> insertCheck({
    required BodyMeasurements measurements,
    required DateTime checkedAt,
    required String cycleKey,
    String? note,
  }) async {
    insertAttemptCount += 1;
    String? existingId;
    for (final entry in _cycleKeysByCheckId.entries) {
      if (entry.value == cycleKey) {
        existingId = entry.key;
        break;
      }
    }
    if (existingId != null) {
      return updateCheck(
        checkId: existingId,
        measurements: measurements,
        note: note,
      );
    }
    insertCount += 1;
    final check = BodyProgressCheck(
      id: 'check-$insertCount',
      userId: 'user',
      measurements: measurements,
      note: note,
      checkedAt: checkedAt,
      createdAt: checkedAt,
      updatedAt: checkedAt,
    );
    _cycleKeysByCheckId[check.id] = cycleKey;
    _history.insert(0, check);
    return check;
  }

  @override
  Future<BodyProgressCheck> updateCheck({
    required String checkId,
    required BodyMeasurements measurements,
    String? note,
  }) async {
    updateCount += 1;
    final index = _history.indexWhere((item) => item.id == checkId);
    final current = _history[index];
    final updated = BodyProgressCheck(
      id: current.id,
      userId: current.userId,
      measurements: measurements,
      note: note,
      checkedAt: current.checkedAt,
      createdAt: current.createdAt,
      updatedAt: current.updatedAt.add(const Duration(seconds: 1)),
    );
    _history[index] = updated;
    return updated;
  }
}
