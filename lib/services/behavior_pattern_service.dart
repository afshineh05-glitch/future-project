import 'package:future_project/models/behavior_pattern.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/behavior_pattern_learning_engine.dart';
import 'package:future_project/services/health/recovery_context_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class BehaviorPatternStore {
  String? get currentUserId;
  Future<List<BehaviorTrainingSignal>> loadTraining(DateTime since);
  Future<List<DateTime>> loadNutrition(DateTime since);
  Future<List<DateTime>> loadReflections(DateTime since);
  Future<List<WearableDailyRecord>> loadWearable(DateTime since);
  Future<List<BehaviorPattern>> replaceActive(
    List<BehaviorPattern> patterns,
    DateTime learnedAt,
  );
  Future<List<BehaviorPattern>> loadActive();
}

class SupabaseBehaviorPatternStore implements BehaviorPatternStore {
  final SupabaseClient _supabase;
  SupabaseBehaviorPatternStore(this._supabase);
  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;
  String get _userId =>
      currentUserId ??
      (throw StateError('Sign in to learn behavior patterns.'));
  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<BehaviorTrainingSignal>> loadTraining(DateTime since) async {
    final rows = await _supabase
        .from('workout_sessions')
        .select(
          'scheduled_at,status,planned_duration_minutes,actual_duration_minutes',
        )
        .eq('user_id', _userId)
        .gte('scheduled_at', since.toUtc().toIso8601String());
    return rows
        .map(
          (row) => BehaviorTrainingSignal(
            scheduledAt: DateTime.parse(
              row['scheduled_at'].toString(),
            ).toLocal(),
            completed: row['status'] == 'completed',
            plannedDurationMinutes: (row['planned_duration_minutes'] as num?)
                ?.toInt(),
            actualDurationMinutes: (row['actual_duration_minutes'] as num?)
                ?.toInt(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<DateTime>> loadNutrition(DateTime since) async {
    final rows = await _supabase
        .from('nutrition_food_logs')
        .select('consumed_at')
        .eq('user_id', _userId)
        .gte('consumed_at', since.toUtc().toIso8601String());
    return rows
        .map((row) => DateTime.parse(row['consumed_at'].toString()).toLocal())
        .toList(growable: false);
  }

  @override
  Future<List<DateTime>> loadReflections(DateTime since) async {
    final rows = await _supabase
        .from('vision_daily_reflections')
        .select('reflection_date')
        .eq('user_id', _userId)
        .gte('reflection_date', _date(since));
    return rows
        .map((row) => DateTime.parse(row['reflection_date'].toString()))
        .toList(growable: false);
  }

  @override
  Future<List<WearableDailyRecord>> loadWearable(DateTime since) async {
    final rows = await _supabase
        .from('wearable_daily_records')
        .select()
        .eq('user_id', _userId)
        .gte('local_date', _date(since))
        .order('local_date');
    return rows.map(WearableDailyRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<BehaviorPattern>> replaceActive(
    List<BehaviorPattern> patterns,
    DateTime learnedAt,
  ) async {
    final payload = patterns
        .map(
          (p) => {
            'fingerprint': p.fingerprint,
            'pattern_type': p.type.name,
            'direction': p.direction.name,
            'confidence_band': p.confidenceBand.name,
            'observations': p.observations,
            'evidence': p.evidence,
            'window_start': _date(p.windowStart),
            'window_end': _date(p.windowEnd),
            'coach_hint': p.coachHint,
          },
        )
        .toList();
    final rows = await _supabase.rpc(
      'replace_behavior_patterns_v1',
      params: {
        'p_patterns': payload,
        'p_learned_at': learnedAt.toUtc().toIso8601String(),
      },
    );
    return (rows as List)
        .map(
          (row) =>
              BehaviorPattern.fromMap(Map<String, dynamic>.from(row as Map)),
        )
        .toList(growable: false);
  }

  @override
  Future<List<BehaviorPattern>> loadActive() async {
    if (currentUserId == null) return const [];
    final rows = await _supabase
        .from('behavior_patterns')
        .select()
        .eq('user_id', _userId)
        .isFilter('retired_at', null)
        .order('confidence_band');
    return rows.map(BehaviorPattern.fromMap).toList(growable: false);
  }
}

class BehaviorPatternService {
  final BehaviorPatternStore _store;
  final BehaviorPatternLearningEngine _engine;
  final RecoveryContextEngine _recoveryEngine;
  final DateTime Function() _clock;
  BehaviorPatternService({
    SupabaseClient? supabase,
    BehaviorPatternStore? store,
    BehaviorPatternLearningEngine engine =
        const BehaviorPatternLearningEngine(),
    RecoveryContextEngine recoveryEngine = const RecoveryContextEngine(),
    DateTime Function()? clock,
  }) : _store =
           store ??
           SupabaseBehaviorPatternStore(supabase ?? Supabase.instance.client),
       _engine = engine,
       _recoveryEngine = recoveryEngine,
       _clock = clock ?? DateTime.now;

  Future<List<BehaviorPattern>> learnAndSave() async {
    if (_store.currentUserId == null) {
      throw StateError('Sign in to learn behavior patterns.');
    }
    final now = _clock();
    final windowStart = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 41));
    final recoveryHistoryStart = DateTime(now.year, now.month, now.day)
        .subtract(
          const Duration(days: 55),
        ); // baseline history plus the 42-day output window
    // Each source is optional across installations and migration states. One
    // unavailable source must reduce coverage, not prevent the other validated
    // sources from contributing patterns.
    final training = await _orEmpty(() => _store.loadTraining(windowStart));
    final nutrition = await _orEmpty(() => _store.loadNutrition(windowStart));
    final reflections = await _orEmpty(
      () => _store.loadReflections(windowStart),
    );
    final wearable = await _orEmpty(
      () => _store.loadWearable(recoveryHistoryStart),
    );
    final completed = training
        .where((e) => e.completed)
        .map((e) => e.scheduledAt)
        .toList();
    final recovery = <BehaviorRecoverySignal>[];
    for (final day in wearable) {
      final context = _recoveryEngine.evaluate(
        RecoveryContextInput(
          wearableHistory: wearable
              .where(
                (e) =>
                    !e.localDate.isAfter(day.localDate) &&
                    !e.localDate.isBefore(
                      day.localDate.subtract(const Duration(days: 14)),
                    ),
              )
              .toList(),
          completedWorkoutDates: completed,
          now: day.localDate,
        ),
      );
      if (context.overallState == RecoveryContextState.favorable ||
          context.overallState == RecoveryContextState.caution) {
        recovery.add(
          BehaviorRecoverySignal(
            date: day.localDate,
            favorable: context.overallState == RecoveryContextState.favorable,
            caution: context.overallState == RecoveryContextState.caution,
          ),
        );
      }
    }
    final learned = _engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: training,
        nutritionLogs: nutrition,
        reflections: reflections,
        recovery: recovery,
      ),
    );
    return _store.replaceActive(learned, now);
  }

  Future<List<BehaviorPattern>> loadActive() => _store.loadActive();

  Future<List<T>> _orEmpty<T>(Future<List<T>> Function() load) async {
    try {
      return await load();
    } catch (_) {
      return const [];
    }
  }
}
