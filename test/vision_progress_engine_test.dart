import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/vision_progress_engine.dart';

void main() {
  const engine = VisionProgressEngine();
  final now = DateTime(2026, 8, 26);

  VisionTrainingSession completed(int daysAgo) => VisionTrainingSession(
    scheduledAt: now.subtract(Duration(days: daysAgo)),
    completedAt: now.subtract(Duration(days: daysAgo)),
    status: VisionTrainingSessionStatus.completed,
  );

  test('Foundation only has low confidence and no display percentage', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 90,
          targetWeightKg: 80,
        ),
      ),
    );

    expect(result.overallProgress, 0);
    expect(result.confidence, lessThan(0.35));
    expect(result.canShowPercentage, isFalse);
  });

  test('training history increases behavioral progress', () {
    final empty = engine.evaluate(VisionProgressInput(now: now));
    final trained = engine.evaluate(
      VisionProgressInput(
        now: now,
        trainingSessions: List.generate(6, completed),
      ),
    );

    expect(trained.overallProgress, greaterThan(empty.overallProgress));
  });

  test('training and consistency normalize without body or wearable cap', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        trainingSessions: List.generate(6, completed),
      ),
    );
    final training = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.trainingAdherence,
    );
    final consistency = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.consistency,
    );
    final body = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.bodyProgress,
    );
    final wearable = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.wearable,
    );
    final expected = (training.value * 0.35 + consistency.value * 0.10) / 0.45;

    expect(training.available, isTrue);
    expect(consistency.available, isTrue);
    expect(body.available, isFalse);
    expect(wearable.available, isFalse);
    expect(result.overallProgress, closeTo(expected, 0.000001));
  });

  test('body and training weights normalize correctly', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 100,
          targetWeightKg: 90,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(
            checkedAt: now.subtract(const Duration(days: 30)),
            weightKg: 100,
          ),
          VisionBodyProgressCheck(checkedAt: now, weightKg: 95),
        ],
        trainingSessions: List.generate(
          2,
          (_) => VisionTrainingSession(
            scheduledAt: now,
            completedAt: now,
            status: VisionTrainingSessionStatus.completed,
          ),
        ),
      ),
    );
    final body = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.bodyProgress,
    );
    final training = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.trainingAdherence,
    );
    final consistency = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.consistency,
    );
    final expected = (body.value * 0.50 + training.value * 0.35) / 0.85;

    expect(body.available, isTrue);
    expect(training.available, isTrue);
    expect(consistency.available, isFalse);
    expect(result.overallProgress, closeTo(expected, 0.000001));
  });

  test('absent wearable has zero effective weight, not zero progress', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        trainingSessions: List.generate(5, completed),
      ),
    );
    final wearable = result.signals.singleWhere(
      (item) => item.type == VisionProgressSignalType.wearable,
    );

    expect(wearable.available, isFalse);
    expect(wearable.effectiveWeight, 0);
    expect(
      result.signals
          .where((item) => item.available && item.configuredWeight > 0)
          .map((item) => item.effectiveWeight)
          .reduce((a, b) => a + b),
      closeTo(1, 0.000001),
    );
  });

  test('multiple measurement points increase confidence', () {
    const foundation = VisionFoundationBaseline(
      exists: true,
      completed: true,
      primaryGoal: 'fat_loss',
      startingWeightKg: 90,
      targetWeightKg: 80,
    );
    final one = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: foundation,
        bodyProgressChecks: [
          VisionBodyProgressCheck(checkedAt: now, weightKg: 89),
        ],
      ),
    );
    final two = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: foundation,
        bodyProgressChecks: [
          VisionBodyProgressCheck(
            checkedAt: now.subtract(const Duration(days: 30)),
            weightKg: 90,
          ),
          VisionBodyProgressCheck(checkedAt: now, weightKg: 88),
        ],
      ),
    );

    expect(two.confidence, greaterThan(one.confidence));
  });

  test('missing optional workout history evaluates safely', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(exists: true),
        trainingSessions: const [],
      ),
    );

    expect(result.status, VisionProgressStatus.starting);
  });

  test('no data returns safe starting state', () {
    final result = engine.evaluate(VisionProgressInput(now: now));

    expect(result.status, VisionProgressStatus.starting);
    expect(result.overallProgress, 0);
    expect(result.confidence, 0);
  });

  test('one training sample cannot produce a high-confidence status', () {
    final result = engine.evaluate(
      VisionProgressInput(now: now, trainingSessions: [completed(0)]),
    );

    expect(result.confidence, lessThan(0.25));
    expect(result.status, VisionProgressStatus.starting);
    expect(result.canShowPercentage, isFalse);
  });

  test('all four sources retain configured 50 35 10 5 weights', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 100,
          targetWeightKg: 90,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(
            checkedAt: now.subtract(const Duration(days: 30)),
            weightKg: 100,
          ),
          VisionBodyProgressCheck(checkedAt: now, weightKg: 95),
        ],
        trainingSessions: List.generate(8, completed),
        wearable: const VisionWearableSignal(
          normalizedValue: 0.7,
          reliability: 0.8,
          observations: 14,
          explanation: 'Connected wearable activity.',
        ),
      ),
    );
    double effective(VisionProgressSignalType type) =>
        result.signals.singleWhere((item) => item.type == type).effectiveWeight;

    expect(
      effective(VisionProgressSignalType.bodyProgress),
      closeTo(.50, 1e-9),
    );
    expect(
      effective(VisionProgressSignalType.trainingAdherence),
      closeTo(.35, 1e-9),
    );
    expect(effective(VisionProgressSignalType.consistency), closeTo(.10, 1e-9));
    expect(effective(VisionProgressSignalType.wearable), closeTo(.05, 1e-9));
  });

  test('confidence remains independent from normalized progress', () {
    final result = engine.evaluate(
      VisionProgressInput(now: now, trainingSessions: [completed(0)]),
    );

    expect(result.overallProgress, greaterThan(result.confidence));
    expect(result.canShowPercentage, isFalse);
  });

  test('progress is always clamped from zero to one', () {
    final result = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 100,
          targetWeightKg: 90,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(
            checkedAt: now.subtract(const Duration(days: 30)),
            weightKg: 100,
          ),
          VisionBodyProgressCheck(checkedAt: now, weightKg: 50),
        ],
        trainingSessions: List.generate(100, completed),
        wearable: const VisionWearableSignal(
          normalizedValue: 20,
          reliability: 20,
          observations: 100,
          explanation: 'Test signal',
        ),
      ),
    );

    expect(result.overallProgress, inInclusiveRange(0, 1));
    expect(result.confidence, inInclusiveRange(0, 1));
  });
}
