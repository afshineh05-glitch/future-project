import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/health/recovery_context_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class RecoveryContextDataSource {
  Future<List<WearableDailyRecord>> loadWearableHistory();

  Future<List<DateTime>> loadCompletedWorkoutDates();
}

class SupabaseRecoveryContextDataSource implements RecoveryContextDataSource {
  final SupabaseClient _supabase;

  SupabaseRecoveryContextDataSource(this._supabase);

  @override
  Future<List<WearableDailyRecord>> loadWearableHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to load recovery context.');
    final cutoff = DateTime.now().subtract(
      RecoveryContextEngine.baselineWindow,
    );
    final rows = await _supabase
        .from('wearable_daily_records')
        .select()
        .eq('user_id', user.id)
        .gte('local_date', _dateKey(cutoff))
        .order('local_date', ascending: false);
    return rows.map(WearableDailyRecord.fromMap).toList(growable: false);
  }

  @override
  Future<List<DateTime>> loadCompletedWorkoutDates() async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to load recovery context.');
    final cutoff = DateTime.now().subtract(RecoveryContextEngine.workoutWindow);
    final rows = await _supabase
        .from('workout_sessions')
        .select('completed_at')
        .eq('user_id', user.id)
        .eq('status', 'completed')
        .gte('completed_at', cutoff.toUtc().toIso8601String());
    return rows
        .map((row) => DateTime.tryParse(row['completed_at']?.toString() ?? ''))
        .nonNulls
        .toList(growable: false);
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class RecoveryContextService {
  final RecoveryContextDataSource _dataSource;
  final RecoveryContextEngine _engine;

  RecoveryContextService({
    SupabaseClient? supabase,
    RecoveryContextDataSource? dataSource,
    RecoveryContextEngine engine = const RecoveryContextEngine(),
  }) : _dataSource =
           dataSource ??
           SupabaseRecoveryContextDataSource(
             supabase ?? Supabase.instance.client,
           ),
       _engine = engine;

  Future<RecoveryContext> load({DateTime? now}) async {
    final generatedAt = now ?? DateTime.now();
    final wearable = await _dataSource.loadWearableHistory();
    List<DateTime> workouts;
    try {
      workouts = await _dataSource.loadCompletedWorkoutDates();
    } catch (_) {
      workouts = const [];
    }
    return _engine.evaluate(
      RecoveryContextInput(
        wearableHistory: wearable,
        completedWorkoutDates: workouts,
        now: generatedAt,
      ),
    );
  }
}
