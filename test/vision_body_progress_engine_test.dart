import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/body_progress.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/services/vision_body_progress_engine.dart';

void main() {
  const engine = VisionBodyProgressEngine();

  BodyProgressCheck check(String id, DateTime checkedAt) => BodyProgressCheck(
    id: id,
    userId: 'user',
    measurements: const BodyMeasurements(
      weightKg: 80,
      waistCm: 85,
      chestCm: 100,
      hipsCm: 95,
      armCm: 35,
      thighCm: 58,
      neckCm: 38,
    ),
    checkedAt: checkedAt,
    createdAt: checkedAt,
    updatedAt: checkedAt,
  );

  test('first persisted check becomes Vision evidence', () {
    final checkedAt = DateTime(2026, 8, 30);
    final evidence = engine.evidenceFor([check('first', checkedAt)]);

    expect(evidence, isNotNull);
    expect(evidence!.type, VisionEvidenceType.bodyProgress);
    expect(evidence.label, contains('starting point'));
    expect(evidence.occurredAt, checkedAt);
  });

  test('repeated checks use the actual latest check as evidence date', () {
    final older = DateTime(2026, 8, 1);
    final latest = DateTime(2026, 8, 30);
    final evidence = engine.evidenceFor([
      check('older', older),
      check('latest', latest),
    ]);

    expect(evidence!.label, contains('kept measuring'));
    expect(evidence.detail, contains('2 Body Progress checks'));
    expect(evidence.occurredAt, latest);
  });

  test('only a due cycle becomes a Body Progress Today action', () {
    final upcoming = BodyProgressCycle.calculate(
      baselineAt: DateTime(2026, 8, 1),
      now: DateTime(2026, 8, 20),
    );
    final due = BodyProgressCycle.calculate(
      baselineAt: DateTime(2026, 8, 1),
      now: DateTime(2026, 8, 22),
    );

    expect(engine.dueActionFor(upcoming), isNull);
    final action = engine.dueActionFor(due);
    expect(action, isNotNull);
    expect(action!.destination, VisionActionDestination.bodyProgress);
    expect(action.ctaLabel, 'Start Body Progress Check');
  });
}
