import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/end_of_day_coach_summary.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/unified_coach_context_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EndOfDayObservation {
  final bool? workoutCompleted;
  final WearableDailyRecord? wearableRecord;

  const EndOfDayObservation({this.workoutCompleted, this.wearableRecord});
}

abstract interface class EndOfDayObservationSource {
  Future<EndOfDayObservation> load(DateTime localDate);
}

class SupabaseEndOfDayObservationSource implements EndOfDayObservationSource {
  final SupabaseClient _supabase;

  SupabaseEndOfDayObservationSource(this._supabase);

  @override
  Future<EndOfDayObservation> load(DateTime localDate) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to load the evening summary.');
    final start = DateTime(localDate.year, localDate.month, localDate.day);
    final end = start.add(const Duration(days: 1));
    bool? workoutCompleted;
    WearableDailyRecord? wearable;
    try {
      final rows = await _supabase
          .from('workout_sessions')
          .select('status')
          .eq('user_id', user.id)
          .gte('scheduled_at', start.toUtc().toIso8601String())
          .lt('scheduled_at', end.toUtc().toIso8601String());
      workoutCompleted = rows.any((row) => row['status'] == 'completed');
    } catch (_) {
      workoutCompleted = null;
    }
    try {
      final row = await _supabase
          .from('wearable_daily_records')
          .select()
          .eq('user_id', user.id)
          .eq('local_date', _dateKey(start))
          .maybeSingle();
      wearable = row == null ? null : WearableDailyRecord.fromMap(row);
    } catch (_) {
      wearable = null;
    }
    return EndOfDayObservation(
      workoutCompleted: workoutCompleted,
      wearableRecord: wearable,
    );
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class EndOfDayCoachInput {
  final DateTime now;
  final WeeklyCoachPlan? weeklyPlan;
  final CoachDecision? dailyDecision;
  final RecoveryContext? recoveryContext;
  final EndOfDayObservation observation;
  final bool selfReportedPain;
  final bool selfReportedFatigue;
  final UnifiedCoachContext? unifiedContext;

  const EndOfDayCoachInput({
    required this.now,
    this.weeklyPlan,
    this.dailyDecision,
    this.recoveryContext,
    this.observation = const EndOfDayObservation(),
    this.selfReportedPain = false,
    this.selfReportedFatigue = false,
    this.unifiedContext,
  });
}

class EndOfDayCoachEngine {
  const EndOfDayCoachEngine();

  EndOfDayCoachSummary? evaluate(EndOfDayCoachInput input) {
    final unified =
        input.unifiedContext ??
        const UnifiedCoachContextEngine().evaluate(
          UnifiedCoachContextInput(
            now: input.now,
            recoveryContext: input.recoveryContext,
            weeklyPlan: input.weeklyPlan,
            dailyDecision: input.dailyDecision,
            userReportedPainOrFatigue:
                input.selfReportedPain || input.selfReportedFatigue,
          ),
        );
    final hasCondition =
        unified.primaryState == UnifiedCoachPrimaryState.userCondition;
    final recoveryCaution =
        unified.primaryState == UnifiedCoachPrimaryState.recovery;
    final lighter = input.dailyDecision == CoachDecision.lighterSession;
    final completed = input.observation.workoutCompleted == true;
    final coverage = EndOfDayDataCoverage(
      weeklyMissionAvailable: input.weeklyPlan != null,
      dailyDecisionAvailable: input.dailyDecision != null,
      workoutDataAvailable: input.observation.workoutCompleted != null,
      wearableDataAvailable: input.observation.wearableRecord != null,
      recoveryContextAvailable: input.recoveryContext != null,
    );
    if (coverage.availableSources == 0 && !hasCondition) return null;

    final evidence = <String>[];
    if (hasCondition) evidence.add('user_reported_condition');
    if (recoveryCaution) evidence.add('recovery_caution');
    if (lighter) evidence.add('lighter_session_decision');
    if (completed) evidence.add('completed_workout');
    if (input.observation.wearableRecord != null) {
      evidence.add('validated_wearable_record');
    }

    late String headline;
    late String recognition;
    late String observation;
    late String next;
    if (hasCondition) {
      headline = 'Close the day around how you feel';
      recognition = lighter
          ? 'You chose a lighter approach instead of overriding how you felt.'
          : 'Your reported pain or fatigue is the most important context available tonight.';
      observation =
          'Recovery and your own condition take priority over training consistency.';
      next = unified.primaryAction;
    } else if (recoveryCaution) {
      headline = 'Protect recovery tonight';
      recognition = lighter
          ? 'You respected today’s recovery context by choosing the lighter option.'
          : completed
          ? 'You recorded today’s completed workout; recovery context now supports an easier close to the day.'
          : 'Today’s recovery context supports a lower-demand close to the day.';
      observation = 'Available recovery signals call for caution tonight.';
      next = unified.primaryAction;
    } else if (lighter) {
      headline = 'You kept today within control';
      recognition =
          'You followed through on your recorded lighter-session choice.';
      observation =
          'The lighter decision is the clearest recorded action from today.';
      next = unified.primaryAction;
    } else if (completed) {
      headline = 'Today’s planned work is complete';
      recognition = 'You completed a recorded workout today.';
      observation =
          'The completed session is today’s clearest progress evidence.';
      next = unified.primaryAction;
    } else {
      headline = 'Keep tonight simple';
      recognition =
          'There is not enough positive evidence to claim a completed action today.';
      observation = input.observation.workoutCompleted == false
          ? 'No completed app workout was recorded today.'
          : 'Workout data was unavailable, so no workout outcome is assumed.';
      next = unified.primaryAction;
    }

    return EndOfDayCoachSummary(
      localDate: DateTime(input.now.year, input.now.month, input.now.day),
      headline: headline,
      progressRecognition: recognition,
      missionContext: _missionContext(input.weeklyPlan, completed, lighter),
      todayObservation: observation,
      nextAction: next,
      evidence: List.unmodifiable(evidence),
      dataCoverage: coverage,
      generatedAt: input.now,
      dailyDecisionContext: input.dailyDecision,
      recoveryContext: input.recoveryContext?.overallState,
    );
  }

  String? _missionContext(WeeklyCoachPlan? plan, bool completed, bool lighter) {
    if (plan == null) return null;
    if (lighter) return 'Today’s lighter choice supported the weekly path.';
    if (completed &&
        plan.missionType == WeeklyMissionType.improveWorkoutConsistency) {
      return 'Today’s completed session kept the weekly consistency path moving.';
    }
    return 'Tonight’s next action stays connected to the current weekly path.';
  }
}

class EndOfDayCoachService {
  final EndOfDayObservationSource _source;
  final DateTime Function() _clock;

  EndOfDayCoachService({
    SupabaseClient? supabase,
    EndOfDayObservationSource? source,
    DateTime Function()? clock,
  }) : _source =
           source ??
           SupabaseEndOfDayObservationSource(
             supabase ?? Supabase.instance.client,
           ),
       _clock = clock ?? DateTime.now;

  Future<EndOfDayObservation> loadTodaySafely() async {
    try {
      return await _source.load(_clock());
    } catch (_) {
      return const EndOfDayObservation();
    }
  }
}
