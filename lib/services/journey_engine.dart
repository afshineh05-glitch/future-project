import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/journey.dart';

class JourneyEngine {
  const JourneyEngine();

  JourneyTimeline build(JourneySourceSnapshot source) {
    final events = <JourneyEvent>[];
    final add = events.add;
    final vision = _first(source.visions);
    final visionCreated = _date(vision?['created_at']);
    if (visionCreated != null) {
      add(
        _event(
          'vision-created',
          JourneyEventType.visionCreated,
          visionCreated,
          'You chose a direction',
          'Your Vision gives the work ahead a clear identity.',
          JourneyEventCategory.identity,
          'vision_profiles',
          'vision',
        ),
      );
    }
    final visionUpdated = _date(vision?['updated_at']);
    if (visionCreated != null &&
        visionUpdated != null &&
        visionUpdated.difference(visionCreated).inMinutes.abs() > 1) {
      add(
        _event(
          'vision-updated',
          JourneyEventType.visionUpdated,
          visionUpdated,
          'Your direction became clearer',
          'You meaningfully updated the identity you are building toward.',
          JourneyEventCategory.identity,
          'vision_profiles',
          'vision',
        ),
      );
    }
    final futureSelf = _date(vision?['future_self_generated_at']);
    if (futureSelf != null) {
      add(
        _event(
          'future-self-generated',
          JourneyEventType.futureSelfGenerated,
          futureSelf,
          'You pictured the future self',
          'A generated Future Self gave your direction a tangible reference.',
          JourneyEventCategory.identity,
          'vision_profiles',
          'vision',
        ),
      );
    }
    final foundation = _first(source.foundations);
    if (foundation?['is_completed'] == true) {
      final date =
          _date(foundation?['completed_at']) ??
          _date(foundation?['updated_at']) ??
          _date(foundation?['created_at']);
      if (date != null) {
        add(
          _event(
            'foundation-completed',
            JourneyEventType.foundationCompleted,
            date,
            'You established your foundation',
            'Your goals and baseline now anchor the changes that follow.',
            JourneyEventCategory.foundation,
            'user_foundations',
            'foundation',
          ),
        );
      }
    }
    final plan = _first(source.plans);
    final planDate = _date(plan?['created_at']);
    if (planDate != null) {
      add(
        _event(
          'training-plan-${_id(plan) ?? _key(planDate)}',
          JourneyEventType.trainingPlanCreated,
          planDate,
          'You committed to a training plan',
          'A verified plan turned intention into a repeatable path.',
          JourneyEventCategory.training,
          'training_plans',
          'training_plan',
        ),
      );
    }

    final completed =
        source.workouts
            .where((row) => row['status']?.toString() == 'completed')
            .toList()
          ..sort(
            (a, b) =>
                (_date(a['completed_at']) ??
                        _date(a['scheduled_at']) ??
                        DateTime(1900))
                    .compareTo(
                      _date(b['completed_at']) ??
                          _date(b['scheduled_at']) ??
                          DateTime(1900),
                    ),
          );
    if (completed.isNotEmpty) {
      final first =
          _date(completed.first['completed_at']) ??
          _date(completed.first['scheduled_at']);
      if (first != null) {
        add(
          _event(
            'first-workout-${_id(completed.first) ?? _key(first)}',
            JourneyEventType.firstWorkoutCompleted,
            first,
            'You completed your first workout',
            'The first verified session made your new identity visible in action.',
            JourneyEventCategory.training,
            'workout_sessions',
            'training_plan',
          ),
        );
      }
      final dates = _distinctDates(
        completed.map(
          (row) => _date(row['completed_at']) ?? _date(row['scheduled_at']),
        ),
      );
      if (dates.length >= 7 &&
          dates.last.difference(dates.first).inDays >= 13) {
        add(
          _event(
            'training-consistency',
            JourneyEventType.trainingConsistencyEstablished,
            dates[6],
            'Your training is becoming consistent',
            'Repeated verified sessions show a routine taking shape.',
            JourneyEventCategory.consistency,
            'workout_sessions',
            'training_plan',
          ),
        );
      }
      for (var i = 1; i < dates.length; i++) {
        if (dates[i].difference(dates[i - 1]).inDays >= 4) {
          add(
            _event(
              'returned-${_key(dates[i])}',
              JourneyEventType.returnedAfterGap,
              dates[i],
              'You came back',
              'Returning after a meaningful gap kept your journey moving.',
              JourneyEventCategory.consistency,
              'workout_sessions',
              'training_plan',
            ),
          );
          break;
        }
      }
    }
    if (source.nutrition.isNotEmpty) {
      final dates =
          source.nutrition
              .map((r) => _date(r['consumed_at']) ?? _date(r['created_at']))
              .whereType<DateTime>()
              .toList()
            ..sort();
      if (dates.isNotEmpty) {
        add(
          _event(
            'nutrition-started',
            JourneyEventType.nutritionJourneyStarted,
            dates.first,
            'You started fueling your goal',
            'Your verified nutrition choices are now part of the transformation story.',
            JourneyEventCategory.nutrition,
            'nutrition_food_logs',
            'nutrition',
          ),
        );
      }
    }
    for (final row in source.bodyProgress) {
      final date = _date(row['checked_at']) ?? _date(row['created_at']);
      final id = _id(row);
      if (date != null && id != null) {
        add(
          _event(
            'body-check-$id',
            JourneyEventType.bodyProgressCheckCompleted,
            date,
            'You recorded a body progress check',
            'A verified check preserves the evidence of where you are now.',
            JourneyEventCategory.progress,
            'body_progress_checks',
            'body_progress',
          ),
        );
      }
    }
    if (_meaningfulBodyProgress(source.bodyProgress)) {
      final sorted =
          source.bodyProgress
              .map((r) => _date(r['checked_at']) ?? _date(r['created_at']))
              .whereType<DateTime>()
              .toList()
            ..sort();
      if (sorted.length >= 2) {
        add(
          _event(
          'meaningful-body-progress',
            JourneyEventType.meaningfulBodyProgressDetected,
            sorted.last,
            'Your recorded progress is becoming visible',
            'Repeated measurements provide a verified comparison over time.',
            JourneyEventCategory.progress,
            'body_progress_checks',
            'body_progress',
          ),
        );
      }
    }
    for (final row in source.milestones.where(
      (r) => r['status']?.toString() == 'completed',
    )) {
      final date = _date(row['completed_at']);
      final id = _id(row) ?? row['id']?.toString();
      if (date != null && id != null) {
        add(
          _event(
            'milestone-$id',
            JourneyEventType.milestoneCompleted,
            date,
            row['title']?.toString() ?? 'You reached a milestone',
            'A verified milestone marks progress already earned.',
            JourneyEventCategory.progress,
            'VisionMilestonesEngine',
            'vision_milestones',
          ),
        );
      }
    }
    for (final row in source.behaviorPatterns.where(
      (r) => r['retired_at'] == null,
    )) {
      final fingerprint = row['fingerprint']?.toString();
      final date = _date(row['learned_at']);
      if (fingerprint != null && date != null) {
        add(
          _event(
            'behavior-$fingerprint',
            JourneyEventType.behaviorPatternEstablished,
            date,
            'A pattern became part of your process',
            row['coach_hint']?.toString() ??
                'Repeated evidence revealed a stable routine.',
            JourneyEventCategory.consistency,
            'behavior_patterns',
            'todays_coach',
          ),
        );
      }
    }
    for (final row in source.weeklyPlans) {
      final date = _date(row['updated_at']) ?? _date(row['generated_at']);
      final id = row['week_start']?.toString() ?? _id(row) ?? _key(date);
      if (date != null && id != null && row['evidence'] != null) {
        add(
          _event(
            'weekly-progress-$id',
            JourneyEventType.weeklyPriorityProgressConfirmed,
            date,
            'Your weekly priority moved forward',
            'Weekly Coach evidence confirmed progress toward the priority you chose.',
            JourneyEventCategory.consistency,
            'coach_weekly_plans',
            'weekly_coach',
          ),
        );
      }
    }
    final unique = <String, JourneyEvent>{
      for (final event in events) event.identity: event,
    };
    final ordered = unique.values.toList()
      ..sort((a, b) {
        final date = b.occurredAt.compareTo(a.occurredAt);
        return date == 0 ? a.identity.compareTo(b.identity) : date;
      });
    final stage = _stage(ordered);
    final nextTitle = source.nextMilestoneTitle ?? source.todayMissionTitle;
    final nextMeaning = source.nextMilestoneTitle != null
        ? source.nextMilestoneMeaning
        : source.todayMissionMeaning;
    final nextDestination = source.nextMilestoneTitle != null
        ? source.nextMilestoneDestination
        : source.todayMissionDestination;
    return JourneyTimeline(
      stage: stage,
      events: List.unmodifiable(ordered),
      nextChapterTitle: nextTitle,
      nextChapterMeaning: nextMeaning,
      nextChapterDestination: nextDestination,
      partial: source.partial,
    );
  }

  JourneyEvent _event(
    String id,
    JourneyEventType type,
    DateTime date,
    String title,
    String meaning,
    JourneyEventCategory category,
    String source,
    String? destination,
  ) => JourneyEvent(
    identity: id,
    type: type,
    occurredAt: date.toLocal(),
    title: title,
    meaning: meaning,
    category: category,
    verifiedSource: source,
    destination: destination,
  );

  VisionJourneyStage _stage(List<JourneyEvent> events) {
    if (events.any(
      (e) => e.type == JourneyEventType.meaningfulBodyProgressDetected,
    )) {
      return VisionJourneyStage.livingIt;
    }
    if (events.any(
      (e) =>
          e.type == JourneyEventType.trainingConsistencyEstablished ||
          e.type == JourneyEventType.behaviorPatternEstablished,
    )) {
      return VisionJourneyStage.becoming;
    }
    if (events.any(
      (e) =>
          e.type == JourneyEventType.firstWorkoutCompleted ||
          e.type == JourneyEventType.nutritionJourneyStarted,
    )) {
      return VisionJourneyStage.building;
    }
    return VisionJourneyStage.starting;
  }

  Map<String, dynamic>? _first(List<Map<String, dynamic>> rows) =>
      rows.isEmpty ? null : rows.first;
  String? _id(Map<String, dynamic>? row) => row?['id']?.toString();
  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());
  String? _key(DateTime? date) =>
      date == null ? null : '${date.year}-${date.month}-${date.day}';
  List<DateTime> _distinctDates(Iterable<DateTime?> values) {
    final map = <String, DateTime>{};
    for (final value in values) {
      if (value == null) continue;
      final d = value.toLocal();
      final day = DateTime(d.year, d.month, d.day);
      map[_key(day)!] = day;
    }
    return map.values.toList()..sort();
  }

  bool _meaningfulBodyProgress(List<Map<String, dynamic>> rows) {
    if (rows.length < 2) return false;
    final sorted = [...rows]
      ..sort(
        (a, b) =>
            (_date(a['checked_at']) ?? _date(a['created_at']) ?? DateTime(1900))
                .compareTo(
                  _date(b['checked_at']) ??
                      _date(b['created_at']) ??
                      DateTime(1900),
                ),
      );
    final first = sorted.first;
    final last = sorted.last;
    for (final key in const [
      'weight',
      'waist',
      'chest',
      'hips',
      'arm',
      'thigh',
      'neck',
    ]) {
      final start = double.tryParse(first[key]?.toString() ?? '');
      final end = double.tryParse(last[key]?.toString() ?? '');
      if (start != null &&
          start > 0 &&
          end != null &&
          ((end - start).abs() / start) >= 0.02) {
        return true;
      }
    }
    return false;
  }
}
