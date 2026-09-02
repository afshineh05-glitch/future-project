import 'package:future_project/models/vision_progress.dart';

class VisionProgressEngine {
  static const double bodyWeight = 0.50;
  static const double trainingWeight = 0.35;
  static const double consistencyWeight = 0.10;
  static const double wearableWeight = 0.05;
  static const int minimumConsistencyActiveDays = 3;
  static const double minimumWearableReliability = 0.50;

  const VisionProgressEngine();

  VisionProgress evaluate(VisionProgressInput input) {
    final completed = input.trainingSessions
        .where((item) => item.status == VisionTrainingSessionStatus.completed)
        .toList();
    final bodyScore = _bodyScore(input);
    final trainingScore = _trainingScore(input.trainingSessions, input.now);
    final consistencyScore = _consistencyScore(completed);
    final activeTrainingDays = _activeDates(completed).length;
    final wearableScore = input.wearable == null
        ? 0.0
        : _clamp(input.wearable!.normalizedValue);
    final bodyAvailable = bodyScore != null;
    final trainingAvailable = input.trainingSessions.isNotEmpty;
    final consistencyAvailable =
        activeTrainingDays >= minimumConsistencyActiveDays;
    final wearableAvailable =
        input.wearable != null &&
        input.wearable!.observations > 0 &&
        input.wearable!.reliability >= minimumWearableReliability;
    final availableWeight =
        (bodyAvailable ? bodyWeight : 0) +
        (trainingAvailable ? trainingWeight : 0) +
        (consistencyAvailable ? consistencyWeight : 0) +
        (wearableAvailable ? wearableWeight : 0);
    final weightedTotal =
        (bodyAvailable ? bodyScore * bodyWeight : 0) +
        (trainingAvailable ? trainingScore * trainingWeight : 0) +
        (consistencyAvailable ? consistencyScore * consistencyWeight : 0) +
        (wearableAvailable ? wearableScore * wearableWeight : 0);
    final progress = availableWeight == 0
        ? 0.0
        : _clamp(weightedTotal / availableWeight);
    final confidence = _confidence(input);
    final signals = <VisionProgressSignal>[
      VisionProgressSignal(
        type: VisionProgressSignalType.foundation,
        value: 0,
        configuredWeight: 0,
        effectiveWeight: 0,
        available: input.foundation.exists,
        evidenceCount: input.foundation.exists ? 1 : 0,
        explanation: input.foundation.exists
            ? input.foundation.completed
                  ? 'Foundation provides your completed baseline.'
                  : 'Foundation provides partial baseline context.'
            : 'Foundation baseline is unavailable.',
      ),
      VisionProgressSignal(
        type: VisionProgressSignalType.bodyProgress,
        value: bodyScore ?? 0,
        configuredWeight: bodyWeight,
        effectiveWeight: bodyAvailable ? bodyWeight / availableWeight : 0,
        available: bodyAvailable,
        evidenceCount: input.bodyProgressChecks.length,
        explanation: bodyAvailable
            ? '${input.bodyProgressChecks.length} Body Progress checks compared with your baseline.'
            : 'Not enough comparable Body Progress checks yet.',
      ),
      VisionProgressSignal(
        type: VisionProgressSignalType.trainingAdherence,
        value: trainingScore,
        configuredWeight: trainingWeight,
        effectiveWeight: trainingAvailable
            ? trainingWeight / availableWeight
            : 0,
        available: trainingAvailable,
        evidenceCount: input.trainingSessions.length,
        explanation: trainingAvailable
            ? '${completed.length} completed workouts across ${input.trainingSessions.length} recorded sessions.'
            : 'No workout adherence observations yet.',
      ),
      VisionProgressSignal(
        type: VisionProgressSignalType.consistency,
        value: consistencyScore,
        configuredWeight: consistencyWeight,
        effectiveWeight: consistencyAvailable
            ? consistencyWeight / availableWeight
            : 0,
        available: consistencyAvailable,
        evidenceCount: activeTrainingDays,
        explanation: consistencyAvailable
            ? '$activeTrainingDays active training days recorded.'
            : 'At least $minimumConsistencyActiveDays active training days are needed for consistency.',
      ),
      VisionProgressSignal(
        type: VisionProgressSignalType.wearable,
        value: wearableScore,
        configuredWeight: wearableWeight,
        effectiveWeight: wearableAvailable
            ? wearableWeight / availableWeight
            : 0,
        available: wearableAvailable,
        evidenceCount: input.wearable?.observations ?? 0,
        explanation: wearableAvailable
            ? input.wearable!.explanation
            : 'No sufficiently reliable connected wearable signal.',
      ),
    ];
    final status = _status(
      input: input,
      progress: progress,
      confidence: confidence,
      completed: completed,
      bodyAvailable: bodyAvailable,
    );
    return VisionProgress(
      overallProgress: progress,
      status: status,
      confidence: confidence,
      signals: List.unmodifiable(signals),
      summary: _summary(status, confidence),
    );
  }

  double? _bodyScore(VisionProgressInput input) {
    if (input.bodyProgressChecks.isEmpty || !input.foundation.exists) {
      return null;
    }
    final checks = [...input.bodyProgressChecks]
      ..sort((a, b) => a.checkedAt.compareTo(b.checkedAt));
    final baselineWeight =
        input.foundation.startingWeightKg;
    final targetWeight = input.foundation.targetWeightKg;
    final latestWeight = checks.last.weightKg;
    if (baselineWeight != null &&
        targetWeight != null &&
        latestWeight != null &&
        (targetWeight - baselineWeight).abs() >= 0.5) {
      return _clamp(
        (latestWeight - baselineWeight) / (targetWeight - baselineWeight),
      );
    }
    final goal = _normalize(input.foundation.primaryGoal);
    if ({'fat_loss', 'lose_fat'}.contains(goal)) {
      final baselineWaist =
          input.foundation.measurementsCm['waist'];
      final latestWaist = checks.last.measurementsCm['waist'];
      if (baselineWaist != null && latestWaist != null && baselineWaist > 0) {
        return _clamp((baselineWaist - latestWaist) / (baselineWaist * 0.10));
      }
    }
    if ({'build_muscle', 'muscle_gain', 'become_stronger'}.contains(goal)) {
      const muscleMeasurements = ['chest', 'arm', 'thigh'];
      final changes = <double>[];
      for (final key in muscleMeasurements) {
        final baseline =
            input.foundation.measurementsCm[key];
        final latest = checks.last.measurementsCm[key];
        if (baseline != null && latest != null && baseline > 0) {
          changes.add((latest - baseline) / (baseline * 0.08));
        }
      }
      if (changes.isNotEmpty) {
        return _clamp(changes.reduce((a, b) => a + b) / changes.length);
      }
    }
    return null;
  }

  double _trainingScore(List<VisionTrainingSession> sessions, DateTime now) {
    if (sessions.isEmpty) return 0;
    final completed = sessions
        .where((item) => item.status == VisionTrainingSessionStatus.completed)
        .toList();
    final adherence = completed.length / sessions.length;
    final volume = _clamp(completed.length / 25);
    final recentActiveDays = _activeDates(
      completed.where(
        (item) =>
            !item.scheduledAt.isBefore(now.subtract(const Duration(days: 28))),
      ),
    ).length;
    final recency = _clamp(recentActiveDays / 12);
    return _clamp(volume * 0.45 + adherence * 0.35 + recency * 0.20);
  }

  double _consistencyScore(List<VisionTrainingSession> completed) =>
      _clamp(_activeDates(completed).length / 30);

  double _confidence(VisionProgressInput input) {
    var confidence = 0.0;
    if (input.foundation.exists) confidence += 0.10;
    if (input.foundation.completed) confidence += 0.05;
    final checks = input.bodyProgressChecks.length;
    if (checks == 1) {
      confidence += 0.10;
    } else if (checks >= 2) {
      confidence += 0.25 + ((checks - 2).clamp(0, 3) * 0.05);
    }
    confidence += (input.trainingSessions.length.clamp(0, 10) / 10) * 0.30;
    if (input.wearable != null &&
        input.wearable!.observations > 0 &&
        input.wearable!.reliability >= minimumWearableReliability) {
      confidence += 0.15 * _clamp(input.wearable!.reliability);
    }
    return _clamp(confidence);
  }

  VisionProgressStatus _status({
    required VisionProgressInput input,
    required double progress,
    required double confidence,
    required List<VisionTrainingSession> completed,
    required bool bodyAvailable,
  }) {
    if (input.trainingSessions.isEmpty && !bodyAvailable) {
      return VisionProgressStatus.starting;
    }
    final latestCompletion = completed.isEmpty
        ? null
        : ([...completed]
                ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt)))
              .first
              .scheduledAt;
    if (input.trainingSessions.length >= 3 &&
        (latestCompletion == null ||
            input.now.difference(latestCompletion).inDays >= 14)) {
      return VisionProgressStatus.needsAttention;
    }
    if (confidence < 0.25) return VisionProgressStatus.starting;
    if (confidence < 0.35) return VisionProgressStatus.building;
    final recentCompleted = completed
        .where(
          (item) => !item.scheduledAt.isBefore(
            input.now.subtract(const Duration(days: 28)),
          ),
        )
        .length;
    final hasMomentumEvidence =
        recentCompleted >= 8 ||
        (bodyAvailable && input.bodyProgressChecks.length >= 3);
    if (progress >= 0.65 && hasMomentumEvidence) {
      return VisionProgressStatus.gainingMomentum;
    }
    final hasOnTrackEvidence =
        input.trainingSessions.length >= 5 || bodyAvailable;
    if (progress >= 0.45 && hasOnTrackEvidence) {
      return VisionProgressStatus.onTrack;
    }
    return VisionProgressStatus.building;
  }

  String _summary(VisionProgressStatus status, double confidence) {
    if (confidence < 0.35) {
      return 'Your progress picture is still forming.';
    }
    return switch (status) {
      VisionProgressStatus.starting => 'Your baseline is taking shape.',
      VisionProgressStatus.building => 'You are building measurable momentum.',
      VisionProgressStatus.onTrack =>
        'Your actions are moving in the right direction.',
      VisionProgressStatus.gainingMomentum =>
        'Your recent consistency is gaining momentum.',
      VisionProgressStatus.needsAttention =>
        'Your recent training signals need attention.',
    };
  }

  Set<String> _activeDates(Iterable<VisionTrainingSession> sessions) => sessions
      .map(
        (item) =>
            '${item.scheduledAt.year}-${item.scheduledAt.month}-${item.scheduledAt.day}',
      )
      .toSet();

  String _normalize(String value) =>
      value.toLowerCase().trim().replaceAll(RegExp(r'[\s-]+'), '_');

  double _clamp(num value) => value.toDouble().clamp(0.0, 1.0);
}
