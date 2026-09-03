import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/vision_intelligence.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/vision_intelligence_engine.dart';
import 'package:future_project/services/vision_milestones_engine.dart';
import 'package:future_project/services/vision_progress_engine.dart';

void main() {
  const intelligenceEngine = VisionIntelligenceEngine();
  const progressEngine = VisionProgressEngine();
  const milestonesEngine = VisionMilestonesEngine();
  final now = DateTime(2026, 9, 3, 12);

  VisionTrainingSession session(
    int daysAgo, {
    VisionTrainingSessionStatus status = VisionTrainingSessionStatus.completed,
  }) => VisionTrainingSession(
    scheduledAt: now.subtract(Duration(days: daysAgo)),
    completedAt: status == VisionTrainingSessionStatus.completed
        ? now.subtract(Duration(days: daysAgo))
        : null,
    status: status,
  );

  VisionReflection reflection(int daysAgo, String response) => VisionReflection(
    id: '$daysAgo-$response',
    date: now.subtract(Duration(days: daysAgo)),
    response: response,
    note: null,
    createdAt: null,
    updatedAt: null,
  );

  VisionIntelligence evaluate({
    String goal = '',
    bool foundationExists = false,
    bool foundationCompleted = false,
    List<VisionTrainingSession> sessions = const [],
    List<VisionBodyProgressCheck> checks = const [],
    List<DateTime> nutritionDates = const [],
    List<VisionReflection> reflections = const [],
    bool returnedAfterGap = false,
    VisionActionDestination destination = VisionActionDestination.none,
    bool myWhy = false,
    FutureVision? vision,
    List<VisionEvidence> evidence = const [],
  }) {
    final canonical = VisionProgressInput(
      now: now,
      foundation: VisionFoundationBaseline(
        exists: foundationExists,
        completed: foundationCompleted,
        primaryGoal: goal,
        startingWeightKg: goal == 'fat_loss' ? 100 : null,
        targetWeightKg: goal == 'fat_loss' ? 90 : null,
      ),
      trainingSessions: sessions,
      bodyProgressChecks: checks,
      nutritionLogCount: nutritionDates.length,
      nutritionActiveDates: nutritionDates,
    );
    final progress = progressEngine.evaluate(canonical);
    final milestones = milestonesEngine.evaluate(canonical);
    final completed = sessions
        .where((item) => item.status == VisionTrainingSessionStatus.completed)
        .toList();
    final trainingDates = completed.map((item) => item.scheduledAt).toList()
      ..sort();
    final reflectionDates = reflections.map((item) => item.date).toList();
    final activeDates = <DateTime>[
      ...trainingDates,
      ...nutritionDates,
      ...reflectionDates,
    ]..sort();
    return intelligenceEngine.interpret(
      VisionIntelligenceInput(
        vision: vision,
        canonicalInput: canonical,
        progress: progress,
        milestones: milestones,
        behavior: VisionBehaviorSummary(
          completedWorkoutCount: completed.length,
          trainingActiveDates: trainingDates,
          nutritionLogCount: nutritionDates.length,
          nutritionActiveDates: nutritionDates,
          reflectionHistory: reflections,
          activeBehaviorDates: activeDates,
          returnedAfterGap: returnedAfterGap,
        ),
        evidence: evidence,
        todayAction: VisionTodayAction(
          action: destination == VisionActionDestination.none
              ? 'Recover intentionally'
              : 'Act today',
          source: 'canonical action',
          explanation: 'replaced by intelligence',
          ctaLabel: null,
          destination: destination,
          isRecovery: destination == VisionActionDestination.none,
        ),
        myWhy: VisionMyWhyMetadata(exists: myWhy, hasText: myWhy),
      ),
    );
  }

  test('brand-new user uses unknown-safe baseline copy', () {
    final result = evaluate();
    expect(result.phase, VisionPhase.starting);
    expect(result.heroInsight, contains('baseline'));
    expect(result.futureSelfMessage, isNot(contains('changed')));
  });

  test('Foundation only establishes a baseline without a percentage claim', () {
    final result = evaluate(
      goal: 'fat_loss',
      foundationExists: true,
      foundationCompleted: true,
    );
    expect(result.phase, VisionPhase.establishingBaseline);
    expect(result.journeyInsight, contains('measurable starting point'));
    expect(
      result.factsUsed
          .singleWhere((fact) => fact.type == VisionFactType.progressConfidence)
          .value,
      lessThan(0.35),
    );
  });

  test('first completed workout becomes recorded action', () {
    final result = evaluate(sessions: [session(0)]);
    expect(result.heroInsight, contains('recorded action'));
    expect(result.futureSelfMessage, contains('1 completed workout'));
  });

  test('six completed workouts personalize identity evidence', () {
    final result = evaluate(
      goal: 'build_muscle',
      sessions: List.generate(6, session),
    );
    expect(result.heroInsight, startsWith('6 completed workouts'));
    expect(result.futureSelfMessage, contains('6 completed workouts'));
  });

  test('strong training consistency maps from canonical momentum', () {
    final result = evaluate(
      foundationExists: true,
      foundationCompleted: true,
      sessions: List.generate(12, (index) => session(index * 2)),
    );
    expect(
      result.phase,
      anyOf(VisionPhase.gainingMomentum, VisionPhase.onTrack),
    );
    expect(result.beliefStatement, contains('something you do'));
  });

  test('first Body Progress Check is a comparison point, not change', () {
    final result = evaluate(
      goal: 'build_muscle',
      foundationExists: true,
      foundationCompleted: true,
      checks: [VisionBodyProgressCheck(checkedAt: now, weightKg: 80)],
    );
    expect(result.futureSelfMessage, contains('comparison point'));
    expect(result.futureSelfMessage, isNot(contains('movement')));
  });

  test('two comparable Body Progress Checks are traceable', () {
    final result = evaluate(
      checks: [
        VisionBodyProgressCheck(
          checkedAt: now.subtract(const Duration(days: 30)),
          weightKg: 80,
        ),
        VisionBodyProgressCheck(checkedAt: now, weightKg: 80),
      ],
    );
    expect(
      result.factsUsed
          .singleWhere(
            (fact) => fact.type == VisionFactType.comparableBodyProgress,
          )
          .value,
      isTrue,
    );
  });

  test('verified body progress uses the canonical body signal', () {
    final result = evaluate(
      goal: 'fat_loss',
      foundationExists: true,
      foundationCompleted: true,
      checks: [VisionBodyProgressCheck(checkedAt: now, weightKg: 95)],
    );
    expect(result.futureSelfMessage, contains('verified movement'));
  });

  test('missing Body Progress stays unknown', () {
    final result = evaluate(goal: 'fat_loss');
    expect(
      result.factsUsed,
      contains(
        predicate<VisionFact>(
          (fact) =>
              fact.type == VisionFactType.bodyProgressChecks && fact.value == 0,
        ),
      ),
    );
    expect(result.futureSelfMessage, isNot(contains('body has not')));
  });

  test('goals produce meaningfully different recovery explanations', () {
    final muscle = evaluate(goal: 'build_muscle');
    final loss = evaluate(goal: 'fat_loss');
    final fitness = evaluate(goal: 'improve_fitness');
    expect(muscle.todayExplanation, contains('muscle growth'));
    expect(loss.todayExplanation, contains('fat-loss'));
    expect(fitness.todayExplanation, contains('fitness'));
    expect(
      {
        muscle.todayExplanation,
        loss.todayExplanation,
        fitness.todayExplanation,
      }.length,
      3,
    );
  });

  test('mixed reflections are interpreted without labeling the user', () {
    final result = evaluate(
      reflections: [
        reflection(0, 'yes'),
        reflection(1, 'a_little'),
        reflection(2, 'not_today'),
      ],
    );
    expect(result.reflectionInsight, contains('mixed'));
    expect(result.reflectionInsight, isNot(contains('lazy')));
  });

  test('several positive reflections acknowledge showing up', () {
    final result = evaluate(
      reflections: List.generate(5, (index) => reflection(index, 'yes')),
    );
    expect(result.reflectionInsight, contains('showing up consistently'));
  });

  test('several not-today reflections invite one action without diagnosis', () {
    final result = evaluate(
      reflections: List.generate(4, (index) => reflection(index, 'not_today')),
    );
    expect(result.reflectionInsight, contains('One intentional action'));
    expect(result.reflectionInsight, isNot(contains('unmotivated')));
  });

  test('canonical inactivity status is preserved as needs attention', () {
    final result = evaluate(sessions: [session(20), session(21), session(22)]);
    expect(result.phase, VisionPhase.needsAttention);
    expect(result.heroInsight, contains('restart'));
  });

  test('verified comeback is the only override of canonical presentation', () {
    final result = evaluate(
      sessions: [session(7), session(0)],
      returnedAfterGap: true,
    );
    expect(result.phase, VisionPhase.returning);
    expect(result.futureSelfMessage, contains('returned after a gap'));
  });

  test('low and high confidence remain canonical facts', () {
    final low = evaluate(foundationExists: true);
    final high = evaluate(
      sessions: List.generate(10, session),
      checks: [
        VisionBodyProgressCheck(checkedAt: now, weightKg: 80),
        VisionBodyProgressCheck(
          checkedAt: now.subtract(const Duration(days: 30)),
          weightKg: 81,
        ),
      ],
    );
    double confidence(VisionIntelligence value) =>
        value.factsUsed
                .singleWhere(
                  (fact) => fact.type == VisionFactType.progressConfidence,
                )
                .value
            as double;
    expect(confidence(low), lessThan(0.35));
    expect(confidence(high), greaterThanOrEqualTo(0.35));
  });

  test('next Body Progress milestone gets comparison explanation', () {
    final result = evaluate(
      foundationExists: true,
      foundationCompleted: true,
      checks: [VisionBodyProgressCheck(checkedAt: now)],
    );
    expect(result.milestoneExplanation, contains('second check'));
  });

  test('next workout milestone gets training explanation', () {
    final result = evaluate(sessions: List.generate(6, session));
    expect(
      result.milestoneExplanation,
      contains('strongest available progress signals'),
    );
  });

  test('My Why exposes metadata only', () {
    final result = evaluate(myWhy: true);
    expect(result.beliefSupport, contains('saved privately'));
    expect(
      result.factsUsed.any((fact) => fact.type == VisionFactType.hasMyWhyText),
      isTrue,
    );
  });

  test('privacy contract cannot accept My Why plaintext or media', () {
    final model = File(
      'lib/models/vision_intelligence.dart',
    ).readAsStringSync();
    final engine = File(
      'lib/services/vision_intelligence_engine.dart',
    ).readAsStringSync();
    expect(model, isNot(contains('encryptedTextPayload')));
    expect(model, isNot(contains('voiceStoragePath')));
    expect(model, isNot(contains('videoStoragePath')));
    expect(engine, isNot(contains('MyWhyService')));
    expect(engine, isNot(contains('decrypt')));
  });

  test('missing wearable is ignored and creates no wearable copy', () {
    final result = evaluate();
    final allCopy =
        '${result.heroInsight} ${result.futureSelfMessage} ${result.todayExplanation}';
    expect(allCopy.toLowerCase(), isNot(contains('wearable')));
  });

  test('no unsupported strength, body-change, or nutrition claim', () {
    final result = evaluate(goal: 'become_stronger');
    final allCopy =
        '${result.heroInsight} ${result.futureSelfMessage} ${result.beliefSupport}';
    expect(allCopy, isNot(contains('strength improved')));
    expect(allCopy, isNot(contains('body changed')));
    expect(allCopy, isNot(contains('nutrition adherence')));
  });

  test('identical input produces identical output', () {
    final first = evaluate(
      goal: 'build_muscle',
      sessions: List.generate(6, session),
    );
    final second = evaluate(
      goal: 'build_muscle',
      sessions: List.generate(6, session),
    );
    expect(first.phase, second.phase);
    expect(first.heroInsight, second.heroInsight);
    expect(first.futureSelfMessage, second.futureSelfMessage);
    expect(first.todayExplanation, second.todayExplanation);
  });

  test(
    'presentation phase does not conflict with canonical progress status',
    () {
      final cases = <VisionProgressStatus, VisionPhase>{
        VisionProgressStatus.starting: VisionPhase.starting,
        VisionProgressStatus.building: VisionPhase.building,
        VisionProgressStatus.onTrack: VisionPhase.onTrack,
        VisionProgressStatus.gainingMomentum: VisionPhase.gainingMomentum,
        VisionProgressStatus.needsAttention: VisionPhase.needsAttention,
      };
      for (final entry in cases.entries) {
        final progress = VisionProgress(
          overallProgress: 0,
          status: entry.key,
          confidence: 0.5,
          signals: const [],
          summary: '',
        );
        final canonical = VisionProgressInput(now: now);
        final result = intelligenceEngine.interpret(
          VisionIntelligenceInput(
            vision: null,
            canonicalInput: canonical,
            progress: progress,
            milestones: const VisionMilestonesState(
              milestones: [],
              nextMilestone: null,
            ),
            behavior: const VisionBehaviorSummary(
              nutritionLogCount: 0,
              nutritionActiveDates: [],
              reflectionHistory: [],
              activeBehaviorDates: [],
              returnedAfterGap: false,
            ),
            evidence: const [],
            todayAction: const VisionTodayAction(
              action: 'Recover',
              source: 'canonical',
              explanation: '',
              ctaLabel: null,
              destination: VisionActionDestination.none,
            ),
          ),
        );
        expect(result.phase, entry.value);
      }
    },
  );

  test(
    'Today training, recovery, and Body Progress explanations are specific',
    () {
      final training = evaluate(
        goal: 'build_muscle',
        destination: VisionActionDestination.trainingPlan,
      );
      final recovery = evaluate(
        goal: 'build_muscle',
        destination: VisionActionDestination.none,
      );
      final body = evaluate(
        goal: 'fat_loss',
        destination: VisionActionDestination.bodyProgress,
      );
      expect(training.todayExplanation, contains('training signal'));
      expect(recovery.todayExplanation, contains('Recovery protects'));
      expect(body.todayExplanation, contains('comparison point'));
    },
  );

  test('goal-aware evidence ranking is stable and meaningful', () {
    final old = now.subtract(const Duration(days: 30));
    final evidence = [
      VisionEvidence(
        type: VisionEvidenceType.nutritionStarted,
        label: 'Nutrition',
        detail: 'Logged',
        priority: 60,
        occurredAt: now,
      ),
      VisionEvidence(
        type: VisionEvidenceType.workoutCompleted,
        label: 'Training',
        detail: 'Completed',
        priority: 55,
        occurredAt: old,
      ),
    ];
    final result = evaluate(goal: 'build_muscle', evidence: evidence);
    expect(
      result.rankedEvidence.first.type,
      VisionEvidenceType.workoutCompleted,
    );
    expect(result.journeyEvents, hasLength(2));
    expect(result.rankedEvidence.first.occurredAt, old);
  });
}
