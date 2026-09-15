import 'package:future_project/models/behavior_pattern.dart';

class BehaviorPatternLearningInput {
  final DateTime now;
  final List<BehaviorTrainingSignal> training;
  final List<DateTime> nutritionLogs;
  final List<DateTime> reflections;
  final List<BehaviorRecoverySignal> recovery;

  const BehaviorPatternLearningInput({
    required this.now,
    this.training = const [],
    this.nutritionLogs = const [],
    this.reflections = const [],
    this.recovery = const [],
  });
}

/// Learns descriptive patterns only. It never changes a plan or makes a daily
/// decision; its hints are optional, lower-priority coach context.
class BehaviorPatternLearningEngine {
  static const learningWindow = Duration(days: 42);
  const BehaviorPatternLearningEngine();

  List<BehaviorPattern> evaluate(BehaviorPatternLearningInput input) {
    final end = _day(input.now);
    final start = end.subtract(const Duration(days: 41));
    bool inWindow(DateTime date) {
      final day = _day(date);
      return !day.isBefore(start) && !day.isAfter(end);
    }

    final training = input.training
        .where((e) => inWindow(e.scheduledAt))
        .toList();
    final nutrition = input.nutritionLogs.where(inWindow).map(_day).toSet();
    final reflections = input.reflections.where(inWindow).map(_day).toSet();
    final recovery = input.recovery.where((e) => inWindow(e.date)).toList();
    final patterns = <BehaviorPattern>[];

    for (var weekday = 1; weekday <= 7; weekday++) {
      final observations = training
          .where((e) => e.scheduledAt.weekday == weekday)
          .toList();
      if (observations.length < 3) continue;
      final completed = observations.where((e) => e.completed).length;
      final rate = completed / observations.length;
      if (rate >= .8) {
        patterns.add(
          _pattern(
            type: BehaviorPatternType.strongTrainingWeekday,
            key: 'weekday:$weekday',
            direction: BehaviorPatternDirection.positive,
            successes: completed,
            observations: observations.length,
            evidence: [
              'completed:$completed',
              'scheduled:${observations.length}',
              'weekday:$weekday',
            ],
            hint: '${_weekday(weekday)} has been a reliable training day.',
            start: start,
            end: end,
          ),
        );
      } else if (rate <= .34 && observations.length - completed >= 2) {
        patterns.add(
          _pattern(
            type: BehaviorPatternType.missedTrainingWeekday,
            key: 'weekday:$weekday',
            direction: BehaviorPatternDirection.negative,
            successes: observations.length - completed,
            observations: observations.length,
            evidence: [
              'missed:${observations.length - completed}',
              'scheduled:${observations.length}',
              'weekday:$weekday',
            ],
            hint: '${_weekday(weekday)} training has been harder to complete.',
            start: start,
            end: end,
          ),
        );
      }
    }

    final completedWithDuration = training
        .where(
          (e) =>
              e.completed &&
              e.plannedDurationMinutes != null &&
              e.plannedDurationMinutes! > 0 &&
              e.actualDurationMinutes != null,
        )
        .toList();
    final shortened = completedWithDuration
        .where(
          (e) => e.actualDurationMinutes! <= e.plannedDurationMinutes! * .75,
        )
        .length;
    if (completedWithDuration.length >= 4 &&
        shortened >= 3 &&
        shortened / completedWithDuration.length >= .5) {
      patterns.add(
        _pattern(
          type: BehaviorPatternType.shortenedWorkouts,
          key: 'all',
          direction: BehaviorPatternDirection.negative,
          successes: shortened,
          observations: completedWithDuration.length,
          evidence: [
            'shortened:$shortened',
            'completed_with_duration:${completedWithDuration.length}',
            'threshold:25_percent',
          ],
          hint: 'Recent completed workouts often fit a shorter window.',
          start: start,
          end: end,
        ),
      );
    }

    _addRhythms(
      patterns,
      BehaviorPatternType.nutritionRhythm,
      nutrition,
      start,
      end,
    );
    _addRhythms(
      patterns,
      BehaviorPatternType.reflectionRhythm,
      reflections,
      start,
      end,
    );
    _addRecoveryPattern(patterns, training, recovery, start, end);
    _addReturns(patterns, training, start, end);

    final completed = training.where((e) => e.completed).length;
    if (training.length >= 6 &&
        completed >= 5 &&
        completed / training.length >= .8) {
      patterns.add(
        _pattern(
          type: BehaviorPatternType.consistentRoutine,
          key: 'training',
          direction: BehaviorPatternDirection.positive,
          successes: completed,
          observations: training.length,
          evidence: ['completed:$completed', 'scheduled:${training.length}'],
          hint: 'Your recent training routine has been consistent.',
          start: start,
          end: end,
        ),
      );
    }
    return List.unmodifiable(patterns);
  }

  void _addRhythms(
    List<BehaviorPattern> out,
    BehaviorPatternType type,
    Set<DateTime> days,
    DateTime start,
    DateTime end,
  ) {
    for (var weekday = 1; weekday <= 7; weekday++) {
      final count = days.where((d) => d.weekday == weekday).length;
      if (count < 4) continue; // repeated across at least four of six weeks
      out.add(
        _pattern(
          type: type,
          key: 'weekday:$weekday',
          direction: BehaviorPatternDirection.positive,
          successes: count,
          observations: 6,
          evidence: [
            'logged_weeks:$count',
            'possible_weeks:6',
            'weekday:$weekday',
          ],
          hint:
              '${_weekday(weekday)} is a recurring ${type == BehaviorPatternType.nutritionRhythm ? 'nutrition logging' : 'reflection'} rhythm.',
          start: start,
          end: end,
        ),
      );
    }
  }

  void _addRecoveryPattern(
    List<BehaviorPattern> out,
    List<BehaviorTrainingSignal> training,
    List<BehaviorRecoverySignal> recovery,
    DateTime start,
    DateTime end,
  ) {
    final byDay = _dayEntries(recovery);
    final comparable = training
        .where((t) => byDay.containsKey(_key(t.scheduledAt)))
        .toList();
    if (comparable.length < 4) return;
    final favorable = comparable
        .where((t) => byDay[_key(t.scheduledAt)]!.favorable)
        .toList();
    final caution = comparable
        .where((t) => byDay[_key(t.scheduledAt)]!.caution)
        .toList();
    if (favorable.length < 2 || caution.length < 2) return;
    final favorableRate =
        favorable.where((t) => t.completed).length / favorable.length;
    final cautionRate =
        caution.where((t) => t.completed).length / caution.length;
    if ((favorableRate - cautionRate).abs() < .34) return;
    final positive = favorableRate > cautionRate;
    out.add(
      _pattern(
        type: BehaviorPatternType.recoveryLinkedAdherence,
        key: positive ? 'favorable_higher' : 'caution_higher',
        direction: positive
            ? BehaviorPatternDirection.positive
            : BehaviorPatternDirection.mixed,
        successes: comparable.where((t) => t.completed).length,
        observations: comparable.length,
        evidence: [
          'favorable:${favorable.where((t) => t.completed).length}/${favorable.length}',
          'caution:${caution.where((t) => t.completed).length}/${caution.length}',
        ],
        hint: positive
            ? 'Training adherence has been stronger on favorable recovery days.'
            : 'Training adherence has not consistently tracked favorable recovery days.',
        start: start,
        end: end,
      ),
    );
  }

  Map<String, BehaviorRecoverySignal> _dayEntries(
    List<BehaviorRecoverySignal> values,
  ) => {for (final value in values) _key(value.date): value};

  void _addReturns(
    List<BehaviorPattern> out,
    List<BehaviorTrainingSignal> training,
    DateTime start,
    DateTime end,
  ) {
    final completed = training.where((e) => e.completed).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    final gaps = <int>[];
    for (var i = 1; i < completed.length; i++) {
      final gap = _day(
        completed[i].scheduledAt,
      ).difference(_day(completed[i - 1].scheduledAt)).inDays;
      if (gap >= 7) gaps.add(gap);
    }
    if (gaps.length < 2) return;
    out.add(
      _pattern(
        type: BehaviorPatternType.returnAfterGap,
        key: 'training_7d',
        direction: BehaviorPatternDirection.positive,
        successes: gaps.length,
        observations: completed.length,
        evidence: ['returns:${gaps.length}', 'gaps_days:${gaps.join(',')}'],
        hint: 'You have repeatedly returned to training after a gap.',
        start: start,
        end: end,
      ),
    );
  }

  BehaviorPattern _pattern({
    required BehaviorPatternType type,
    required String key,
    required BehaviorPatternDirection direction,
    required int successes,
    required int observations,
    required List<String> evidence,
    required String hint,
    required DateTime start,
    required DateTime end,
  }) => BehaviorPattern(
    fingerprint: 'v1:${type.name}:$key',
    type: type,
    direction: direction,
    confidenceBand: observations >= 8 && successes >= 6
        ? BehaviorPatternConfidence.strong
        : observations >= 5 && successes >= 4
        ? BehaviorPatternConfidence.established
        : BehaviorPatternConfidence.emerging,
    observations: observations,
    evidence: List.unmodifiable(evidence),
    windowStart: start,
    windowEnd: end,
    coachHint: hint,
  );

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  static String _key(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _weekday(int value) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][value - 1];
}
