import 'package:future_project/models/future_vision.dart';

enum JourneyEventType {
  visionCreated,
  visionUpdated,
  foundationCompleted,
  trainingPlanCreated,
  firstWorkoutCompleted,
  trainingConsistencyEstablished,
  nutritionJourneyStarted,
  bodyProgressCheckCompleted,
  meaningfulBodyProgressDetected,
  milestoneCompleted,
  futureSelfGenerated,
  returnedAfterGap,
  behaviorPatternEstablished,
  weeklyPriorityProgressConfirmed,
}

enum JourneyEventCategory {
  identity,
  foundation,
  training,
  nutrition,
  progress,
  consistency,
}

class JourneyEvent {
  final String identity;
  final JourneyEventType type;
  final DateTime occurredAt;
  final String title;
  final String meaning;
  final JourneyEventCategory category;
  final String verifiedSource;
  final String? destination;

  const JourneyEvent({
    required this.identity,
    required this.type,
    required this.occurredAt,
    required this.title,
    required this.meaning,
    required this.category,
    required this.verifiedSource,
    this.destination,
  });
}

class JourneyTimeline {
  final VisionJourneyStage stage;
  final List<JourneyEvent> events;
  final String? nextChapterTitle;
  final String? nextChapterMeaning;
  final String? nextChapterDestination;
  final bool partial;

  const JourneyTimeline({
    required this.stage,
    required this.events,
    this.nextChapterTitle,
    this.nextChapterMeaning,
    this.nextChapterDestination,
    this.partial = false,
  });
}

class JourneySourceSnapshot {
  final List<Map<String, dynamic>> visions;
  final List<Map<String, dynamic>> foundations;
  final List<Map<String, dynamic>> plans;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> nutrition;
  final List<Map<String, dynamic>> bodyProgress;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, dynamic>> behaviorPatterns;
  final List<Map<String, dynamic>> weeklyPlans;
  final String? nextMilestoneTitle;
  final String? nextMilestoneMeaning;
  final String? nextMilestoneDestination;
  final String? todayMissionTitle;
  final String? todayMissionMeaning;
  final String? todayMissionDestination;
  final bool partial;

  const JourneySourceSnapshot({
    this.visions = const [],
    this.foundations = const [],
    this.plans = const [],
    this.workouts = const [],
    this.nutrition = const [],
    this.bodyProgress = const [],
    this.milestones = const [],
    this.behaviorPatterns = const [],
    this.weeklyPlans = const [],
    this.nextMilestoneTitle,
    this.nextMilestoneMeaning,
    this.nextMilestoneDestination,
    this.todayMissionTitle,
    this.todayMissionMeaning,
    this.todayMissionDestination,
    this.partial = false,
  });
}
