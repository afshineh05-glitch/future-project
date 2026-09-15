import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/behavior_pattern.dart';
import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/services/behavior_pattern_learning_engine.dart';
import 'package:future_project/services/unified_coach_context_engine.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);
  const engine = BehaviorPatternLearningEngine();

  test('uses only the rolling 42-day window and needs repeated evidence', () {
    final result = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: [
          BehaviorTrainingSignal(
            scheduledAt: now.subtract(const Duration(days: 49)),
            completed: true,
          ),
          ...[1, 2, 3].map(
            (weeks) => BehaviorTrainingSignal(
              scheduledAt: now.subtract(Duration(days: weeks * 7)),
              completed: true,
            ),
          ),
        ],
      ),
    );
    final pattern = result.singleWhere(
      (p) => p.type == BehaviorPatternType.strongTrainingWeekday,
    );
    expect(pattern.observations, 3);
    expect(pattern.windowEnd.difference(pattern.windowStart).inDays, 41);
    expect(
      pattern.fingerprint,
      startsWith('v1:strongTrainingWeekday:weekday:'),
    );
  });

  test('does not confirm a weekday from one observation', () {
    final result = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: [BehaviorTrainingSignal(scheduledAt: now, completed: true)],
      ),
    );
    expect(result, isEmpty);
  });

  test('fingerprints remain stable across repeated learning runs', () {
    final training = [
      for (var weeks = 0; weeks < 3; weeks++)
        BehaviorTrainingSignal(
          scheduledAt: now.subtract(Duration(days: weeks * 7)),
          completed: true,
        ),
    ];
    final first = engine.evaluate(
      BehaviorPatternLearningInput(now: now, training: training),
    );
    final second = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now.add(const Duration(hours: 6)),
        training: training,
      ),
    );
    expect(
      second.map((pattern) => pattern.fingerprint),
      first.map((pattern) => pattern.fingerprint),
    );
  });

  test('detects shortened workouts, rhythms and consistent routine', () {
    final training = List.generate(
      6,
      (i) => BehaviorTrainingSignal(
        scheduledAt: now.subtract(Duration(days: i * 7)),
        completed: true,
        plannedDurationMinutes: 60,
        actualDurationMinutes: i < 4 ? 40 : 60,
      ),
    );
    final nutrition = List.generate(
      5,
      (i) => now.subtract(Duration(days: i * 7)),
    );
    final result = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: training,
        nutritionLogs: nutrition,
        reflections: nutrition,
      ),
    );
    expect(
      result.map((p) => p.type),
      containsAll([
        BehaviorPatternType.shortenedWorkouts,
        BehaviorPatternType.nutritionRhythm,
        BehaviorPatternType.reflectionRhythm,
        BehaviorPatternType.consistentRoutine,
      ]),
    );
  });

  test('requires two returns after gaps', () {
    final result = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: [
          for (final days in [35, 25, 15])
            BehaviorTrainingSignal(
              scheduledAt: now.subtract(Duration(days: days)),
              completed: true,
            ),
        ],
      ),
    );
    expect(
      result.map((p) => p.type),
      contains(BehaviorPatternType.returnAfterGap),
    );
  });

  test('detects missed weekdays and recovery-linked adherence', () {
    final training = <BehaviorTrainingSignal>[];
    final recovery = <BehaviorRecoverySignal>[];
    for (var weeks = 0; weeks < 4; weeks++) {
      final date = now.subtract(Duration(days: weeks * 7));
      final favorable = weeks.isEven;
      training.add(
        BehaviorTrainingSignal(scheduledAt: date, completed: favorable),
      );
      recovery.add(
        BehaviorRecoverySignal(
          date: date,
          favorable: favorable,
          caution: !favorable,
        ),
      );
    }
    final result = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: training,
        recovery: recovery,
      ),
    );
    expect(
      result.map((p) => p.type),
      contains(BehaviorPatternType.recoveryLinkedAdherence),
    );

    final missed = engine.evaluate(
      BehaviorPatternLearningInput(
        now: now,
        training: [
          for (var weeks = 0; weeks < 3; weeks++)
            BehaviorTrainingSignal(
              scheduledAt: now.subtract(Duration(days: weeks * 7)),
              completed: false,
            ),
        ],
      ),
    );
    expect(
      missed.map((p) => p.type),
      contains(BehaviorPatternType.missedTrainingWeekday),
    );
  });

  test('learned context cannot override a persisted daily decision', () {
    final pattern = BehaviorPattern(
      fingerprint: 'v1:consistentRoutine:training',
      type: BehaviorPatternType.consistentRoutine,
      direction: BehaviorPatternDirection.positive,
      confidenceBand: BehaviorPatternConfidence.strong,
      observations: 8,
      evidence: const ['completed:8'],
      windowStart: now.subtract(const Duration(days: 41)),
      windowEnd: now,
      coachHint: 'Routine is consistent.',
    );
    final context = const UnifiedCoachContextEngine().evaluate(
      UnifiedCoachContextInput(
        now: now,
        dailyDecision: CoachDecision.lighterSession,
        learnedPatterns: [pattern],
      ),
    );
    expect(context.primaryState, UnifiedCoachPrimaryState.dailyDecision);
    expect(context.learnedPatterns, [pattern]);
  });
}
