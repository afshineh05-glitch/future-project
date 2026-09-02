import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/services/vision_milestones_engine.dart';

void main() {
  const engine = VisionMilestonesEngine();
  final now = DateTime(2026, 8, 26);

  VisionTrainingSession completed(int daysAgo) => VisionTrainingSession(
    scheduledAt: now.subtract(Duration(days: daysAgo)),
    completedAt: now.subtract(Duration(days: daysAgo)),
    status: VisionTrainingSessionStatus.completed,
  );

  VisionProgressInput withWorkouts(int count) => VisionProgressInput(
    now: now,
    trainingSessions: List.generate(count, completed),
  );

  test('first workout milestone completes from real history', () {
    final state = engine.evaluate(withWorkouts(1));
    final first = state.milestones.singleWhere(
      (item) => item.id == 'workouts-1',
    );

    expect(first.status, VisionMilestoneStatus.completed);
    expect(first.completedAt, isNotNull);
  });

  test('six workouts selects ten workouts as next milestone', () {
    final state = engine.evaluate(withWorkouts(6));

    expect(state.nextMilestone?.id, 'workouts-10');
    expect(state.nextMilestone?.currentValue, 6);
  });

  test('completed milestones remain completed', () {
    final state = engine.evaluate(withWorkouts(10));

    expect(
      state.milestones
          .where(
            (item) =>
                item.category == VisionMilestoneCategory.training &&
                item.targetValue <= 10,
          )
          .every((item) => item.status == VisionMilestoneStatus.completed),
      isTrue,
    );
  });

  test('later milestones remain locked', () {
    final state = engine.evaluate(withWorkouts(1));
    final fifty = state.milestones.singleWhere(
      (item) => item.id == 'workouts-50',
    );

    expect(fifty.status, VisionMilestoneStatus.locked);
  });

  test('body milestones are not fabricated without body data', () {
    final state = engine.evaluate(withWorkouts(3));

    expect(
      state.milestones.any(
        (item) => item.category == VisionMilestoneCategory.bodyProgress,
      ),
      isFalse,
    );
  });

  test('first persisted body check completes milestone from Foundation', () {
    final state = engine.evaluate(
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
          VisionBodyProgressCheck(checkedAt: now, weightKg: 97.5),
        ],
      ),
    );
    final firstCheck = state.milestones.singleWhere(
      (item) => item.id == 'body-progress-checks-1',
    );
    final improvement = state.milestones.singleWhere(
      (item) => item.id == 'meaningful-body-improvement',
    );

    expect(firstCheck.status, VisionMilestoneStatus.completed);
    expect(firstCheck.completedAt, now);
    expect(improvement.status, VisionMilestoneStatus.completed);
  });

  test('one real body cycle completes only the first check milestone', () {
    final state = engine.evaluate(
      VisionProgressInput(
        now: now,
        foundation: const VisionFoundationBaseline(
          exists: true,
          completed: true,
          primaryGoal: 'athletic_performance',
          startingWeightKg: 79,
        ),
        bodyProgressChecks: [
          VisionBodyProgressCheck(checkedAt: now, weightKg: 78),
        ],
      ),
    );
    final first = state.milestones.singleWhere(
      (item) => item.id == 'body-progress-checks-1',
    );
    final second = state.milestones.singleWhere(
      (item) => item.id == 'body-progress-checks-2',
    );

    expect(first.status, VisionMilestoneStatus.completed);
    expect(second.status, VisionMilestoneStatus.inProgress);
    expect(second.currentValue, 1);
  });

  test('next milestone selection is deterministic', () {
    final input = withWorkouts(6);
    final first = engine.evaluate(input).nextMilestone;
    final second = engine.evaluate(input).nextMilestone;

    expect(first?.id, second?.id);
  });
}
