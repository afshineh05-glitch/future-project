import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/unified_coach_context_engine.dart';

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
    RecoveryContext? recoveryContext,
    CoachDecision? dailyDecision,
    bool selfReportedPain = false,
    bool selfReportedFatigue = false,
    UnifiedCoachContext? unifiedContext,
  }) {
    if (plan == null) return null;
    final context =
        unifiedContext ??
        const UnifiedCoachContextEngine().evaluate(
          UnifiedCoachContextInput(
            now: DateTime.now(),
            recoveryContext: recoveryContext,
            weeklyPlan: plan,
            dailyDecision: dailyDecision,
            userReportedPainOrFatigue: selfReportedPain || selfReportedFatigue,
            isPlannedTrainingDay: isPlannedTrainingDay,
          ),
        );
    return TodayWeeklyMissionGuidance(
      missionTitle: plan.missionTitle,
      todayFocus: context.primaryAction,
    );
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
