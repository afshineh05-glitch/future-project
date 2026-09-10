import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/weekly_coach_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class WeeklyCoachStore {
  String? get currentUserId;
  Future<WeeklyCoachPlan?> loadForWeek(DateTime weekStart);
  Future<List<WearableDailyRecord>> loadWearableHistory(DateTime since);
  Future<List<WeeklyWorkoutObservation>> loadWorkoutHistory(DateTime since);
  Future<String> loadPrimaryGoal();
  Future<WeeklyCoachPlan> upsert(WeeklyCoachPlan plan);
}

class SupabaseWeeklyCoachStore implements WeeklyCoachStore {
  final SupabaseClient _supabase;
  SupabaseWeeklyCoachStore(this._supabase);

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  String get _userId {
    final value = currentUserId;
    if (value == null) throw StateError('Sign in to use Weekly Coach.');
    return value;
  }

  @override
  Future<WeeklyCoachPlan?> loadForWeek(DateTime weekStart) async {
    if (currentUserId == null) return null;
    final row = await _supabase
        .from('coach_weekly_plans')
        .select()
        .eq('user_id', _userId)
        .eq('week_start', WeeklyCoachPlan.dateKey(weekStart))
        .maybeSingle();
    return row == null ? null : WeeklyCoachPlan.fromMap(row);
  }

  @override
  Future<List<WearableDailyRecord>> loadWearableHistory(DateTime since) async {
    final rows = await _supabase
        .from('wearable_daily_records')
        .select()
        .eq('user_id', _userId)
        .gte('local_date', WeeklyCoachPlan.dateKey(since))
        .order('local_date');
    return rows.map(WearableDailyRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<WeeklyWorkoutObservation>> loadWorkoutHistory(
    DateTime since,
  ) async {
    final rows = await _supabase
        .from('workout_sessions')
        .select('scheduled_at,status')
        .eq('user_id', _userId)
        .gte('scheduled_at', since.toUtc().toIso8601String());
    return rows
        .map(
          (row) => WeeklyWorkoutObservation(
            DateTime.parse(row['scheduled_at'].toString()).toLocal(),
            row['status']?.toString() ?? '',
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<String> loadPrimaryGoal() async {
    final row = await _supabase
        .from('user_foundations')
        .select('primary_goal')
        .eq('user_id', _userId)
        .maybeSingle();
    return row?['primary_goal']?.toString() ?? '';
  }

  @override
  Future<WeeklyCoachPlan> upsert(WeeklyCoachPlan plan) async {
    final rows = await _supabase.rpc(
      'save_coach_weekly_plan',
      params: {
        'p_week_start': WeeklyCoachPlan.dateKey(plan.weekStart),
        'p_week_end': WeeklyCoachPlan.dateKey(plan.weekEnd),
        'p_short_retrospective': plan.shortRetrospective,
        'p_biggest_win': plan.biggestWin,
        'p_main_limiting_factor': plan.mainLimitingFactor,
        'p_mission_type': WeeklyCoachPlan.missionKey(plan.missionType),
        'p_mission_title': plan.missionTitle,
        'p_mission_reason': plan.missionReason,
        'p_action_items': plan.actionItems,
        'p_motivation_context': plan.motivationContext,
        'p_previous_mission_title': plan.previousMissionTitle,
        'p_previous_mission_outcome': WeeklyCoachPlan.outcomeKey(
          plan.previousMissionOutcome,
        ),
        'p_follow_up_message': plan.followUpMessage,
        'p_wearable_days': plan.dataCoverage.wearableDays,
        'p_workout_source_available': plan.dataCoverage.workoutSourceAvailable,
        'p_evidence': plan.evidence,
        'p_generated_at': plan.generatedAt.toUtc().toIso8601String(),
      },
    );
    if (rows is! List || rows.isEmpty) {
      throw StateError('Weekly Coach plan was not saved.');
    }
    return WeeklyCoachPlan.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}

class WeeklyCoachService {
  final WeeklyCoachStore _store;
  final WeeklyCoachEngine _engine;
  final DateTime Function() _clock;

  WeeklyCoachService({
    SupabaseClient? supabase,
    WeeklyCoachStore? store,
    WeeklyCoachEngine engine = const WeeklyCoachEngine(),
    DateTime Function()? clock,
  }) : _store =
           store ??
           SupabaseWeeklyCoachStore(supabase ?? Supabase.instance.client),
       _engine = engine,
       _clock = clock ?? DateTime.now;

  DateTime _weekStart(DateTime value) {
    final local = value.toLocal();
    final date = DateTime(local.year, local.month, local.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  /// Read-only integration point for Today’s Coach.
  Future<WeeklyCoachPlan?> loadCurrentPlan() =>
      _store.loadForWeek(_weekStart(_clock()));

  Future<WeeklyCoachPlan> generateAndSave() async {
    if (_store.currentUserId == null) {
      throw StateError('Sign in to use Weekly Coach.');
    }
    final now = _clock();
    final start = _weekStart(now);
    final since = start.subtract(const Duration(days: 35));
    List<WearableDailyRecord> wearable = const [];
    List<WeeklyWorkoutObservation> workouts = const [];
    var workoutAvailable = true;
    try {
      wearable = await _store.loadWearableHistory(since);
    } catch (_) {
      wearable = const [];
    }
    try {
      workouts = await _store.loadWorkoutHistory(since);
    } catch (_) {
      workoutAvailable = false;
    }
    String goal = '';
    try {
      goal = await _store.loadPrimaryGoal();
    } catch (_) {
      goal = '';
    }
    final previous = await _store.loadForWeek(
      start.subtract(const Duration(days: 7)),
    );
    final plan = _engine.evaluate(
      WeeklyCoachInput(
        now: now,
        wearableHistory: wearable,
        workouts: workouts,
        workoutSourceAvailable: workoutAvailable,
        primaryGoal: goal,
        previousPlan: previous,
      ),
    );
    return _store.upsert(plan);
  }
}
