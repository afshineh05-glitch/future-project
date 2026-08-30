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

  test('next milestone selection is deterministic', () {
    final input = withWorkouts(6);
    final first = engine.evaluate(input).nextMilestone;
    final second = engine.evaluate(input).nextMilestone;

    expect(first?.id, second?.id);
  });
}
