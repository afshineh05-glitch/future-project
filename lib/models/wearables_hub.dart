import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

enum WearableProvider { appleHealth }

class ConnectedHealthSource {
  final WearableProvider provider;
  final String displayName;
  final WearablePermissionStatus permissionStatus;
  final DateTime? lastSuccessfulSync;
  final bool dataAvailable;
  final String? statusMessage;

  const ConnectedHealthSource({
    required this.provider,
    required this.displayName,
    required this.permissionStatus,
    this.lastSuccessfulSync,
    required this.dataAvailable,
    this.statusMessage,
  });
}

enum WearableTrendDirection { increasing, decreasing, stable, insufficientData }

class WearableTrend {
  final String metric;
  final WearableTrendDirection direction;
  final int coverageDays;
  final String description;

  const WearableTrend({
    required this.metric,
    required this.direction,
    required this.coverageDays,
    required this.description,
  });
}

class WearablesCoachInsight {
  final String insight;
  final String nextAction;
  final List<String> evidence;

  const WearablesCoachInsight({
    required this.insight,
    required this.nextAction,
    required this.evidence,
  });
}

class WearablesHubData {
  final ConnectedHealthSource source;
  final ValidatedWearableData? today;
  final List<WearableDailyRecord> history;
  final RecoveryContext? recoveryContext;
  final WeeklyCoachPlan? weeklyPlan;
  final CoachDecision? dailyDecision;
  final List<WearableTrend> trends;
  final WearablesCoachInsight? coachInsight;
  final bool selfReportedPainOrFatigue;
  final DateTime generatedAt;

  const WearablesHubData({
    required this.source,
    this.today,
    this.history = const [],
    this.recoveryContext,
    this.weeklyPlan,
    this.dailyDecision,
    this.trends = const [],
    this.coachInsight,
    this.selfReportedPainOrFatigue = false,
    required this.generatedAt,
  });
}
