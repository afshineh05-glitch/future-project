import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/daily_activity_state.dart';
import 'package:future_project/services/daily_activity_state_service.dart';

class _Store implements DailyActivityStateStore {
  int syncCalls = 0;
  List<DailyActivityRecord> lastSynced = const [];
  Set<DailyActivityType> lastObservedTypes = const {};
  bool failNutrition = false;
  bool switchAccountDuringLoad = false;
  String? userId = 'user-1';
  DateTime? workoutStart;
  DateTime? workoutEnd;
  List<Map<String, dynamic>> workoutRows = [
    {'id': 'session-1', 'status': 'completed', 'training_day_id': 'day-1'},
  ];

  @override
  String? get currentUserId => userId;

  @override
  Future<List<Map<String, dynamic>>> loadWorkouts(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    workoutStart = start;
    workoutEnd = end;
    return workoutRows;
  }

  @override
  Future<List<Map<String, dynamic>>> loadNutrition(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    if (failNutrition) throw StateError('missing table');
    return [
      {'id': 'meal-1'},
      {'id': 'meal-2'},
    ];
  }

  @override
  Future<Map<String, dynamic>?> loadReflection(
    String userId,
    DateTime localDate,
  ) async => {'id': 'reflection-1', 'reflection_value': 'yes'};

  @override
  Future<Map<String, dynamic>?> loadWeeklyMission(
    String userId,
    DateTime localDate,
  ) async => null;

  @override
  Future<Map<String, dynamic>?> loadDailyDecision(
    String userId,
    DateTime localDate,
  ) async => null;

  @override
  Future<String?> loadVisionIdentity(String userId) async {
    if (switchAccountDuringLoad) this.userId = 'user-2';
    return 'a consistent athlete';
  }

  @override
  Future<List<DailyActivityRecord>> sync(
    DateTime localDate,
    List<DailyActivityRecord> activities,
    Set<DailyActivityType> observedTypes,
    DateTime syncedAt,
  ) async {
    syncCalls++;
    lastSynced = activities;
    lastObservedTypes = observedTypes;
    return activities;
  }
}

void main() {
  test(
    'reads authoritative completion sources into stable identities',
    () async {
      final store = _Store();
      final service = DailyActivityStateService(
        store: store,
        clock: () => DateTime(2026, 9, 15, 12),
      );
      final first = await service.loadToday();
      final second = await service.loadToday();

      expect(first.hasCompleted(DailyActivityType.workout), isTrue);
      expect(first.hasCompleted(DailyActivityType.nutrition), isTrue);
      expect(first.hasCompleted(DailyActivityType.reflection), isTrue);
      expect(
        first.activities.map((item) => item.activityIdentity),
        containsAll([
          'workout:session-1',
          'nutrition:daily',
          'reflection:daily',
        ]),
      );
      expect(
        second.activities.map((item) => item.activityIdentity),
        first.activities.map((item) => item.activityIdentity),
      );
      expect(store.syncCalls, 2);
      expect(store.workoutStart, DateTime(2026, 9, 15));
      expect(store.workoutEnd, DateTime(2026, 9, 16));
    },
  );

  test(
    'one missing optional source does not hide other completion state',
    () async {
      final store = _Store()..failNutrition = true;
      final result = await DailyActivityStateService(
        store: store,
        clock: () => DateTime(2026, 9, 15, 12),
      ).loadToday();

      expect(result.coverage.nutritionAvailable, isFalse);
      expect(
        store.lastObservedTypes,
        isNot(contains(DailyActivityType.nutrition)),
      );
      expect(result.hasCompleted(DailyActivityType.workout), isTrue);
      expect(result.hasCompleted(DailyActivityType.reflection), isTrue);
    },
  );

  test(
    'partial and skipped workouts remain distinct and do not complete',
    () async {
      final store = _Store()
        ..workoutRows = [
          {'id': 'partial', 'status': 'partial'},
          {'id': 'skipped', 'status': 'skipped'},
        ];
      final result = await DailyActivityStateService(
        store: store,
        clock: () => DateTime(2026, 9, 15, 12),
      ).loadToday();

      expect(result.hasCompleted(DailyActivityType.workout), isFalse);
      expect(
        result.ofType(DailyActivityType.workout).map((item) => item.status),
        containsAll([DailyActivityStatus.partial, DailyActivityStatus.skipped]),
      );
    },
  );

  test('account switch prevents persistence of stale source results', () async {
    final store = _Store()..switchAccountDuringLoad = true;
    await DailyActivityStateService(
      store: store,
      clock: () => DateTime(2026, 9, 15, 12),
    ).loadToday();

    expect(store.syncCalls, 0);
  });
}
