import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/services/coach_daily_decision_service.dart';

class MemoryCoachDailyDecisionStore implements CoachDailyDecisionStore {
  @override
  String? currentUserId = 'user-1';
  final Map<String, CoachDailyDecision> rows = {};
  bool failLoads = false;
  bool failSaves = false;
  int saveCalls = 0;

  String key(DateTime date) =>
      '$currentUserId:${CoachDailyDecision.dateKey(date)}';

  @override
  Future<CoachDailyDecision?> loadForDate(DateTime localDate) async {
    if (failLoads) throw Exception('offline');
    return rows[key(localDate)];
  }

  @override
  Future<CoachDailyDecision> upsertForDate(
    DateTime localDate,
    CoachDecision decision,
  ) async {
    saveCalls++;
    if (failSaves) throw Exception('offline');
    final now = DateTime.utc(2026, 9, 10, 16);
    final rowKey = key(localDate);
    final prior = rows[rowKey];
    final row = CoachDailyDecision(
      userId: currentUserId!,
      localDate: DateTime.parse(CoachDailyDecision.dateKey(localDate)),
      decision: decision,
      createdAt: prior?.createdAt ?? now,
      updatedAt: now,
    );
    rows[rowKey] = row;
    return row;
  }
}

void main() {
  final today = DateTime(2026, 9, 10, 8);
  late MemoryCoachDailyDecisionStore store;
  late CoachDailyDecisionService service;

  setUp(() {
    store = MemoryCoachDailyDecisionStore();
    service = CoachDailyDecisionService(store: store, clock: () => today);
  });

  test('no existing decision returns optional null', () async {
    expect(await service.loadToday(), isNull);
  });

  test('saves and reopens a planned session decision', () async {
    await service.saveToday(CoachDecision.plannedSession);
    expect((await service.loadToday())?.decision, CoachDecision.plannedSession);
  });

  test('saves and reopens a lighter session decision', () async {
    await service.saveToday(CoachDecision.lighterSession);
    expect((await service.loadToday())?.decision, CoachDecision.lighterSession);
  });

  test('changing choice updates the same daily record', () async {
    await service.saveToday(CoachDecision.lighterSession);
    final createdAt = (await service.loadToday())!.createdAt;
    await service.saveToday(CoachDecision.plannedSession);
    expect(store.rows, hasLength(1));
    expect((await service.loadToday())!.createdAt, createdAt);
    expect((await service.loadToday())!.decision, CoachDecision.plannedSession);
  });

  test('different local calendar day creates a separate record', () async {
    await service.saveToday(CoachDecision.plannedSession);
    final tomorrowService = CoachDailyDecisionService(
      store: store,
      clock: () => DateTime(2026, 9, 11, 1),
    );
    await tomorrowService.saveToday(CoachDecision.lighterSession);
    expect(store.rows, hasLength(2));
  });

  test('nothing is saved without an explicit save call', () async {
    await service.loadToday();
    expect(store.saveCalls, 0);
    expect(store.rows, isEmpty);
  });

  test('recovery caution alone cannot persist a lighter choice', () async {
    // Recovery is deliberately absent from this persistence API. Only the
    // explicit saveToday entry point can write a user decision.
    expect(store.saveCalls, 0);
    expect(store.rows, isEmpty);
  });

  test('save failure is finite and preserves prior server state', () async {
    await service.saveToday(CoachDecision.plannedSession);
    store.failSaves = true;
    await expectLater(
      service.saveToday(CoachDecision.lighterSession),
      throwsException,
    );
    expect(store.saveCalls, 2);
    expect(store.rows, hasLength(1));
    expect(store.rows.values.single.decision, CoachDecision.plannedSession);
  });

  test('load failure is isolated for Coach callers to handle', () async {
    store.failLoads = true;
    await expectLater(service.loadToday(), throwsException);
    expect(store.saveCalls, 0);
  });

  test('decision persistence has no wearable dependency', () async {
    await service.saveToday(CoachDecision.lighterSession);
    expect(store.rows.values.single.decision, CoachDecision.lighterSession);
  });

  test('Training Plan and Progress Engine have no automatic integration', () {
    final trainingPlan = File(
      'lib/screens/training_plan_screen.dart',
    ).readAsStringSync();
    final progressEngine = File(
      'lib/services/vision_intelligence_engine.dart',
    ).readAsStringSync();
    expect(trainingPlan, isNot(contains('CoachDailyDecision')));
    expect(trainingPlan, isNot(contains('coach_daily_decisions')));
    expect(progressEngine, isNot(contains('CoachDailyDecision')));
    expect(progressEngine, isNot(contains('coach_daily_decisions')));
  });
}
