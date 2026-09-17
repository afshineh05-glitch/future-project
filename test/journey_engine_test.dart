import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/journey.dart';
import 'package:future_project/services/journey_engine.dart';

void main() {
  const engine = JourneyEngine();

  test(
    'removes prototype concepts and derives newest verified events first',
    () {
      final timeline = engine.build(
        JourneySourceSnapshot(
          visions: [
            {
              'created_at': '2026-01-01T00:00:00Z',
              'updated_at': '2026-01-01T00:00:00Z',
            },
          ],
          workouts: [
            {
              'id': 'w1',
              'status': 'completed',
              'scheduled_at': '2026-01-02T10:00:00Z',
              'completed_at': '2026-01-02T11:00:00Z',
            },
          ],
          nutrition: [
            {'id': 'n1', 'consumed_at': '2026-01-03T12:00:00Z'},
          ],
        ),
      );
      expect(timeline.events.first.title, 'You started fueling your goal');
      expect(
        timeline.events.map((event) => event.title),
        isNot(contains('Learn Flutter')),
      );
      expect(
        timeline.events.map((event) => event.title),
        isNot(contains('Firebase')),
      );
    },
  );

  test('event identities remain stable across repeated builds', () {
    final source = JourneySourceSnapshot(
      workouts: [
        {
          'id': 'stable',
          'status': 'completed',
          'scheduled_at': '2026-01-02T10:00:00Z',
          'completed_at': '2026-01-02T11:00:00Z',
        },
      ],
    );
    final first = engine
        .build(source)
        .events
        .map((event) => event.identity)
        .toList();
    final second = engine
        .build(source)
        .events
        .map((event) => event.identity)
        .toList();
    expect(second, first);
  });

  test('optional failures preserve available verified events', () {
    final timeline = engine.build(
      const JourneySourceSnapshot(
        visions: [
          {'created_at': '2026-01-01T00:00:00Z'},
        ],
        partial: true,
      ),
    );
    expect(timeline.events, isNotEmpty);
    expect(timeline.partial, isTrue);
  });
}
