import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/weekly_coach_plan.dart';

class WeeklyWorkoutObservation {
  final DateTime date;
  final String status;

  const WeeklyWorkoutObservation(this.date, this.status);
}

class WeeklyCoachInput {
  final DateTime now;
  final List<WearableDailyRecord> wearableHistory;
  final List<WeeklyWorkoutObservation> workouts;
  final bool workoutSourceAvailable;
  final String primaryGoal;
  final WeeklyCoachPlan? previousPlan;

  const WeeklyCoachInput({
    required this.now,
    this.wearableHistory = const [],
    this.workouts = const [],
    this.workoutSourceAvailable = true,
    this.primaryGoal = '',
    this.previousPlan,
  });
}

class WeeklyCoachEngine {
  const WeeklyCoachEngine();

  WeeklyCoachPlan evaluate(WeeklyCoachInput input) {
    final start = _monday(input.now);
    final completedStart = start.subtract(const Duration(days: 7));
    final previousStart = completedStart.subtract(const Duration(days: 7));
    final currentWearable = _wearable(
      input.wearableHistory,
      completedStart,
      start,
    );
    final previousWearable = _wearable(
      input.wearableHistory,
      previousStart,
      completedStart,
    );
    final baselineWearable = _wearable(
      input.wearableHistory,
      completedStart.subtract(const Duration(days: 28)),
      completedStart,
    );
    final currentWorkouts = _workouts(input.workouts, completedStart, start);
    final previousWorkouts = _workouts(
      input.workouts,
      previousStart,
      completedStart,
    );
    final sleep = _average(
      currentWearable.map((e) => e.sleepMinutes?.toDouble()),
    );
    final previousSleep = _average(
      previousWearable.map((e) => e.sleepMinutes?.toDouble()),
    );
    final baselineSleep = _average(
      baselineWearable.map((e) => e.sleepMinutes?.toDouble()),
    );
    final restingHr = _average(
      currentWearable.map((e) => e.restingHeartRateBpm),
    );
    final baselineHr = _average(
      baselineWearable.map((e) => e.restingHeartRateBpm),
    );
    final activity = _average(currentWearable.map((e) => e.steps?.toDouble()));
    final baselineActivity = _average(
      baselineWearable.map((e) => e.steps?.toDouble()),
    );
    final completed = currentWorkouts
        .where((e) => e.status == 'completed')
        .length;
    final priorCompleted = previousWorkouts
        .where((e) => e.status == 'completed')
        .length;
    final missedPlannedSessions = currentWorkouts
        .where((e) => e.status != 'completed')
        .length;
    final evidence = <String>[];

    final sleepLow =
        sleep != null && baselineSleep != null && sleep < baselineSleep - 30;
    final hrHigh =
        restingHr != null && baselineHr != null && restingHr >= baselineHr + 5;
    final loadHigh =
        activity != null &&
        baselineActivity != null &&
        activity > baselineActivity * 1.35;
    if (sleep != null && previousSleep != null) {
      final change = (sleep - previousSleep).round();
      evidence.add(
        'Average sleep changed by $change minutes versus the previous week.',
      );
    }
    if (sleep != null && baselineSleep != null) {
      evidence.add(
        'Average sleep was ${(sleep - baselineSleep).round()} minutes versus personal baseline.',
      );
    }
    if (input.workoutSourceAvailable && currentWorkouts.isNotEmpty) {
      evidence.add(
        '$completed of ${currentWorkouts.length} observed training sessions were completed.',
      );
      if (previousWorkouts.isNotEmpty) {
        evidence.add(
          'The previous week had $priorCompleted of ${previousWorkouts.length} observed sessions completed.',
        );
      }
    }
    if (restingHr != null && baselineHr != null) {
      evidence.add(
        'Resting heart rate was ${(restingHr - baselineHr).toStringAsFixed(1)} bpm versus personal baseline.',
      );
    }

    late WeeklyMissionType mission;
    if ((sleepLow && hrHigh) || (hrHigh && loadHigh)) {
      mission = WeeklyMissionType.protectRecovery;
    } else if (sleepLow) {
      mission = WeeklyMissionType.improveTrainingNightSleep;
    } else if (input.workoutSourceAvailable && missedPlannedSessions > 0) {
      mission = WeeklyMissionType.improveWorkoutConsistency;
    } else if (loadHigh) {
      mission = WeeklyMissionType.reduceActivityLoad;
    } else {
      mission = WeeklyMissionType.maintainSuccessfulBehavior;
    }

    final followUp = _followUp(
      input.previousPlan,
      input,
      completedStart,
      start,
    );
    if (input.previousPlan != null &&
        followUp.$1 != WeeklyMissionOutcome.success &&
        followUp.$1 != WeeklyMissionOutcome.insufficientData &&
        mission == WeeklyMissionType.maintainSuccessfulBehavior) {
      mission = input.previousPlan!.missionType;
    }
    final guidance = _guidance(
      mission,
      input.primaryGoal,
      hasPreviousPlan: input.previousPlan != null,
      adjustActions:
          input.previousPlan?.missionType == mission &&
          followUp.$1 == WeeklyMissionOutcome.unchanged,
    );
    final improvedSleep =
        sleep != null && previousSleep != null && sleep >= previousSleep + 15;
    final improvedTraining =
        input.workoutSourceAvailable && completed > priorCompleted;
    final biggestWin = improvedTraining
        ? 'You completed $completed sessions, up from $priorCompleted the week before.'
        : improvedSleep
        ? 'Average sleep improved by ${(sleep - previousSleep).round()} minutes from the previous week.'
        : completed > 0
        ? 'You completed $completed training ${completed == 1 ? 'session' : 'sessions'} last week.'
        : 'You now have a clear, manageable focus for this week.';
    final retrospective =
        currentWearable.isEmpty && !input.workoutSourceAvailable
        ? 'There is not enough reliable history for a detailed retrospective.'
        : 'Last week is summarized from available wearable and completed training records.';
    final limiting = sleepLow
        ? 'Sleep was below your personal baseline.'
        : hrHigh
        ? 'Recovery signals were less stable than your personal baseline.'
        : input.workoutSourceAvailable && missedPlannedSessions > 0
        ? 'Workout consistency was the clearest available constraint.'
        : 'No clear limiting pattern was supported by the available data.';
    final motivation = improvedTraining
        ? 'You increased completed sessions from $priorCompleted to $completed. This week keeps that progress focused on ${guidance.$1.toLowerCase()}.'
        : improvedSleep
        ? 'Sleep improved by ${(sleep - previousSleep).round()} minutes last week. This week builds on that measured change.'
        : completed > 0
        ? 'You completed $completed ${completed == 1 ? 'session' : 'sessions'} last week. The next step is to make that behavior easier to repeat.'
        : 'The available history does not show a reliable improvement yet, so this week uses one small focus instead of changing several things.';

    return WeeklyCoachPlan(
      weekStart: start,
      weekEnd: start.add(const Duration(days: 6)),
      shortRetrospective: retrospective,
      biggestWin: biggestWin,
      mainLimitingFactor: limiting,
      missionType: mission,
      missionTitle: guidance.$1,
      missionReason: guidance.$2,
      actionItems: guidance.$3,
      motivationContext: motivation,
      previousMissionTitle: input.previousPlan?.missionTitle,
      previousMissionOutcome: followUp.$1,
      followUpMessage: followUp.$2,
      dataCoverage: WeeklyCoachDataCoverage(
        wearableDays: currentWearable.length,
        workoutSourceAvailable: input.workoutSourceAvailable,
      ),
      evidence: List.unmodifiable(evidence),
      generatedAt: input.now,
    );
  }

  (WeeklyMissionOutcome, String) _followUp(
    WeeklyCoachPlan? prior,
    WeeklyCoachInput input,
    DateTime from,
    DateTime to,
  ) {
    if (prior == null) {
      return (
        WeeklyMissionOutcome.insufficientData,
        'There is no previous weekly mission to evaluate yet.',
      );
    }
    final priorFrom = from.subtract(const Duration(days: 7));
    final currentWearable = _wearable(input.wearableHistory, from, to);
    final olderWearable = _wearable(input.wearableHistory, priorFrom, from);
    double? current;
    double? older;
    bool higherIsBetter = true;
    switch (prior.missionType) {
      case WeeklyMissionType.improveTrainingNightSleep:
      case WeeklyMissionType.protectRecovery:
        current = _average(
          currentWearable.map((e) => e.sleepMinutes?.toDouble()),
        );
        older = _average(olderWearable.map((e) => e.sleepMinutes?.toDouble()));
      case WeeklyMissionType.reduceActivityLoad:
        current = _average(currentWearable.map((e) => e.steps?.toDouble()));
        older = _average(olderWearable.map((e) => e.steps?.toDouble()));
        higherIsBetter = false;
      case WeeklyMissionType.improveWorkoutConsistency:
      case WeeklyMissionType.maintainSuccessfulBehavior:
        if (!input.workoutSourceAvailable) {
          return (
            WeeklyMissionOutcome.insufficientData,
            'Last week\'s mission cannot be evaluated reliably because training history is unavailable.',
          );
        }
        final currentWorkouts = _workouts(input.workouts, from, to);
        final olderWorkouts = _workouts(input.workouts, priorFrom, from);
        if (currentWorkouts.isEmpty ||
            (prior.missionType == WeeklyMissionType.improveWorkoutConsistency &&
                olderWorkouts.isEmpty)) {
          return (
            WeeklyMissionOutcome.insufficientData,
            'Last week\'s mission cannot be evaluated reliably without observed training sessions in both comparison weeks.',
          );
        }
        final currentCompleted = currentWorkouts
            .where((e) => e.status == 'completed')
            .length;
        final olderCompleted = olderWorkouts
            .where((e) => e.status == 'completed')
            .length;
        final outcome =
            prior.missionType == WeeklyMissionType.maintainSuccessfulBehavior
            ? currentCompleted == currentWorkouts.length
                  ? WeeklyMissionOutcome.success
                  : currentCompleted > 0
                  ? WeeklyMissionOutcome.partialImprovement
                  : WeeklyMissionOutcome.unchanged
            : currentCompleted == currentWorkouts.length &&
                  olderCompleted < olderWorkouts.length
            ? WeeklyMissionOutcome.success
            : currentCompleted * olderWorkouts.length >
                  olderCompleted * currentWorkouts.length
            ? WeeklyMissionOutcome.partialImprovement
            : WeeklyMissionOutcome.unchanged;
        return (outcome, _followUpMessage(prior, outcome));
    }
    if (current == null || older == null) {
      return (
        WeeklyMissionOutcome.insufficientData,
        'Last week\'s mission cannot be evaluated reliably with the available data.',
      );
    }
    final delta = higherIsBetter ? current - older : older - current;
    final successThreshold =
        prior.missionType == WeeklyMissionType.improveWorkoutConsistency ||
            prior.missionType == WeeklyMissionType.maintainSuccessfulBehavior
        ? 1.0
        : (prior.missionType == WeeklyMissionType.reduceActivityLoad
              ? older * .15
              : 30.0);
    final outcome = delta >= successThreshold
        ? WeeklyMissionOutcome.success
        : delta > 0
        ? WeeklyMissionOutcome.partialImprovement
        : WeeklyMissionOutcome.unchanged;
    return (outcome, _followUpMessage(prior, outcome));
  }

  String _followUpMessage(
    WeeklyCoachPlan prior,
    WeeklyMissionOutcome outcome,
  ) => switch (outcome) {
    WeeklyMissionOutcome.success =>
      'Last week we focused on ${prior.missionTitle.toLowerCase()}. The measured outcome improved, so keep this behavior.',
    WeeklyMissionOutcome.partialImprovement =>
      'Last week\'s mission showed partial improvement. Continue the same priority while the pattern becomes more consistent.',
    WeeklyMissionOutcome.unchanged =>
      'Last week\'s mission has not improved yet. Keep the priority, but adjust the actions rather than repeating the same approach.',
    WeeklyMissionOutcome.insufficientData =>
      'Last week\'s mission cannot be evaluated reliably with the available data.',
  };

  (String, String, List<String>) _guidance(
    WeeklyMissionType type,
    String goal, {
    required bool hasPreviousPlan,
    required bool adjustActions,
  }) {
    final goalText = goal.trim().isEmpty
        ? 'your current goal'
        : goal.replaceAll('_', ' ');
    if (adjustActions) {
      return switch (type) {
        WeeklyMissionType.protectRecovery => (
          'Protect recovery this week',
          'Recovery is still the main priority, so this week narrows the approach to the easiest repeatable protections for $goalText.',
          [
            'Choose one lower-load day and protect it from optional extra work.',
            'Set one consistent wind-down reminder for training nights.',
          ],
        ),
        WeeklyMissionType.improveTrainingNightSleep => (
          'Improve sleep around training',
          'Sleep remains the clearest constraint, so this week simplifies the approach instead of repeating every prior action.',
          [
            'Choose one training night to start the wind-down routine 30 minutes earlier.',
            'Prepare the bedtime reminder before that training day begins.',
          ],
        ),
        WeeklyMissionType.improveWorkoutConsistency => (
          'Build workout consistency',
          'Consistency remains the main opportunity, so this week reduces friction instead of repeating the same approach.',
          [
            'Protect one realistic training window before adding another.',
            'Prepare the essential session steps before that training window.',
            'Record what blocked the session if it is not completed.',
          ],
        ),
        WeeklyMissionType.reduceActivityLoad => (
          'Keep activity load manageable',
          'Activity load remains the priority, so this week targets the clearest optional source rather than changing the whole routine.',
          [
            'Identify one source of optional extra activity and keep it easy this week.',
            'Preserve one lower-load day without adding conditioning.',
          ],
        ),
        WeeklyMissionType.maintainSuccessfulBehavior => (
          'Repeat last week’s consistency',
          'The pattern was not maintained yet, so this week makes one working behavior easier to repeat for $goalText.',
          [
            'Choose the single routine that was easiest to complete and schedule it first.',
            'Record whether that routine was completed so the next review has clear evidence.',
          ],
        ),
      };
    }
    return switch (type) {
      WeeklyMissionType.protectRecovery => (
        'Protect recovery this week',
        'Stable recovery supports consistent work toward $goalText.',
        [
          'Keep the planned training volume instead of adding extra work.',
          'Give sleep a consistent start time on training nights.',
          'Use an easier day when your existing recovery guidance calls for it.',
        ],
      ),
      WeeklyMissionType.improveTrainingNightSleep => (
        'Improve sleep around training',
        'Sleep was the clearest reliable constraint relative to your baseline and matters for consistent $goalText training.',
        [
          'Start bedtime 30 minutes earlier on training nights.',
          'Set a wind-down reminder before the first training day.',
          'Keep the planned session volume instead of adding extra work.',
        ],
      ),
      WeeklyMissionType.improveWorkoutConsistency => (
        'Build workout consistency',
        'Completed training frequency is the most useful current behavior for $goalText.',
        [
          'Choose two realistic training windows for this week.',
          'Start each planned session even if time only allows the essential work.',
          'Record the session outcome when you finish.',
        ],
      ),
      WeeklyMissionType.reduceActivityLoad => (
        'Keep activity load manageable',
        'Activity was above your personal pattern, so protecting planned training quality is the useful priority.',
        [
          'Keep unplanned activity easy on training days.',
          'Avoid adding extra conditioning after planned sessions.',
          'Preserve one lower-load day this week.',
        ],
      ),
      WeeklyMissionType.maintainSuccessfulBehavior => (
        hasPreviousPlan
            ? 'Repeat last week’s consistency'
            : 'Establish a steady weekly rhythm',
        hasPreviousPlan
            ? 'The available data does not support changing direction; repeating a working behavior best supports $goalText.'
            : 'There is not enough prior history for a confident change, so a steady, observable week best supports $goalText.',
        [
          'Keep the same realistic training windows.',
          'Protect the sleep routine that supported last week.',
          'Record completed sessions so next week can be evaluated.',
        ],
      ),
    };
  }

  DateTime _monday(DateTime value) {
    final local = value.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  List<WearableDailyRecord> _wearable(
    List<WearableDailyRecord> values,
    DateTime from,
    DateTime to,
  ) => values
      .where(
        (e) =>
            !e.localDate.isBefore(from) &&
            e.localDate.isBefore(to) &&
            e.hasMetrics,
      )
      .toList();
  List<WeeklyWorkoutObservation> _workouts(
    List<WeeklyWorkoutObservation> values,
    DateTime from,
    DateTime to,
  ) => values
      .where((e) => !e.date.isBefore(from) && e.date.isBefore(to))
      .toList();
  double? _average(Iterable<double?> values) {
    final valid = values.nonNulls.toList();
    return valid.isEmpty ? null : valid.reduce((a, b) => a + b) / valid.length;
  }
}
