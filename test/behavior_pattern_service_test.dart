import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/behavior_pattern.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/behavior_pattern_service.dart';

class _MissingSourceStore implements BehaviorPatternStore {
  List<BehaviorPattern> saved = const [];

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<List<BehaviorTrainingSignal>> loadTraining(DateTime since) async => [
    for (var weeks = 0; weeks < 3; weeks++)
      BehaviorTrainingSignal(
        scheduledAt: DateTime(2026, 9, 15).subtract(Duration(days: weeks * 7)),
        completed: true,
      ),
  ];

  @override
  Future<List<DateTime>> loadNutrition(DateTime since) =>
      throw StateError('table is unavailable');

  @override
  Future<List<DateTime>> loadReflections(DateTime since) async => const [];

  @override
  Future<List<WearableDailyRecord>> loadWearable(DateTime since) async =>
      const [];

  @override
  Future<List<BehaviorPattern>> replaceActive(
    List<BehaviorPattern> patterns,
    DateTime learnedAt,
  ) async {
    saved = patterns;
    return patterns;
  }

  @override
  Future<List<BehaviorPattern>> loadActive() async => saved;
}

void main() {
  test('an unavailable optional source does not abort learning', () async {
    final store = _MissingSourceStore();
    final result = await BehaviorPatternService(
      store: store,
      clock: () => DateTime(2026, 9, 15, 12),
    ).learnAndSave();

    expect(
      result.map((pattern) => pattern.type),
      contains(BehaviorPatternType.strongTrainingWeekday),
    );
    expect(store.saved, result);
  });
}
