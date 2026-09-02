import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/models/future_self_generation.dart';

class FutureVision {
  final String userId;
  final String primaryGoal;
  final String futureIdentity;
  final List<String> desiredFeelings;
  final String visionStatement;
  final String? why;
  final String? currentPhotoPath;
  final String? futureSelfImagePath;
  final DateTime? futureSelfGeneratedAt;
  final FutureSelfInputMode? futureSelfInputMode;
  final FutureSelfInputMode? currentPhotoInputMode;
  final FutureSelfInputMode? futureSelfGeneratedInputMode;
  final int? futureSelfHorizonMonths;
  final String? futureSelfSourceReference;
  final String? futureSelfGoalUsed;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FutureVision({
    required this.userId,
    required this.primaryGoal,
    required this.futureIdentity,
    required this.desiredFeelings,
    required this.visionStatement,
    required this.why,
    this.currentPhotoPath,
    this.futureSelfImagePath,
    this.futureSelfGeneratedAt,
    this.futureSelfInputMode,
    this.currentPhotoInputMode,
    this.futureSelfGeneratedInputMode,
    this.futureSelfHorizonMonths,
    this.futureSelfSourceReference,
    this.futureSelfGoalUsed,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FutureVision.fromMap(Map<String, dynamic> map) => FutureVision(
    userId: map['user_id']?.toString() ?? '',
    primaryGoal: map['primary_goal']?.toString() ?? '',
    futureIdentity: map['future_identity']?.toString() ?? '',
    desiredFeelings: ((map['desired_feelings'] as List?) ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    visionStatement: map['vision_statement']?.toString() ?? '',
    why: _optionalText(map['my_why']),
    currentPhotoPath: _optionalText(map['current_photo_path']),
    futureSelfImagePath: _optionalText(map['future_self_image_path']),
    futureSelfGeneratedAt: _optionalDate(map['future_self_generated_at']),
    futureSelfInputMode: map['future_self_input_mode'] == null
        ? map['current_photo_path'] == null &&
                  map['future_self_image_path'] == null
              ? null
              : FutureSelfInputMode.fullBody
        : FutureSelfInputModeWire.fromWire(
            map['future_self_input_mode']?.toString(),
          ),
    currentPhotoInputMode: map['current_photo_path'] == null
        ? null
        : FutureSelfInputModeWire.fromWire(
            map['current_photo_input_mode']?.toString(),
          ),
    futureSelfGeneratedInputMode: map['future_self_image_path'] == null
        ? null
        : FutureSelfInputModeWire.fromWire(
            map['future_self_generated_input_mode']?.toString(),
          ),
    futureSelfHorizonMonths: (map['future_self_horizon_months'] as num?)
        ?.round(),
    futureSelfSourceReference: _optionalText(
      map['future_self_source_reference'],
    ),
    futureSelfGoalUsed: _optionalText(map['future_self_goal_used']),
    createdAt: DateTime.parse(map['created_at'].toString()),
    updatedAt: DateTime.parse(map['updated_at'].toString()),
  );
}

class VisionReflection {
  final String? id;
  final DateTime date;
  final String response;
  final String? note;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VisionReflection({
    required this.id,
    required this.date,
    required this.response,
    required this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VisionReflection.fromMap(Map<String, dynamic> map) =>
      VisionReflection(
        id: _optionalText(map['id']),
        date: DateTime.parse(map['reflection_date'].toString()),
        response: map['reflection_value']?.toString() ?? '',
        note: _optionalText(map['note']),
        createdAt: _optionalDate(map['created_at']),
        updatedAt: _optionalDate(map['updated_at']),
      );
}

enum VisionEvidenceType {
  visionStarted,
  foundationCompleted,
  bodyProgress,
  trainingPlanCreated,
  workoutCompleted,
  trainingConsistency,
  nutritionStarted,
  nutritionConsistency,
  reflectionStarted,
  reflectionConsistency,
  returnedAfterGap,
}

class VisionEvidence {
  final VisionEvidenceType type;
  final String label;
  final String detail;
  final DateTime? occurredAt;
  final int priority;

  const VisionEvidence({
    required this.type,
    required this.label,
    required this.detail,
    required this.priority,
    this.occurredAt,
  });
}

enum VisionActionDestination { trainingPlan, nutrition, bodyProgress, none }

class VisionTodayAction {
  final String action;
  final String source;
  final String explanation;
  final String? ctaLabel;
  final VisionActionDestination destination;
  final bool isRecovery;

  const VisionTodayAction({
    required this.action,
    required this.source,
    required this.explanation,
    required this.ctaLabel,
    required this.destination,
    this.isRecovery = false,
  });
}

enum VisionJourneyStage { starting, building, becoming, livingIt }

class VisionBehaviorSummary {
  final int completedWorkoutCount;
  final List<DateTime> trainingActiveDates;
  final int nutritionLogCount;
  final List<DateTime> nutritionActiveDates;
  final List<VisionReflection> reflectionHistory;
  final List<DateTime> activeBehaviorDates;
  final bool returnedAfterGap;

  const VisionBehaviorSummary({
    this.completedWorkoutCount = 0,
    this.trainingActiveDates = const [],
    required this.nutritionLogCount,
    required this.nutritionActiveDates,
    required this.reflectionHistory,
    required this.activeBehaviorDates,
    required this.returnedAfterGap,
  });

  int get behaviorCategoryCount =>
      (trainingActiveDates.isNotEmpty ? 1 : 0) +
      (nutritionActiveDates.isNotEmpty ? 1 : 0) +
      (reflectionHistory.isNotEmpty ? 1 : 0);

  int get yesReflectionCount =>
      reflectionHistory.where((item) => item.response == 'yes').length;

  int get aLittleReflectionCount =>
      reflectionHistory.where((item) => item.response == 'a_little').length;

  int get notTodayReflectionCount =>
      reflectionHistory.where((item) => item.response == 'not_today').length;
}

class FutureVisionState {
  final FutureVision? vision;
  final String foundationGoal;
  final VisionJourneyStage stage;
  final List<VisionEvidence> evidence;
  final VisionTodayAction todayAction;
  final VisionReflection? todayReflection;
  final int reflectionCount;
  final int meaningfulSignalCount;
  final String futureSelfMessage;
  final VisionBehaviorSummary behaviorSummary;
  final VisionProgress progress;
  final VisionMilestonesState milestones;

  const FutureVisionState({
    required this.vision,
    required this.foundationGoal,
    required this.stage,
    required this.evidence,
    required this.todayAction,
    required this.todayReflection,
    required this.reflectionCount,
    required this.meaningfulSignalCount,
    required this.futureSelfMessage,
    required this.behaviorSummary,
    required this.progress,
    required this.milestones,
  });
}

String? _optionalText(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _optionalDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());
