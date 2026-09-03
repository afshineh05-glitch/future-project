import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/vision_milestones_engine.dart';

void main() {
  const engine = VisionMilestonesEngine();
  final now = DateTime(2026, 9, 3);

  VisionTrainingSession completed(int daysAgo) => VisionTrainingSession(
    scheduledAt: now.subtract(Duration(days: daysAgo)),
    completedAt: now.subtract(Duration(days: daysAgo)),
    status: VisionTrainingSessionStatus.completed,
  );

  VisionMilestonesState personalized({
    required VisionProgressInput input,
    required String goal,
    bool returning = false,
    bool recentTraining = true,
    bool recentNutrition = true,
  }) => engine.personalize(
    engine.evaluate(input),
    VisionMilestonePersonalizationContext(
      primaryGoal: goal,
      returnedAfterGap: returning,
      hasRecentTraining: recentTraining,
      hasRecentNutrition: recentNutrition,
    ),
  );

  test('different goals produce different Next Milestone priorities', () {
    final input = VisionProgressInput(
      now: now,
      trainingSessions: List.generate(4, completed),
      nutritionLogCount: 6,
      nutritionActiveDates: List.generate(
        6,
        (index) => now.subtract(Duration(days: index)),
      ),
    );

    final muscle = personalized(input: input, goal: 'build_muscle');
    final fatLoss = personalized(input: input, goal: 'fat_loss');

    expect(muscle.nextMilestone?.category, VisionMilestoneCategory.training);
    expect(fatLoss.nextMilestone?.category, VisionMilestoneCategory.nutrition);
  });

  test('proximity affects selection across supported categories', () {
    final canonical = VisionMilestonesState(
      milestones: [
        _milestone(
          id: 'workouts-10',
          category: VisionMilestoneCategory.training,
          current: 2,
          target: 10,
          priority: 100,
          source: VisionMilestoneSource.workoutHistory,
        ),
        _milestone(
          id: 'nutrition-days-7',
          category: VisionMilestoneCategory.nutrition,
          current: 6,
          target: 7,
          priority: 30,
          source: VisionMilestoneSource.nutritionHistory,
        ),
      ],
      nextMilestone: null,
    );
    final result = engine.personalize(
      canonical,
      const VisionMilestonePersonalizationContext(
        primaryGoal: 'feel_healthier',
        hasRecentNutrition: true,
      ),
    );

    expect(result.nextMilestone?.id, 'nutrition-days-7');
  });

  test('completed milestone history remains canonical and visible', () {
    final result = personalized(
      input: VisionProgressInput(
        now: now,
        trainingSessions: List.generate(10, completed),
      ),
      goal: 'build_muscle',
    );
    final completedCanonical = result.milestones
        .where((item) => item.status == VisionMilestoneStatus.completed)
        .map((item) => item.id)
        .toSet();
    final completedVisible = result.visibleMilestones
        .where((item) => item.status == VisionMilestoneStatus.completed)
        .map((item) => item.id)
        .toSet();

    expect(completedVisible, completedCanonical);
    expect(
      completedCanonical,
      containsAll(['workouts-1', 'workouts-5', 'workouts-10']),
    );
  });

  test('missing data creates no unsupported milestone categories', () {
    final result = personalized(
      input: VisionProgressInput(now: now),
      goal: 'fat_loss',
      recentTraining: false,
      recentNutrition: false,
    );

    expect(result.milestones, isNotEmpty);
    expect(
      result.milestones.any(
        (item) => item.category == VisionMilestoneCategory.bodyTransformation,
      ),
      isFalse,
    );
    expect(
      result.milestones.any(
        (item) => item.category == VisionMilestoneCategory.strength,
      ),
      isFalse,
    );
    expect(
      result.milestones.any(
        (item) => item.category == VisionMilestoneCategory.nutrition,
      ),
      isFalse,
    );
  });

  test('returning safely favors a real training re-engagement milestone', () {
    final input = VisionProgressInput(
      now: now,
      trainingSessions: [completed(8), completed(0)],
      nutritionLogCount: 6,
      nutritionActiveDates: List.generate(
        6,
        (index) => now.subtract(Duration(days: index)),
      ),
    );
    final ordinary = personalized(input: input, goal: 'fat_loss');
    final returning = personalized(
      input: input,
      goal: 'fat_loss',
      returning: true,
    );

    expect(ordinary.nextMilestone?.category, VisionMilestoneCategory.nutrition);
    expect(returning.nextMilestone?.category, VisionMilestoneCategory.training);
    expect(returning.nextMilestone?.description, contains('already returned'));
  });

  test('strength milestones appear only when canonical performance exists', () {
    final withoutPerformance = personalized(
      input: VisionProgressInput(
        now: now,
        trainingSessions: List.generate(8, completed),
      ),
      goal: 'become_stronger',
    );
    expect(
      withoutPerformance.milestones.any(
        (item) => item.category == VisionMilestoneCategory.strength,
      ),
      isFalse,
    );

    final verified = _milestone(
      id: 'verified-performance-1',
      category: VisionMilestoneCategory.strength,
      current: 1,
      target: 2,
      priority: 105,
      source: VisionMilestoneSource.exercisePerformance,
    );
    final withPerformance = engine.personalize(
      VisionMilestonesState(milestones: [verified], nextMilestone: verified),
      const VisionMilestonePersonalizationContext(
        primaryGoal: 'become_stronger',
      ),
    );
    expect(
      withPerformance.nextMilestone?.category,
      VisionMilestoneCategory.strength,
    );
  });

  test('Body Transformation requires verified directional body evidence', () {
    final unchanged = personalized(
      input: VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 100,
          targetWeightKg: 90,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(checkedAt: now, weightKg: 100),
        ],
      ),
      goal: 'fat_loss',
    );
    final verified = personalized(
      input: VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
          startingWeightKg: 100,
          targetWeightKg: 90,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(checkedAt: now, weightKg: 97),
        ],
      ),
      goal: 'fat_loss',
    );

    expect(
      unchanged.milestones.any(
        (item) => item.category == VisionMilestoneCategory.bodyTransformation,
      ),
      isFalse,
    );
    expect(
      verified.milestones.any(
        (item) => item.category == VisionMilestoneCategory.bodyTransformation,
      ),
      isTrue,
    );
  });

  test('Hero state receives personalized Next Milestone copy', () {
    final result = personalized(
      input: VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'fat_loss',
        ),
        bodyProgressChecks: [VisionBodyProgressCheck(checkedAt: now)],
      ),
      goal: 'fat_loss',
      recentTraining: false,
      recentNutrition: false,
    );

    expect(result.nextMilestone?.id, 'body-progress-checks-2');
    expect(
      result.nextMilestone?.title,
      'Complete your next Body Progress Check',
    );
  });

  test('user-facing threshold wall is reduced without canonical data loss', () {
    final canonical = engine.evaluate(VisionProgressInput(now: now));
    final result = engine.personalize(
      canonical,
      const VisionMilestonePersonalizationContext(
        primaryGoal: 'improve_fitness',
      ),
    );

    expect(result.milestones.length, canonical.milestones.length);
    expect(result.visibleMilestones.length, lessThan(result.milestones.length));
    expect(
      result.forCategory(VisionMilestoneCategory.training).length,
      lessThan(5),
    );
    expect(
      result.visibleMilestones.any(
        (item) => item.status == VisionMilestoneStatus.inProgress,
      ),
      isTrue,
    );
    expect(
      result.visibleMilestones.any(
        (item) => item.status == VisionMilestoneStatus.locked,
      ),
      isTrue,
    );
  });
}

VisionMilestone _milestone({
  required String id,
  required VisionMilestoneCategory category,
  required double current,
  required double target,
  required int priority,
  required VisionMilestoneSource source,
}) => VisionMilestone(
  id: id,
  category: category,
  title: id,
  description: 'Canonical milestone',
  currentValue: current,
  targetValue: target,
  normalizedProgress: (current / target).clamp(0, 1),
  status: VisionMilestoneStatus.inProgress,
  priority: priority,
  source: source,
);
