import 'package:future_project/models/coach_daily_decision.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/coach_daily_decision_service.dart';
import 'package:future_project/services/health/apple_health_service.dart';
import 'package:future_project/services/health/recovery_context_service.dart';
import 'package:future_project/services/health/wearable_service.dart';
import 'package:future_project/services/health/wearable_sync_service.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';
import 'package:future_project/services/weekly_coach_service.dart';
import 'package:future_project/services/unified_coach_context_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class WearablesHubHistorySource {
  Future<List<WearableDailyRecord>> loadHistory(DateTime since);
  Future<bool> loadSelfReportedPainOrFatigue();
}

class SupabaseWearablesHubHistorySource implements WearablesHubHistorySource {
  final SupabaseClient _supabase;
  SupabaseWearablesHubHistorySource(this._supabase);

  String get _userId {
    final id = _supabase.auth.currentUser?.id;
    if (id == null) throw StateError('Sign in to load Wearables.');
    return id;
  }

  @override
  Future<List<WearableDailyRecord>> loadHistory(DateTime since) async {
    final rows = await _supabase
        .from('wearable_daily_records')
        .select()
        .eq('user_id', _userId)
        .gte('local_date', _dateKey(since))
        .order('local_date');
    return rows.map(WearableDailyRecord.fromMap).toList(growable: false);
  }

  @override
  Future<bool> loadSelfReportedPainOrFatigue() async {
    final row = await _supabase
        .from('user_foundations')
        .select('pain_notes,lifestyle')
        .eq('user_id', _userId)
        .maybeSingle();
    if (row == null) return false;
    final pain = row['pain_notes']?.toString().trim().toLowerCase();
    final painPresent =
        pain != null &&
        pain.isNotEmpty &&
        !const {'none', 'no pain', 'not set', '0'}.contains(pain);
    final lifestyle = row['lifestyle']?.toString().toLowerCase() ?? '';
    return painPresent ||
        const ['low energy', 'fatigue', 'exhausted'].any(lifestyle.contains);
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class WearablesHubEngine {
  final UnifiedCoachContextEngine _unifiedCoach;

  const WearablesHubEngine({
    UnifiedCoachContextEngine unifiedCoach = const UnifiedCoachContextEngine(),
  }) : _unifiedCoach = unifiedCoach;

  WearablesHubData build({
    required ConnectedHealthSource source,
    required DateTime now,
    ValidatedWearableData? today,
    List<WearableDailyRecord> history = const [],
    RecoveryContext? recoveryContext,
    WeeklyCoachPlan? weeklyPlan,
    CoachDecision? dailyDecision,
    bool selfReportedPainOrFatigue = false,
  }) {
    final recent = history.where((row) {
      final cutoff = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
      return !row.localDate.isBefore(cutoff);
    }).toList();
    final trends = <WearableTrend>[
      _trend('Sleep', recent, (row) => row.sleepMinutes?.toDouble(), 'minutes'),
      _trend('Steps', recent, (row) => row.steps?.toDouble(), 'steps'),
      _trend(
        'Resting heart rate',
        recent,
        (row) => row.restingHeartRateBpm,
        'bpm',
      ),
    ];
    final wearableTrend = trends
        .where(
          (trend) => trend.direction != WearableTrendDirection.insufficientData,
        )
        .firstOrNull;
    final UnifiedCoachContext unified = _unifiedCoach.evaluate(
      UnifiedCoachContextInput(
        now: now,
        recoveryContext: recoveryContext,
        weeklyPlan: weeklyPlan,
        dailyDecision: dailyDecision,
        userReportedPainOrFatigue: selfReportedPainOrFatigue,
        wearableInsight: wearableTrend == null
            ? null
            : '${wearableTrend.metric}: ${wearableTrend.description}',
        wearableAction: wearableTrend == null
            ? null
            : 'Keep your existing routine while another validated day builds the pattern.',
        wearableEvidence: wearableTrend == null
            ? const []
            : [
                'wearable_${wearableTrend.metric.toLowerCase().replaceAll(' ', '_')}_trend',
              ],
      ),
    );
    return WearablesHubData(
      source: source,
      today: today,
      history: List.unmodifiable(recent),
      recoveryContext: recoveryContext,
      weeklyPlan: weeklyPlan,
      dailyDecision: dailyDecision,
      trends: List.unmodifiable(trends),
      coachInsight: WearablesCoachInsight(
        insight: unified.primaryInsight,
        nextAction: unified.primaryAction,
        evidence: unified.evidence,
      ),
      unifiedCoachContext: unified,
      selfReportedPainOrFatigue: selfReportedPainOrFatigue,
      generatedAt: now,
    );
  }

  WearableTrend _trend(
    String metric,
    List<WearableDailyRecord> rows,
    double? Function(WearableDailyRecord) select,
    String unit,
  ) {
    final values = rows.map(select).nonNulls.toList();
    if (values.length < 3) {
      return WearableTrend(
        metric: metric,
        direction: WearableTrendDirection.insufficientData,
        coverageDays: values.length,
        description: 'Not enough data for a reliable 7-day trend.',
      );
    }
    final midpoint = values.length ~/ 2;
    final first = _average(values.take(midpoint));
    final second = _average(values.skip(midpoint));
    final tolerance = metric == 'Resting heart rate' ? 2.0 : first * .08;
    final delta = second - first;
    final direction = delta.abs() <= tolerance
        ? WearableTrendDirection.stable
        : delta > 0
        ? WearableTrendDirection.increasing
        : WearableTrendDirection.decreasing;
    return WearableTrend(
      metric: metric,
      direction: direction,
      coverageDays: values.length,
      description: direction == WearableTrendDirection.stable
          ? 'Fairly steady across ${values.length} available days.'
          : '${delta.abs().round()} $unit ${direction == WearableTrendDirection.increasing ? 'higher' : 'lower'} across the available week.',
    );
  }

  double _average(Iterable<double> values) {
    final list = values.toList();
    return list.reduce((a, b) => a + b) / list.length;
  }
}

class WearablesHubService {
  final WearableService _wearable;
  final WearableValidationService _validation;
  final WearableSyncService _sync;
  final RecoveryContextService _recovery;
  final WeeklyCoachService _weekly;
  final CoachDailyDecisionService _decision;
  final WearablesHubHistorySource _history;
  final WearablesHubEngine _engine;
  final DateTime Function() _clock;

  WearablesHubService({
    WearableService? wearable,
    WearableValidationService validation = const WearableValidationService(),
    WearableSyncService? sync,
    RecoveryContextService? recovery,
    WeeklyCoachService? weekly,
    CoachDailyDecisionService? decision,
    WearablesHubHistorySource? history,
    WearablesHubEngine engine = const WearablesHubEngine(),
    DateTime Function()? clock,
    SupabaseClient? supabase,
  }) : _wearable = wearable ?? AppleHealthService(),
       _validation = validation,
       _sync = sync ?? WearableSyncService(supabase: supabase),
       _recovery = recovery ?? RecoveryContextService(supabase: supabase),
       _weekly = weekly ?? WeeklyCoachService(supabase: supabase),
       _decision = decision ?? CoachDailyDecisionService(supabase: supabase),
       _history =
           history ??
           SupabaseWearablesHubHistorySource(
             supabase ?? Supabase.instance.client,
           ),
       _engine = engine,
       _clock = clock ?? DateTime.now;

  Future<WearablesHubData> load({bool readAppleHealth = true}) async {
    final now = _clock();
    WearablePermissionResult permission;
    try {
      permission = await _wearable.permissionStatus();
    } catch (_) {
      permission = const WearablePermissionResult(
        WearablePermissionStatus.unavailable,
      );
    }
    ValidatedWearableData? today;
    if (readAppleHealth &&
        permission.status != WearablePermissionStatus.denied &&
        permission.status != WearablePermissionStatus.unsupportedPlatform &&
        permission.status != WearablePermissionStatus.unavailable) {
      try {
        today = _validation.validate(await _wearable.readToday(), now: now);
        await _sync.sync(today);
        permission = WearablePermissionResult(today.permissionStatus);
      } catch (_) {
        // History and recovery remain independently usable.
      }
    }
    List<WearableDailyRecord> history = const [];
    RecoveryContext? recovery;
    WeeklyCoachPlan? weekly;
    CoachDailyDecision? decision;
    var condition = false;
    try {
      history = await _history.loadHistory(
        now.subtract(const Duration(days: 14)),
      );
    } catch (_) {}
    try {
      recovery = await _recovery.load(now: now);
    } catch (_) {}
    try {
      weekly = await _weekly.loadCurrentPlan();
    } catch (_) {}
    try {
      decision = await _decision.loadToday();
    } catch (_) {}
    try {
      condition = await _history.loadSelfReportedPainOrFatigue();
    } catch (_) {}
    final lastSync = history
        .map((row) => row.syncedAt)
        .nonNulls
        .fold<DateTime?>(
          null,
          (latest, value) =>
              latest == null || value.isAfter(latest) ? value : latest,
        );
    final source = ConnectedHealthSource(
      provider: WearableProvider.appleHealth,
      displayName: 'Apple Health',
      permissionStatus: permission.status,
      lastSuccessfulSync: lastSync,
      dataAvailable: (today?.validMetricCount ?? 0) > 0 || history.isNotEmpty,
      statusMessage: permission.message,
    );
    return _engine.build(
      source: source,
      now: now,
      today: today,
      history: history,
      recoveryContext: recovery,
      weeklyPlan: weekly,
      dailyDecision: decision?.decision,
      selfReportedPainOrFatigue: condition,
    );
  }

  Future<WearablePermissionResult> requestPermissions() =>
      _wearable.requestReadPermissions();
}
