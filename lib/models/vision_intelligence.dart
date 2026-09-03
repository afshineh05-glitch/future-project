import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/vision_progress.dart';

enum VisionPhase {
  establishingBaseline,
  starting,
  building,
  gainingMomentum,
  onTrack,
  needsAttention,
  returning,
}

enum VisionFactType {
  visionExists,
  foundationCompleted,
  primaryGoal,
  trainingPlanExists,
  completedWorkouts,
  trainingActiveDays,
  lastCompletedWorkout,
  bodyProgressChecks,
  comparableBodyProgress,
  verifiedBodyProgress,
  nutritionLoggedDays,
  reflectionYes,
  reflectionALittle,
  reflectionNotToday,
  returnedAfterGap,
  progressStatus,
  progressConfidence,
  nextMilestone,
  futureSelfGenerated,
  hasMyWhy,
  hasMyWhyText,
  hasMyWhyVoice,
  hasMyWhyVideo,
}

class VisionFact {
  final VisionFactType type;
  final Object value;
  final String source;

  const VisionFact({
    required this.type,
    required this.value,
    required this.source,
  });
}

class VisionMyWhyMetadata {
  final bool exists;
  final bool hasText;
  final bool hasVoice;
  final bool hasVideo;

  const VisionMyWhyMetadata({
    this.exists = false,
    this.hasText = false,
    this.hasVoice = false,
    this.hasVideo = false,
  });
}

class VisionIntelligence {
  final VisionPhase phase;
  final String heroInsight;
  final String beliefStatement;
  final String beliefSupport;
  final String journeyInsight;
  final List<VisionEvidence> journeyEvents;
  final List<VisionEvidence> rankedEvidence;
  final String futureSelfMessage;
  final String todayExplanation;
  final String reflectionInsight;
  final String milestoneExplanation;
  final List<VisionFact> factsUsed;

  const VisionIntelligence({
    required this.phase,
    required this.heroInsight,
    required this.beliefStatement,
    required this.beliefSupport,
    required this.journeyInsight,
    required this.journeyEvents,
    required this.rankedEvidence,
    required this.futureSelfMessage,
    required this.todayExplanation,
    required this.reflectionInsight,
    required this.milestoneExplanation,
    required this.factsUsed,
  });
}

extension VisionPhaseJourneyStage on VisionPhase {
  VisionJourneyStage get journeyStage => switch (this) {
    VisionPhase.establishingBaseline ||
    VisionPhase.starting => VisionJourneyStage.starting,
    VisionPhase.building ||
    VisionPhase.needsAttention ||
    VisionPhase.returning => VisionJourneyStage.building,
    VisionPhase.gainingMomentum => VisionJourneyStage.becoming,
    VisionPhase.onTrack => VisionJourneyStage.livingIt,
  };
}

extension VisionProgressStatusWire on VisionProgressStatus {
  String get factValue => switch (this) {
    VisionProgressStatus.starting => 'starting',
    VisionProgressStatus.building => 'building',
    VisionProgressStatus.onTrack => 'on_track',
    VisionProgressStatus.gainingMomentum => 'gaining_momentum',
    VisionProgressStatus.needsAttention => 'needs_attention',
  };
}
