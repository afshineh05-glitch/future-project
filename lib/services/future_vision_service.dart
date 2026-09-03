import 'package:future_project/models/body_progress.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:future_project/models/vision_intelligence.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/services/body_progress_service.dart';
import 'package:future_project/services/vision_body_progress_engine.dart';
import 'package:future_project/services/vision_milestones_engine.dart';
import 'package:future_project/services/vision_progress_engine.dart';
import 'package:future_project/services/vision_intelligence_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FutureVisionService {
  final SupabaseClient _supabase;
  final VisionProgressEngine _progressEngine;
  final VisionMilestonesEngine _milestonesEngine;
  final BodyProgressService _bodyProgressService;
  final VisionBodyProgressEngine _bodyProgressEngine;
  final VisionIntelligenceEngine _intelligenceEngine;

  FutureVisionService({
    SupabaseClient? supabase,
    VisionProgressEngine progressEngine = const VisionProgressEngine(),
    VisionMilestonesEngine milestonesEngine = const VisionMilestonesEngine(),
    BodyProgressService? bodyProgressService,
    VisionBodyProgressEngine bodyProgressEngine =
        const VisionBodyProgressEngine(),
    VisionIntelligenceEngine intelligenceEngine =
        const VisionIntelligenceEngine(),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _progressEngine = progressEngine,
       _milestonesEngine = milestonesEngine,
       _bodyProgressService =
           bodyProgressService ??
           BodyProgressService(supabase: supabase ?? Supabase.instance.client),
       _bodyProgressEngine = bodyProgressEngine,
       _intelligenceEngine = intelligenceEngine;

  Future<FutureVisionState> load() async {
    final user = _requireUser();
    final today = DateTime.now();
    final todayKey = _dateKey(today);
    final localStart = DateTime(today.year, today.month, today.day);
    final localEnd = localStart.add(const Duration(days: 1));

    final results = await Future.wait<dynamic>([
      _supabase
          .from('vision_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle(),
      _supabase
          .from('user_foundations')
          .select()
          .eq('user_id', user.id)
          .maybeSingle(),
      _supabase
          .from('training_plans')
          .select('id, goal, cycle_start, created_at')
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle(),
      _supabase
          .from('nutrition_food_logs')
          .select('id, consumed_at')
          .eq('user_id', user.id)
          .order('consumed_at', ascending: false),
      _supabase
          .from('vision_daily_reflections')
          .select()
          .eq('user_id', user.id)
          .order('reflection_date', ascending: false),
      _loadOptionalWorkoutHistory(user.id),
      _loadOptionalBodyProgressHistory(),
      _loadOptionalMyWhyMetadata(user.id),
    ]);

    final visionRow = results[0] as Map<String, dynamic>?;
    final foundation = results[1] as Map<String, dynamic>?;
    final plan = results[2] as Map<String, dynamic>?;
    final nutritionRows = (results[3] as List).cast<Map<String, dynamic>>();
    final reflectionRows = (results[4] as List).cast<Map<String, dynamic>>();
    final workoutRows = (results[5] as List).cast<Map<String, dynamic>>();
    final bodyProgressResult = results[6] as List<BodyProgressCheck>?;
    final myWhy = results[7] as VisionMyWhyMetadata;
    final bodyProgressHistory =
        bodyProgressResult ?? const <BodyProgressCheck>[];
    final bodyProgressChecks = bodyProgressHistory
        .map((item) => item.toVisionCheck())
        .toList(growable: false);
    final vision = visionRow == null ? null : FutureVision.fromMap(visionRow);

    List<Map<String, dynamic>> trainingDays = const [];
    if (plan != null) {
      final rows = await _supabase
          .from('training_days')
          .select('day_number, title, focus')
          .eq('plan_id', plan['id'])
          .order('day_number');
      trainingDays = rows.cast<Map<String, dynamic>>();
    }

    final reflections = reflectionRows
        .map(VisionReflection.fromMap)
        .toList(growable: false);
    final nutritionDates = _distinctDates(
      nutritionRows.map((row) => _parseDate(row['consumed_at'])?.toLocal()),
    );
    final completedWorkoutRows = workoutRows
        .where((row) => row['status'] == 'completed')
        .toList(growable: false);
    final trainingDates = _distinctDates(
      completedWorkoutRows.map(
        (row) =>
            _parseDate(row['completed_at'] ?? row['scheduled_at'])?.toLocal(),
      ),
    );
    final behaviorDates = _distinctDates([
      ...trainingDates,
      ...nutritionDates,
      ...reflections.map((item) => item.date.toLocal()),
    ]);
    final behavior = VisionBehaviorSummary(
      completedWorkoutCount: completedWorkoutRows.length,
      trainingActiveDates: trainingDates,
      nutritionLogCount: nutritionRows.length,
      nutritionActiveDates: nutritionDates,
      reflectionHistory: reflections,
      activeBehaviorDates: behaviorDates,
      returnedAfterGap: _isRecentReturnAfterGap(behaviorDates, today),
    );
    final evidenceCandidates = _evidenceFor(
      vision: vision,
      foundation: foundation,
      plan: plan,
      trainingDayCount: trainingDays.length,
      behavior: behavior,
      bodyProgressHistory: bodyProgressHistory,
    );
    final todayReflection = reflections.cast<VisionReflection?>().firstWhere(
      (item) => item != null && _dateKey(item.date.toLocal()) == todayKey,
      orElse: () => null,
    );
    final hasNutritionToday = nutritionRows.any((row) {
      final consumedAt = _parseDate(row['consumed_at'])?.toLocal();
      return consumedAt != null &&
          !consumedAt.isBefore(localStart) &&
          consumedAt.isBefore(localEnd);
    });
    final progressInput = VisionProgressInput(
      foundation: _foundationBaseline(foundation),
      bodyProgressChecks: bodyProgressChecks,
      trainingSessions: _trainingSessions(workoutRows),
      wearable: null,
      nutritionLogCount: nutritionRows.length,
      nutritionActiveDates: nutritionDates,
      now: today,
    );
    final progress = _progressEngine.evaluate(progressInput);
    final canonicalMilestones = _milestonesEngine.evaluate(progressInput);
    final recentCutoff = today.subtract(const Duration(days: 14));
    final milestones = _milestonesEngine.personalize(
      canonicalMilestones,
      VisionMilestonePersonalizationContext(
        primaryGoal: progressInput.foundation.primaryGoal.isNotEmpty
            ? progressInput.foundation.primaryGoal
            : vision?.primaryGoal ?? '',
        returnedAfterGap: behavior.returnedAfterGap,
        hasRecentTraining: behavior.trainingActiveDates.any(
          (date) => !date.isBefore(recentCutoff),
        ),
        hasRecentNutrition: behavior.nutritionActiveDates.any(
          (date) => !date.isBefore(recentCutoff),
        ),
      ),
    );
    final bodyProgressCycle = bodyProgressResult == null
        ? null
        : _bodyProgressCycle(
            foundation: foundation,
            history: bodyProgressHistory,
            now: today,
          );
    final todayAction = _todayAction(
      plan,
      trainingDays,
      hasNutritionToday,
      bodyProgressCycle,
    );
    final intelligence = _intelligenceEngine.interpret(
      VisionIntelligenceInput(
        vision: vision,
        canonicalInput: progressInput,
        progress: progress,
        milestones: milestones,
        behavior: behavior,
        evidence: evidenceCandidates,
        todayAction: todayAction,
        hasTrainingPlan: plan != null,
        myWhy: myWhy,
      ),
    );

    return FutureVisionState(
      vision: vision,
      foundationGoal: foundation?['primary_goal']?.toString() ?? '',
      stage: intelligence.phase.journeyStage,
      evidence: intelligence.rankedEvidence,
      todayAction: VisionTodayAction(
        action: todayAction.action,
        source: todayAction.source,
        explanation: intelligence.todayExplanation,
        ctaLabel: todayAction.ctaLabel,
        destination: todayAction.destination,
        isRecovery: todayAction.isRecovery,
      ),
      todayReflection: todayReflection,
      reflectionCount: reflections.length,
      meaningfulSignalCount: evidenceCandidates.length,
      futureSelfMessage: intelligence.futureSelfMessage,
      behaviorSummary: behavior,
      progress: progress,
      milestones: milestones,
      intelligence: intelligence,
    );
  }

  Future<VisionMyWhyMetadata> _loadOptionalMyWhyMetadata(String userId) async {
    try {
      final row = await _supabase
          .from('my_why_entries')
          .select('has_text, has_voice, has_video')
          .eq('user_id', userId)
          .maybeSingle();
      return VisionMyWhyMetadata(
        exists: row != null,
        hasText: row?['has_text'] == true,
        hasVoice: row?['has_voice'] == true,
        hasVideo: row?['has_video'] == true,
      );
    } catch (_) {
      return const VisionMyWhyMetadata();
    }
  }

  /// Completed-workout history is an optional enrichment source.
  ///
  /// Some deployed projects predate the adaptive training history schema. A
  /// missing table, stale PostgREST schema cache, permission error, or other
  /// history-only failure must not prevent the user's Vision, reflections,
  /// Foundation, Training Plan, or nutrition evidence from loading.
  Future<List<Map<String, dynamic>>> _loadOptionalWorkoutHistory(
    String userId,
  ) async {
    try {
      final rows = await _supabase
          .from('workout_sessions')
          .select('id, scheduled_at, completed_at, status')
          .eq('user_id', userId)
          .order('scheduled_at', ascending: false);
      return rows.cast<Map<String, dynamic>>();
    } catch (_) {
      return const <Map<String, dynamic>>[];
    }
  }

  /// Body Progress enriches My Vision, but a pending migration or temporary
  /// history failure must not make the rest of My Vision unavailable.
  Future<List<BodyProgressCheck>?> _loadOptionalBodyProgressHistory() async {
    try {
      return await _bodyProgressService.loadHistory();
    } catch (_) {
      return null;
    }
  }

  Future<FutureVision> saveVision({
    required String primaryGoal,
    required List<String> desiredFeelings,
  }) async {
    final user = _requireUser();
    final identity = generateIdentity(primaryGoal, desiredFeelings);
    final row = await _supabase
        .from('vision_profiles')
        .upsert({
          'user_id': user.id,
          'primary_goal': primaryGoal,
          'future_identity': identity,
          'desired_feelings': desiredFeelings,
          'vision_statement': 'This is who I\'m becoming.',
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'user_id')
        .select()
        .single();
    return FutureVision.fromMap(row);
  }

  Future<void> saveReflection({required String response, String? note}) async {
    final user = _requireUser();
    final now = DateTime.now();
    await _supabase.from('vision_daily_reflections').upsert({
      'user_id': user.id,
      'reflection_date': _dateKey(now),
      'reflection_value': response,
      'note': note?.trim().isEmpty == true ? null : note?.trim(),
      'updated_at': now.toUtc().toIso8601String(),
    }, onConflict: 'user_id,reflection_date');
  }

  VisionFoundationBaseline _foundationBaseline(
    Map<String, dynamic>? foundation,
  ) {
    if (foundation == null) return const VisionFoundationBaseline();
    final measurements = <String, double>{};
    for (final entry in const {
      'waist': 'waist_cm',
      'chest': 'chest_cm',
      'hips': 'hips_cm',
      'arm': 'arm_cm',
      'thigh': 'thigh_cm',
      'neck': 'neck_cm',
    }.entries) {
      final value = _double(foundation[entry.value]);
      if (value != null) measurements[entry.key] = value;
    }
    return VisionFoundationBaseline(
      exists: true,
      completed: foundation['is_completed'] == true,
      primaryGoal: foundation['primary_goal']?.toString() ?? '',
      startingWeightKg: _double(foundation['weight_kg']),
      targetWeightKg: _double(foundation['target_weight_kg']),
      measurementsCm: measurements,
    );
  }

  List<VisionTrainingSession> _trainingSessions(
    List<Map<String, dynamic>> rows,
  ) => rows
      .map((row) {
        final scheduledAt = _parseDate(row['scheduled_at']);
        if (scheduledAt == null) return null;
        return VisionTrainingSession(
          scheduledAt: scheduledAt,
          completedAt: _parseDate(row['completed_at']),
          status: switch (row['status']?.toString()) {
            'completed' => VisionTrainingSessionStatus.completed,
            'skipped' => VisionTrainingSessionStatus.skipped,
            _ => VisionTrainingSessionStatus.partial,
          },
        );
      })
      .whereType<VisionTrainingSession>()
      .toList(growable: false);

  String generateIdentity(String goal, List<String> feelings) {
    final qualities = <String>[];
    final goalQuality = switch (goal) {
      'fat_loss' => 'LEANER',
      'build_muscle' || 'muscle_gain' => 'MORE MUSCULAR',
      'feel_healthier' || 'health' => 'HEALTHIER',
      'become_stronger' => 'STRONGER',
      'improve_fitness' || 'fitness' => 'FITTER',
      'athletic_performance' => 'MORE ATHLETIC',
      _ => 'HEALTHIER',
    };
    qualities.add(goalQuality);
    for (final feeling in feelings) {
      final value = feeling.trim().toUpperCase();
      if (value.isNotEmpty && !qualities.contains(value)) qualities.add(value);
    }
    return qualities.take(3).join(' • ');
  }

  List<VisionEvidence> _evidenceFor({
    required FutureVision? vision,
    required Map<String, dynamic>? foundation,
    required Map<String, dynamic>? plan,
    required int trainingDayCount,
    required VisionBehaviorSummary behavior,
    required List<BodyProgressCheck> bodyProgressHistory,
  }) {
    final evidence = <VisionEvidence>[];
    if (vision != null) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.visionStarted,
          label: 'You chose the future you\'re working toward',
          detail: 'Your Vision gives every next action a direction.',
          priority: 20,
          occurredAt: vision.createdAt,
        ),
      );
    }
    if (foundation?['is_completed'] == true) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.foundationCompleted,
          label: 'You created a clear starting point',
          detail: 'Your goals and baseline now give your journey direction.',
          priority: 15,
          occurredAt: _parseDate(foundation?['completed_at']),
        ),
      );
    }
    final bodyProgressEvidence = _bodyProgressEngine.evidenceFor(
      bodyProgressHistory,
    );
    if (bodyProgressEvidence != null) evidence.add(bodyProgressEvidence);
    if (plan != null) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.trainingPlanCreated,
          label: 'You committed to a training plan',
          detail: trainingDayCount == 0
              ? 'Your planned training now has a place in your path.'
              : '$trainingDayCount planned ${trainingDayCount == 1 ? 'session is' : 'sessions are'} ready for your week.',
          priority: 30,
          occurredAt: _parseDate(plan['created_at']),
        ),
      );
    }

    if (behavior.completedWorkoutCount > 0) {
      final consistent = _hasConsistency(behavior.trainingActiveDates);
      evidence.add(
        VisionEvidence(
          type: consistent
              ? VisionEvidenceType.trainingConsistency
              : VisionEvidenceType.workoutCompleted,
          label: consistent
              ? 'Your training is becoming consistent'
              : 'You completed planned training',
          detail: consistent
              ? 'You completed workouts on ${behavior.trainingActiveDates.length} different days.'
              : '${behavior.completedWorkoutCount} completed ${behavior.completedWorkoutCount == 1 ? 'workout is' : 'workouts are'} proof that you are moving forward.',
          priority: consistent ? 110 : 75,
          occurredAt: behavior.trainingActiveDates.last,
        ),
      );
    }

    final nutritionConsistent = _hasConsistency(behavior.nutritionActiveDates);
    if (nutritionConsistent) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.nutritionConsistency,
          label: 'Your nutrition habits are becoming part of the process',
          detail:
              'You confirmed meals on ${behavior.nutritionActiveDates.length} different days.',
          priority: 90,
          occurredAt: behavior.nutritionActiveDates.last,
        ),
      );
    } else if (behavior.nutritionLogCount > 0) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.nutritionStarted,
          label: 'You started fueling your goal',
          detail:
              '${behavior.nutritionLogCount} confirmed ${behavior.nutritionLogCount == 1 ? 'meal is' : 'meals are'} now connected to your nutrition plan.',
          priority: 60,
          occurredAt: behavior.nutritionActiveDates.last,
        ),
      );
    }

    final reflectionDates = _distinctDates(
      behavior.reflectionHistory.map((item) => item.date.toLocal()),
    );
    final reflectionsConsistent = _hasConsistency(reflectionDates);
    if (reflectionsConsistent) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.reflectionConsistency,
          label: 'You kept checking in with yourself',
          detail:
              '${reflectionDates.length} reflection days are helping you notice your patterns.',
          priority: 80,
          occurredAt: reflectionDates.last,
        ),
      );
    } else if (behavior.reflectionHistory.isNotEmpty) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.reflectionStarted,
          label: 'You started checking in with yourself',
          detail: 'Your reflections are becoming part of your journey.',
          priority: 55,
          occurredAt: behavior.reflectionHistory.first.date,
        ),
      );
    }

    if (behavior.returnedAfterGap) {
      evidence.add(
        VisionEvidence(
          type: VisionEvidenceType.returnedAfterGap,
          label: 'You came back',
          detail: 'Missing time didn\'t end your journey. Returning matters.',
          priority: 100,
          occurredAt: behavior.activeBehaviorDates.last,
        ),
      );
    }
    return evidence;
  }

  VisionTodayAction _todayAction(
    Map<String, dynamic>? plan,
    List<Map<String, dynamic>> days,
    bool hasNutritionToday,
    BodyProgressCycle? bodyProgressCycle,
  ) {
    final bodyProgressAction = _bodyProgressEngine.dueActionFor(
      bodyProgressCycle,
    );
    if (bodyProgressAction != null) return bodyProgressAction;
    final scheduled = _scheduledTrainingDay(plan, days);
    if (scheduled != null) {
      final title = scheduled['title']?.toString().trim();
      final focus = scheduled['focus']?.toString().trim();
      return VisionTodayAction(
        action: title?.isNotEmpty == true
            ? 'Complete your planned session: $title'
            : 'Complete today\'s planned training session',
        source: 'Today\'s Training Plan',
        explanation: focus?.isNotEmpty == true
            ? 'Today\'s $focus session directly supports the future you chose.'
            : 'Today\'s planned session directly supports the future you chose.',
        ctaLabel: 'View Today\'s Plan',
        destination: VisionActionDestination.trainingPlan,
      );
    }
    if (hasNutritionToday) {
      return const VisionTodayAction(
        action: 'Keep your nutrition choices aligned with your plan',
        source: 'Today\'s confirmed nutrition',
        explanation:
            'The choices you confirm today help connect your nutrition plan to the future you chose.',
        ctaLabel: 'Open Nutrition',
        destination: VisionActionDestination.nutrition,
      );
    }
    return const VisionTodayAction(
      action: 'Recover intentionally',
      source: 'No scheduled action is available today',
      explanation: 'Rest is part of the plan, not a break from it.',
      ctaLabel: null,
      destination: VisionActionDestination.none,
      isRecovery: true,
    );
  }

  BodyProgressCycle? _bodyProgressCycle({
    required Map<String, dynamic>? foundation,
    required List<BodyProgressCheck> history,
    required DateTime now,
  }) {
    if (foundation?['is_completed'] != true) return null;
    final baselineAt = _parseDate(
      foundation?['completed_at'] ?? foundation?['created_at'],
    );
    if (baselineAt == null) return null;
    return BodyProgressCycle.calculate(
      baselineAt: baselineAt.toLocal(),
      latestCheckAt: history.firstOrNull?.checkedAt.toLocal(),
      now: now,
    );
  }

  Map<String, dynamic>? _scheduledTrainingDay(
    Map<String, dynamic>? plan,
    List<Map<String, dynamic>> days,
  ) {
    if (plan == null || days.isEmpty) return null;
    final cycleStart = DateTime.tryParse(plan['cycle_start']?.toString() ?? '');
    if (cycleStart == null) return null;
    final now = DateTime.now();
    final start = cycleStart.toLocal();
    final elapsed = _day(now).difference(_day(start)).inDays;
    if (elapsed < 0) return null;
    final dayNumber = days.length == 7
        ? elapsed % 7 + 1
        : (elapsed == 0 ? 1 : null);
    if (dayNumber == null) return null;
    for (final day in days) {
      if ((day['day_number'] as num?)?.toInt() == dayNumber) return day;
    }
    return null;
  }

  bool _hasConsistency(List<DateTime> dates) =>
      dates.length >= 7 && dates.last.difference(dates.first).inDays >= 13;

  bool _isRecentReturnAfterGap(List<DateTime> dates, DateTime today) {
    if (dates.length < 2 || _day(today).difference(dates.last).inDays > 3) {
      return false;
    }
    return dates.last.difference(dates[dates.length - 2]).inDays >= 4;
  }

  List<DateTime> _distinctDates(Iterable<DateTime?> values) {
    final byKey = <String, DateTime>{};
    for (final value in values) {
      if (value == null) continue;
      final day = _day(value);
      byKey[_dateKey(day)] = day;
    }
    final dates = byKey.values.toList()..sort();
    return List.unmodifiable(dates);
  }

  DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to use My Vision.');
    return user;
  }

  DateTime? _parseDate(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
