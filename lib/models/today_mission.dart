import 'package:future_project/models/unified_coach_context.dart';

class TodayMission {
  final String title;
  final String action;
  final String reason;
  final String? activityIdentity;
  final bool alreadyCompleted;
  final UnifiedCoachPrimaryState sourcePriority;
  final List<String> evidence;

  const TodayMission({
    required this.title,
    required this.action,
    required this.reason,
    this.activityIdentity,
    required this.alreadyCompleted,
    required this.sourcePriority,
    required this.evidence,
  });
}
