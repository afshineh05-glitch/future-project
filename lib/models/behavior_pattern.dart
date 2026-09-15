enum BehaviorPatternType {
  strongTrainingWeekday,
  missedTrainingWeekday,
  shortenedWorkouts,
  nutritionRhythm,
  reflectionRhythm,
  recoveryLinkedAdherence,
  returnAfterGap,
  consistentRoutine,
}

enum BehaviorPatternDirection { positive, negative, mixed }

enum BehaviorPatternConfidence { emerging, established, strong }

class BehaviorPattern {
  final String fingerprint;
  final BehaviorPatternType type;
  final BehaviorPatternDirection direction;
  final BehaviorPatternConfidence confidenceBand;
  final int observations;
  final List<String> evidence;
  final DateTime windowStart;
  final DateTime windowEnd;
  final String coachHint;
  final bool active;

  const BehaviorPattern({
    required this.fingerprint,
    required this.type,
    required this.direction,
    required this.confidenceBand,
    required this.observations,
    required this.evidence,
    required this.windowStart,
    required this.windowEnd,
    required this.coachHint,
    this.active = true,
  });

  factory BehaviorPattern.fromMap(Map<String, dynamic> map) => BehaviorPattern(
    fingerprint: map['fingerprint'].toString(),
    type: BehaviorPatternType.values.byName(map['pattern_type'].toString()),
    direction: BehaviorPatternDirection.values.byName(
      map['direction'].toString(),
    ),
    confidenceBand: BehaviorPatternConfidence.values.byName(
      map['confidence_band'].toString(),
    ),
    observations: (map['observations'] as num).toInt(),
    evidence: List<String>.from(map['evidence'] as List? ?? const []),
    windowStart: DateTime.parse(map['window_start'].toString()),
    windowEnd: DateTime.parse(map['window_end'].toString()),
    coachHint: map['coach_hint'].toString(),
    active: map['retired_at'] == null,
  );
}

class BehaviorTrainingSignal {
  final DateTime scheduledAt;
  final bool completed;
  final int? plannedDurationMinutes;
  final int? actualDurationMinutes;

  const BehaviorTrainingSignal({
    required this.scheduledAt,
    required this.completed,
    this.plannedDurationMinutes,
    this.actualDurationMinutes,
  });
}

class BehaviorRecoverySignal {
  final DateTime date;
  final bool favorable;
  final bool caution;

  const BehaviorRecoverySignal({
    required this.date,
    required this.favorable,
    required this.caution,
  });
}
