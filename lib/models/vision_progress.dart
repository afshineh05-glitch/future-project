import 'package:future_project/models/wearable_data.dart';

enum VisionProgressStatus {
  starting,
  building,
  onTrack,
  gainingMomentum,
  needsAttention,
}

enum VisionProgressSignalType {
  foundation,
  bodyProgress,
  trainingAdherence,
  consistency,
  wearable,
}

class VisionProgressSignal {
  final VisionProgressSignalType type;
  final double value;
  final double configuredWeight;
  final double effectiveWeight;
  final bool available;
  final int evidenceCount;
  final String explanation;

  const VisionProgressSignal({
    required this.type,
    required this.value,
    required this.configuredWeight,
    required this.effectiveWeight,
    required this.available,
    required this.evidenceCount,
    required this.explanation,
  });

  double get normalizedValue => value;
  double get weight => configuredWeight;
  int get observations => evidenceCount;
}

class VisionProgress {
  final double overallProgress;
  final VisionProgressStatus status;
  final double confidence;
  final List<VisionProgressSignal> signals;
  final String summary;

  const VisionProgress({
    required this.overallProgress,
    required this.status,
    required this.confidence,
    required this.signals,
    required this.summary,
  });

  bool get canShowPercentage => confidence >= 0.35;
}

class VisionFoundationBaseline {
  final bool exists;
  final bool completed;
  final String primaryGoal;
  final double? startingWeightKg;
  final double? targetWeightKg;
  final Map<String, double> measurementsCm;

  const VisionFoundationBaseline({
    this.exists = false,
    this.completed = false,
    this.primaryGoal = '',
    this.startingWeightKg,
    this.targetWeightKg,
    this.measurementsCm = const {},
  });
}

class VisionBodyProgressCheck {
  final DateTime checkedAt;
  final double? weightKg;
  final Map<String, double> measurementsCm;

  const VisionBodyProgressCheck({
    required this.checkedAt,
    this.weightKg,
    this.measurementsCm = const {},
  });
}

enum VisionTrainingSessionStatus { completed, partial, skipped }

class VisionTrainingSession {
  final DateTime scheduledAt;
  final DateTime? completedAt;
  final VisionTrainingSessionStatus status;

  const VisionTrainingSession({
    required this.scheduledAt,
    this.completedAt,
    required this.status,
  });
}

class VisionWearableSignal {
  final double normalizedValue;
  final double reliability;
  final int observations;
  final String explanation;

  const VisionWearableSignal({
    required this.normalizedValue,
    required this.reliability,
    required this.observations,
    required this.explanation,
  });
}

class VisionProgressInput {
  final VisionFoundationBaseline foundation;
  final List<VisionBodyProgressCheck> bodyProgressChecks;
  final List<VisionTrainingSession> trainingSessions;
  final VisionWearableSignal? wearable;

  /// Validated metric-level context. The engine intentionally does not score
  /// this in Phase 2; [wearable] remains the pre-existing scoring contract.
  final ValidatedWearableData? wearableContext;
  final int nutritionLogCount;
  final List<DateTime> nutritionActiveDates;
  final DateTime now;

  const VisionProgressInput({
    this.foundation = const VisionFoundationBaseline(),
    this.bodyProgressChecks = const [],
    this.trainingSessions = const [],
    this.wearable,
    this.wearableContext,
    this.nutritionLogCount = 0,
    this.nutritionActiveDates = const [],
    required this.now,
  });
}
