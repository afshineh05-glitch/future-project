import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/coach_recovery_recommendation.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

class TodayWeeklyMissionGuidance {
  final String missionTitle;
  final String? todayFocus;

  const TodayWeeklyMissionGuidance({
    required this.missionTitle,
    this.todayFocus,
  });
}

class TodayWeeklyMissionAdvisor {
  const TodayWeeklyMissionAdvisor();

  TodayWeeklyMissionGuidance? advise({
    required WeeklyCoachPlan? plan,
    required bool isPlannedTrainingDay,
    CoachRecoveryRecommendation? recoveryRecommendation,
    CoachDecision? dailyDecision,
    bool selfReportedPain = false,
    bool selfReportedFatigue = false,
  }) {
    if (plan == null) return null;

    final title = plan.missionTitle;
    if (selfReportedPain || selfReportedFatigue) {
      return TodayWeeklyMissionGuidance(
        missionTitle: title,
        todayFocus:
            'How you feel comes first today. Keep your effort within your current comfort and energy.',
      );
    }
    if (dailyDecision == CoachDecision.lighterSession) {
      return TodayWeeklyMissionGuidance(
        missionTitle: title,
        todayFocus:
            'Your lighter choice comes first today. Keep the weekly focus without returning to the full planned session.',
      );
    }
    final recoveryCaution =
        recoveryRecommendation?.type ==
            CoachRecoveryRecommendationType.considerLighterTraining ||
        recoveryRecommendation?.type ==
            CoachRecoveryRecommendationType.recoverySupport;
    if (recoveryCaution) {
      return TodayWeeklyMissionGuidance(
        missionTitle: title,
        todayFocus: isPlannedTrainingDay
            ? 'Recovery comes first today. Use the lighter option if needed while keeping this week’s direction in view.'
            : 'Recovery comes first today. Protect an easier day while keeping this week’s direction in view.',
      );
    }

    final focus = switch (plan.missionType) {
      WeeklyMissionType.improveWorkoutConsistency =>
        isPlannedTrainingDay
            ? 'Completing today’s planned session keeps this week’s consistency moving—without adding intensity.'
            : null,
      WeeklyMissionType.protectRecovery =>
        isPlannedTrainingDay
            ? _firstMatching(plan.actionItems, const [
                'recovery',
                'sleep',
                'volume',
              ])
            : _firstMatching(plan.actionItems, const [
                'sleep',
                'easier',
                'recovery',
              ]),
      WeeklyMissionType.improveTrainingNightSleep => _firstMatching(
        plan.actionItems,
        const ['sleep', 'bedtime', 'wind-down'],
      ),
      WeeklyMissionType.reduceActivityLoad => _firstMatching(
        plan.actionItems,
        const ['activity', 'conditioning', 'lower-load'],
      ),
      WeeklyMissionType.maintainSuccessfulBehavior =>
        isPlannedTrainingDay
            ? _firstMatching(plan.actionItems, const ['training', 'session'])
            : null,
    };
    return TodayWeeklyMissionGuidance(missionTitle: title, todayFocus: focus);
  }

  String? _firstMatching(List<String> actions, List<String> terms) {
    for (final action in actions) {
      final normalized = action.toLowerCase();
      if (terms.any(normalized.contains)) return action;
    }
    return null;
  }
}

class TodayWeeklyMissionLoader {
  final Future<WeeklyCoachPlan?> Function() _loadCurrentPlan;

  const TodayWeeklyMissionLoader(this._loadCurrentPlan);

  Future<WeeklyCoachPlan?> loadSafely() async {
    try {
      return await _loadCurrentPlan();
    } catch (_) {
      return null;
    }
  }
}
