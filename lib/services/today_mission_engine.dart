import 'package:future_project/models/daily_activity_state.dart';
import 'package:future_project/models/today_mission.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

class TodayMissionInput {
  final UnifiedCoachContext coachContext;
  final DailyActivityState activityState;
  final WeeklyCoachPlan? weeklyPlan;

  const TodayMissionInput({
    required this.coachContext,
    required this.activityState,
    this.weeklyPlan,
  });
}

/// Selects one read-only action. It never records completion or alters a plan.
class TodayMissionEngine {
  const TodayMissionEngine();

  TodayMission evaluate(TodayMissionInput input) {
    final context = input.coachContext;
    final state = input.activityState;
    final evidence = <String>[...context.evidence];
    final vision = state.visionIdentity?.trim();
    if (vision != null && vision.isNotEmpty) evidence.add('my_vision');

    if (context.primaryState == UnifiedCoachPrimaryState.userCondition ||
        context.primaryState == UnifiedCoachPrimaryState.recovery ||
        context.primaryState == UnifiedCoachPrimaryState.dailyDecision) {
      return _mission(
        title: 'Protect today’s direction',
        action: context.primaryAction,
        reason: _reason(context.primaryInsight, vision),
        context: context,
        evidence: evidence,
      );
    }

    final workouts = state.ofType(DailyActivityType.workout).toList();
    final workoutCompleted = workouts.any((item) => item.isComplete);
    final plannedWorkout = workouts
        .where((item) => item.status == DailyActivityStatus.planned)
        .firstOrNull;

    if (context.primaryState == UnifiedCoachPrimaryState.weeklyMission) {
      if (input.weeklyPlan?.missionType ==
              WeeklyMissionType.improveWorkoutConsistency &&
          workoutCompleted) {
        evidence.add('authoritative_workout_completed');
        return _mission(
          title: 'Today’s planned work is recorded',
          action:
              'Keep the completed session as today’s contribution; do not add extra work.',
          reason: _reason(input.weeklyPlan!.missionReason, vision),
          context: context,
          evidence: evidence,
          identity: workouts
              .firstWhere((item) => item.isComplete)
              .activityIdentity,
          completed: true,
        );
      }
      return _mission(
        title: input.weeklyPlan?.missionTitle ?? 'Today’s Mission',
        action: context.primaryAction,
        reason: _reason(context.primaryInsight, vision),
        context: context,
        evidence: evidence,
        identity: plannedWorkout?.activityIdentity,
      );
    }

    if (context.primaryState == UnifiedCoachPrimaryState.wearableContext ||
        context.primaryState == UnifiedCoachPrimaryState.learnedBehavior) {
      return _mission(
        title: 'Use today’s strongest context',
        action: context.primaryAction,
        reason: _reason(context.primaryInsight, vision),
        context: context,
        evidence: evidence,
        identity: plannedWorkout?.activityIdentity,
      );
    }

    if (plannedWorkout != null) {
      evidence.add('training_plan_scheduled');
      return _mission(
        title: 'Follow the existing Training Plan',
        action:
            'Complete today’s existing planned session without adding intensity.',
        reason: _reason(
          'The Training Plan already defines today’s work.',
          vision,
        ),
        context: context,
        evidence: evidence,
        identity: plannedWorkout.activityIdentity,
      );
    }
    if (!state.hasCompleted(DailyActivityType.nutrition) &&
        state.coverage.nutritionAvailable) {
      evidence.add('nutrition_not_yet_logged');
      return _mission(
        title: 'Support today with nutrition',
        action: 'Log your next meal in the existing Nutrition flow.',
        reason: _reason('No nutrition log is recorded for today yet.', vision),
        context: context,
        evidence: evidence,
        identity: 'nutrition:daily',
      );
    }
    if (!state.hasCompleted(DailyActivityType.reflection) &&
        state.coverage.reflectionAvailable) {
      evidence.add('reflection_not_yet_recorded');
      return _mission(
        title: 'Close the loop in My Vision',
        action: 'Complete today’s existing Daily Reflection.',
        reason: _reason(
          'Today’s reflection has not been recorded yet.',
          vision,
        ),
        context: context,
        evidence: evidence,
        identity: 'reflection:daily',
      );
    }
    return _mission(
      title: 'Continue the existing plan',
      action: context.primaryAction,
      reason: _reason(context.primaryInsight, vision),
      context: context,
      evidence: evidence,
    );
  }

  TodayMission _mission({
    required String title,
    required String action,
    required String reason,
    required UnifiedCoachContext context,
    required List<String> evidence,
    String? identity,
    bool completed = false,
  }) => TodayMission(
    title: title,
    action: action,
    reason: reason,
    activityIdentity: identity,
    alreadyCompleted: completed,
    sourcePriority: context.primaryState,
    evidence: List.unmodifiable(evidence.toSet()),
  );

  String _reason(String base, String? vision) =>
      vision == null || vision.isEmpty ? base : '$base This supports $vision.';
}
