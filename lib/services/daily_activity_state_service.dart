import 'package:future_project/models/daily_activity_state.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DailyActivitySourceResult<T> {
  final T value;
  final bool available;
  const DailyActivitySourceResult(this.value, this.available);
}

abstract interface class DailyActivityStateStore {
  String? get currentUserId;
  Future<List<Map<String, dynamic>>> loadWorkouts(
    String userId,
    DateTime start,
    DateTime end,
  );
  Future<List<Map<String, dynamic>>> loadNutrition(
    String userId,
    DateTime start,
    DateTime end,
  );
  Future<Map<String, dynamic>?> loadReflection(
    String userId,
    DateTime localDate,
  );
  Future<Map<String, dynamic>?> loadWeeklyMission(
    String userId,
    DateTime localDate,
  );
  Future<Map<String, dynamic>?> loadDailyDecision(
    String userId,
    DateTime localDate,
  );
  Future<String?> loadVisionIdentity(String userId);
  Future<List<DailyActivityRecord>> sync(
    DateTime localDate,
    List<DailyActivityRecord> activities,
    Set<DailyActivityType> observedTypes,
    DateTime syncedAt,
  );
}

class SupabaseDailyActivityStateStore implements DailyActivityStateStore {
  final SupabaseClient _supabase;
  SupabaseDailyActivityStateStore(this._supabase);

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<List<Map<String, dynamic>>> loadWorkouts(
    String userId,
    DateTime start,
    DateTime end,
  ) async =>
      (await _supabase
              .from('workout_sessions')
              .select('id,scheduled_at,completed_at,status,training_day_id')
              .eq('user_id', userId)
              .gte('scheduled_at', start.toUtc().toIso8601String())
              .lt('scheduled_at', end.toUtc().toIso8601String()))
          .cast<Map<String, dynamic>>();

  @override
  Future<List<Map<String, dynamic>>> loadNutrition(
    String userId,
    DateTime start,
    DateTime end,
  ) async =>
      (await _supabase
              .from('nutrition_food_logs')
              .select('id,consumed_at')
              .eq('user_id', userId)
              .gte('consumed_at', start.toUtc().toIso8601String())
              .lt('consumed_at', end.toUtc().toIso8601String()))
          .cast<Map<String, dynamic>>();

  @override
  Future<Map<String, dynamic>?> loadReflection(
    String userId,
    DateTime localDate,
  ) => _supabase
      .from('vision_daily_reflections')
      .select('id,reflection_date,reflection_value')
      .eq('user_id', userId)
      .eq('reflection_date', _date(localDate))
      .maybeSingle();

  @override
  Future<Map<String, dynamic>?> loadWeeklyMission(
    String userId,
    DateTime localDate,
  ) async {
    final row = await _supabase
        .from('coach_weekly_plans')
        .select('week_start,week_end,mission_type,mission_title')
        .eq('user_id', userId)
        .lte('week_start', _date(localDate))
        .gte('week_end', _date(localDate))
        .order('week_start', ascending: false)
        .limit(1)
        .maybeSingle();
    return row;
  }

  @override
  Future<Map<String, dynamic>?> loadDailyDecision(
    String userId,
    DateTime localDate,
  ) => _supabase
      .from('coach_daily_decisions')
      .select('local_date,decision')
      .eq('user_id', userId)
      .eq('local_date', _date(localDate))
      .maybeSingle();

  @override
  Future<String?> loadVisionIdentity(String userId) async {
    final row = await _supabase
        .from('vision_profiles')
        .select('future_identity')
        .eq('user_id', userId)
        .maybeSingle();
    return row?['future_identity']?.toString();
  }

  @override
  Future<List<DailyActivityRecord>> sync(
    DateTime localDate,
    List<DailyActivityRecord> activities,
    Set<DailyActivityType> observedTypes,
    DateTime syncedAt,
  ) async {
    final rows = await _supabase.rpc(
      'sync_daily_activity_state_v1',
      params: {
        'p_local_date': _date(localDate),
        'p_activities': activities
            .map(
              (activity) => {
                'activity_identity': activity.activityIdentity,
                'activity_type': activity.type.name,
                'status': activity.status.name,
                'source_table': activity.sourceTable,
                'source_id': activity.sourceId,
                'observation_count': activity.observationCount,
                'metadata': activity.metadata,
              },
            )
            .toList(),
        'p_observed_types': observedTypes.map((type) => type.name).toList(),
        'p_synced_at': syncedAt.toUtc().toIso8601String(),
      },
    );
    return (rows as List)
        .map(
          (row) => DailyActivityRecord.fromMap(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList(growable: false);
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class DailyActivityStateService {
  final DailyActivityStateStore _store;
  final DateTime Function() _clock;

  DailyActivityStateService({
    SupabaseClient? supabase,
    DailyActivityStateStore? store,
    DateTime Function()? clock,
  }) : _store =
           store ??
           SupabaseDailyActivityStateStore(
             supabase ?? Supabase.instance.client,
           ),
       _clock = clock ?? DateTime.now;

  Future<DailyActivityState> loadToday() async {
    final userId = _store.currentUserId;
    if (userId == null) {
      throw StateError('Sign in to load today’s activity state.');
    }
    final now = _clock().toLocal();
    final day = DateTime(now.year, now.month, now.day);
    // Calendar construction stays correct across 23/25-hour DST days.
    final end = DateTime(day.year, day.month, day.day + 1);

    final workouts = await _optional(
      () => _store.loadWorkouts(userId, day, end),
      <Map<String, dynamic>>[],
    );
    final nutrition = await _optional(
      () => _store.loadNutrition(userId, day, end),
      <Map<String, dynamic>>[],
    );
    final reflection = await _optional(
      () => _store.loadReflection(userId, day),
      null,
    );
    final weekly = await _optional(
      () => _store.loadWeeklyMission(userId, day),
      null,
    );
    final decision = await _optional(
      () => _store.loadDailyDecision(userId, day),
      null,
    );
    final vision = await _optional(
      () => _store.loadVisionIdentity(userId),
      null,
    );
    final activities = <DailyActivityRecord>[
      ...workouts.value.map((row) => _workout(day, row)),
      if (nutrition.value.isNotEmpty)
        DailyActivityRecord(
          localDate: day,
          activityIdentity: 'nutrition:daily',
          type: DailyActivityType.nutrition,
          status: DailyActivityStatus.completed,
          sourceTable: 'nutrition_food_logs',
          sourceId: nutrition.value.first['id']?.toString(),
          observationCount: nutrition.value.length,
        ),
      if (reflection.value != null)
        DailyActivityRecord(
          localDate: day,
          activityIdentity: 'reflection:daily',
          type: DailyActivityType.reflection,
          status: DailyActivityStatus.completed,
          sourceTable: 'vision_daily_reflections',
          sourceId: reflection.value!['id']?.toString(),
          metadata: {'reflection_value': reflection.value!['reflection_value']},
        ),
      if (weekly.value != null)
        DailyActivityRecord(
          localDate: day,
          activityIdentity: 'weekly_mission:${weekly.value!['week_start']}',
          type: DailyActivityType.weeklyMission,
          status: DailyActivityStatus.recorded,
          sourceTable: 'coach_weekly_plans',
          sourceId: weekly.value!['week_start']?.toString(),
          metadata: {
            'mission_type': weekly.value!['mission_type'],
            'mission_title': weekly.value!['mission_title'],
          },
        ),
      if (decision.value != null)
        DailyActivityRecord(
          localDate: day,
          activityIdentity: 'daily_decision',
          type: DailyActivityType.dailyDecision,
          status: DailyActivityStatus.recorded,
          sourceTable: 'coach_daily_decisions',
          sourceId: decision.value!['local_date']?.toString(),
          metadata: {'decision': decision.value!['decision']},
        ),
    ];

    var canonical = activities;
    try {
      if (_store.currentUserId != userId) {
        throw StateError('Account changed while activity state was loading.');
      }
      canonical = await _store.sync(day, activities, {
        if (workouts.available) DailyActivityType.workout,
        if (nutrition.available) DailyActivityType.nutrition,
        if (reflection.available) DailyActivityType.reflection,
        if (weekly.available) DailyActivityType.weeklyMission,
        if (decision.available) DailyActivityType.dailyDecision,
      }, now);
    } catch (_) {
      // A missing migration or sync outage must not hide live source truth.
    }
    return DailyActivityState(
      localDate: day,
      activities: List.unmodifiable(canonical),
      coverage: DailyActivityCoverage(
        workoutAvailable: workouts.available,
        nutritionAvailable: nutrition.available,
        reflectionAvailable: reflection.available,
        weeklyMissionAvailable: weekly.available,
        dailyDecisionAvailable: decision.available,
        visionAvailable: vision.available,
      ),
      visionIdentity: vision.value,
      generatedAt: now,
    );
  }

  DailyActivityRecord _workout(DateTime day, Map<String, dynamic> row) {
    final status = switch (row['status']?.toString()) {
      'completed' => DailyActivityStatus.completed,
      'partial' => DailyActivityStatus.partial,
      'skipped' => DailyActivityStatus.skipped,
      _ => DailyActivityStatus.planned,
    };
    return DailyActivityRecord(
      localDate: day,
      activityIdentity: 'workout:${row['id']}',
      type: DailyActivityType.workout,
      status: status,
      sourceTable: 'workout_sessions',
      sourceId: row['id']?.toString(),
      metadata: {'training_day_id': row['training_day_id']},
    );
  }

  Future<DailyActivitySourceResult<T>> _optional<T>(
    Future<T> Function() load,
    T fallback,
  ) async {
    try {
      return DailyActivitySourceResult(await load(), true);
    } catch (_) {
      return DailyActivitySourceResult(fallback, false);
    }
  }
}
