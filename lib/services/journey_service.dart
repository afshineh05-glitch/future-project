import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/journey.dart';
import 'package:future_project/services/journey_engine.dart';

abstract interface class JourneySourceReader {
  String? get currentUserId;
  Future<JourneySourceSnapshot> read(String userId);
}

class SupabaseJourneySourceReader implements JourneySourceReader {
  final SupabaseClient _supabase;

  SupabaseJourneySourceReader([SupabaseClient? supabase])
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<JourneySourceSnapshot> read(String userId) async {
    var partial = false;
    Future<List<Map<String, dynamic>>> source(
      String table,
      String columns,
    ) async {
      try {
        final rows = await _supabase
            .from(table)
            .select(columns)
            .eq('user_id', userId);
        return rows.cast<Map<String, dynamic>>();
      } catch (_) {
        partial = true;
        return const <Map<String, dynamic>>[];
      }
    }

    final results = await Future.wait<List<Map<String, dynamic>>>([
      source(
        'vision_profiles',
        'created_at, updated_at, future_self_generated_at',
      ),
      source(
        'user_foundations',
        'id, created_at, updated_at, completed_at, is_completed',
      ),
      source('training_plans', 'id, created_at, updated_at'),
      source('workout_sessions', 'id, status, scheduled_at, completed_at'),
      source('nutrition_food_logs', 'id, consumed_at, created_at'),
      source(
        'body_progress_checks',
        'id, checked_at, created_at, weight, waist, chest, hips, arm, thigh, neck',
      ),
      source(
        'behavior_patterns',
        'fingerprint, learned_at, coach_hint, retired_at',
      ),
      source(
        'coach_weekly_plans',
        'week_start, week_end, updated_at, generated_at, mission_title, mission_reason, evidence',
      ),
    ]);
    if (currentUserId != userId) {
      throw StateError('Journey account changed while loading.');
    }
    final milestones = _milestoneRows(results[3], results[4], results[5]);
    final weekly = results[7];
    final latestWeekly = weekly.isEmpty
        ? null
        : (weekly..sort(
                (a, b) => (_date(b['updated_at']) ?? DateTime(1970)).compareTo(
                  _date(a['updated_at']) ?? DateTime(1970),
                ),
              ))
              .first;
    return JourneySourceSnapshot(
      visions: results[0],
      foundations: results[1],
      plans: results[2],
      workouts: results[3],
      nutrition: results[4],
      bodyProgress: results[5],
      milestones: milestones,
      behaviorPatterns: results[6],
      weeklyPlans: weekly,
      nextMilestoneTitle: _nextMilestoneTitle(
        results[3],
        results[4],
        results[5],
      ),
      nextMilestoneMeaning:
          'Your next verified progress marker will become part of the story as it is recorded.',
      nextMilestoneDestination: 'vision_milestones',
      todayMissionTitle: latestWeekly?['mission_title']?.toString(),
      todayMissionMeaning: latestWeekly?['mission_reason']?.toString(),
      todayMissionDestination: latestWeekly == null ? null : 'todays_coach',
      partial: partial,
    );
  }

  List<Map<String, dynamic>> _milestoneRows(
    List<Map<String, dynamic>> workouts,
    List<Map<String, dynamic>> nutrition,
    List<Map<String, dynamic>> body,
  ) {
    final completed =
        workouts
            .where(
              (row) =>
                  row['status'] == 'completed' &&
                  (_date(row['completed_at']) ?? _date(row['scheduled_at'])) !=
                      null,
            )
            .toList()
          ..sort(
            (a, b) => (_date(a['completed_at']) ?? _date(a['scheduled_at']))!
                .compareTo(
                  (_date(b['completed_at']) ?? _date(b['scheduled_at']))!,
                ),
          );
    final dates = <String, DateTime>{};
    for (final row in completed) {
      final date = _date(row['completed_at']) ?? _date(row['scheduled_at']);
      if (date != null) dates[_dayKey(date)] = date;
    }
    final rows = <Map<String, dynamic>>[];
    for (final threshold in const [1, 5, 10, 25, 50]) {
      if (completed.length >= threshold) {
        rows.add({
          'id': 'workouts-$threshold',
          'title': '$threshold ${threshold == 1 ? 'Workout' : 'Workouts'}',
          'status': 'completed',
          'completed_at':
              (_date(completed[threshold - 1]['completed_at']) ??
                      _date(completed[threshold - 1]['scheduled_at']))!
                  .toIso8601String(),
        });
      }
    }
    final nutritionDays = <String>{};
    for (final row in nutrition) {
      final date = _date(row['consumed_at']) ?? _date(row['created_at']);
      if (date != null) nutritionDays.add(_dayKey(date));
    }
    for (final threshold in const [1, 7, 30]) {
      if (nutritionDays.length >= threshold) {
        final sorted = nutritionDays.toList()..sort();
        rows.add({
          'id': 'nutrition-days-$threshold',
          'title': '$threshold Nutrition Days',
          'status': 'completed',
          'completed_at': DateTime.parse(
            sorted[threshold - 1],
          ).toIso8601String(),
        });
      }
    }
    for (final row in body) {
      final id = row['id']?.toString();
      final date = _date(row['checked_at']) ?? _date(row['created_at']);
      if (id != null && date != null) {
        rows.add({
          'id': 'body-$id',
          'title': 'Body Progress Check',
          'status': 'completed',
          'completed_at': date.toIso8601String(),
        });
      }
    }
    return rows;
  }

  String? _nextMilestoneTitle(
    List<Map<String, dynamic>> workouts,
    List<Map<String, dynamic>> nutrition,
    List<Map<String, dynamic>> body,
  ) {
    final count = workouts.where((r) => r['status'] == 'completed').length;
    for (final target in const [1, 5, 10, 25, 50]) {
      if (count < target) {
        return 'Complete ${target == 1 ? 'your first verified workout' : '$target verified workouts'}';
      }
    }
    if (nutrition.isEmpty) return 'Record your first nutrition day';
    if (body.length < 2) return 'Complete your next Body Progress Check';
    return null;
  }

  DateTime? _date(dynamic value) => DateTime.tryParse(value?.toString() ?? '');
  String _dayKey(DateTime value) {
    final d = value.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

class JourneyService {
  final JourneySourceReader _reader;
  final JourneyEngine _engine;
  Future<JourneyTimeline>? _inFlight;
  String? _inFlightUser;

  JourneyService({JourneySourceReader? reader, JourneyEngine? engine})
    : _reader = reader ?? SupabaseJourneySourceReader(),
      _engine = engine ?? const JourneyEngine();

  Future<JourneyTimeline> load() {
    final userId = _reader.currentUserId;
    if (userId == null) {
      return Future<JourneyTimeline>.error(StateError('Sign in required.'));
    }
    if (_inFlight != null && _inFlightUser == userId) return _inFlight!;
    final request = _load(userId);
    _inFlightUser = userId;
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) {
        _inFlight = null;
        _inFlightUser = null;
      }
    });
  }

  Future<JourneyTimeline> _load(String userId) async {
    final snapshot = await _reader.read(userId);
    if (_reader.currentUserId != userId) {
      throw StateError('Journey account changed.');
    }
    return _engine.build(snapshot);
  }

  void clear() {
    _inFlight = null;
    _inFlightUser = null;
  }
}
