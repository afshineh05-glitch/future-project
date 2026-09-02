import 'package:future_project/models/body_progress.dart';
import 'package:future_project/models/vision_progress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class BodyProgressStore {
  Future<BodyProgressBaseline?> loadBaseline();

  Future<List<BodyProgressCheck>> loadHistory();

  Future<BodyProgressCheck> insertCheck({
    required BodyMeasurements measurements,
    required DateTime checkedAt,
    required String cycleKey,
    String? note,
  });

  Future<BodyProgressCheck> updateCheck({
    required String checkId,
    required BodyMeasurements measurements,
    String? note,
  });
}

class _SupabaseBodyProgressStore implements BodyProgressStore {
  final SupabaseClient _supabase;

  _SupabaseBodyProgressStore(this._supabase);

  @override
  Future<BodyProgressBaseline?> loadBaseline() async {
    final user = _requireUser();
    final row = await _supabase
        .from('user_foundations')
        .select(
          'weight_kg, waist_cm, chest_cm, hips_cm, arm_cm, thigh_cm, neck_cm, measurement_system, completed_at, created_at, is_completed',
        )
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null || row['is_completed'] != true) return null;
    return BodyProgressBaseline(
      measurements: BodyMeasurements.fromFoundation(row),
      establishedAt:
          DateTime.tryParse(
            (row['completed_at'] ?? row['created_at'] ?? '').toString(),
          ) ??
          DateTime.now(),
      measurementSystem: row['measurement_system']?.toString() ?? 'metric',
    );
  }

  @override
  Future<List<BodyProgressCheck>> loadHistory() async {
    final user = _requireUser();
    final rows = await _supabase
        .from('body_progress_checks')
        .select()
        .eq('user_id', user.id)
        .order('checked_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(BodyProgressCheck.fromMap)
        .toList(growable: false);
  }

  @override
  Future<BodyProgressCheck> insertCheck({
    required BodyMeasurements measurements,
    required DateTime checkedAt,
    required String cycleKey,
    String? note,
  }) async {
    final user = _requireUser();
    try {
      final row = await _supabase
          .from('body_progress_checks')
          .insert({
            'user_id': user.id,
            ...measurements.toDatabaseMap(),
            'note': _normalizedNote(note),
            'checked_at': checkedAt.toUtc().toIso8601String(),
            'cycle_key': cycleKey,
          })
          .select()
          .single();
      return BodyProgressCheck.fromMap(row);
    } on PostgrestException catch (error) {
      if (error.code != '23505') rethrow;
      final existing = await _supabase
          .from('body_progress_checks')
          .select()
          .eq('user_id', user.id)
          .eq('cycle_key', cycleKey)
          .single();
      return updateCheck(
        checkId: existing['id'].toString(),
        measurements: measurements,
        note: note,
      );
    }
  }

  @override
  Future<BodyProgressCheck> updateCheck({
    required String checkId,
    required BodyMeasurements measurements,
    String? note,
  }) async {
    final user = _requireUser();
    final row = await _supabase
        .from('body_progress_checks')
        .update({
          ...measurements.toDatabaseMap(),
          'note': _normalizedNote(note),
        })
        .eq('id', checkId)
        .eq('user_id', user.id)
        .select()
        .single();
    return BodyProgressCheck.fromMap(row);
  }

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to use Body Progress.');
    return user;
  }

  String? _normalizedNote(String? note) {
    final value = note?.trim();
    return value == null || value.isEmpty ? null : value;
  }
}

class BodyProgressService {
  final BodyProgressStore _store;

  BodyProgressService({SupabaseClient? supabase, BodyProgressStore? store})
    : _store =
          store ??
          _SupabaseBodyProgressStore(supabase ?? Supabase.instance.client);

  Future<BodyProgressBaseline?> loadBaseline() => _store.loadBaseline();

  Future<List<BodyProgressCheck>> loadHistory() => _store.loadHistory();

  Future<BodyProgressCheck?> loadLatestCheck() async {
    final history = await loadHistory();
    return history.isEmpty ? null : _latest(history);
  }

  Future<BodyProgressCheck> createCheck({
    required BodyMeasurements measurements,
    required String cycleKey,
    String? note,
    DateTime? checkedAt,
  }) => _store.insertCheck(
    measurements: measurements,
    note: note,
    checkedAt: checkedAt ?? DateTime.now(),
    cycleKey: cycleKey,
  );

  Future<BodyProgressCheck> updateCheck({
    required BodyProgressCheck check,
    required BodyMeasurements measurements,
    String? note,
  }) => _store.updateCheck(
    checkId: check.id,
    measurements: measurements,
    note: note,
  );

  Future<BodyProgressCheck> saveCheckForCurrentCycle({
    required BodyProgressBaseline baseline,
    required List<BodyProgressCheck> history,
    required BodyMeasurements measurements,
    String? note,
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();
    final state = resolveCycle(
      baseline: baseline,
      history: history,
      now: effectiveNow,
    );
    final currentCheck = state.currentCheck;
    if (currentCheck != null) {
      return updateCheck(
        check: currentCheck,
        measurements: measurements,
        note: note,
      );
    }
    return createCheck(
      measurements: measurements,
      note: note,
      checkedAt: effectiveNow,
      cycleKey: cycleKeyFor(baseline: baseline, history: history),
    );
  }

  String cycleKeyFor({
    required BodyProgressBaseline baseline,
    required List<BodyProgressCheck> history,
  }) {
    if (history.isNotEmpty) return 'after:${_latest(history).id}';
    return 'foundation:${baseline.establishedAt.toUtc().toIso8601String()}';
  }

  BodyProgressCycleState resolveCycle({
    required BodyProgressBaseline baseline,
    required List<BodyProgressCheck> history,
    DateTime? now,
  }) {
    final latestCheck = history.isEmpty ? null : _latest(history);
    final cycle = calculateCycle(
      baseline: baseline,
      latestCheck: latestCheck,
      now: now,
    );
    return BodyProgressCycleState(
      cycle: cycle,
      currentCheck: cycle.status == BodyProgressCycleStatus.completed
          ? latestCheck
          : null,
    );
  }

  BodyProgressCycle calculateCycle({
    required BodyProgressBaseline baseline,
    BodyProgressCheck? latestCheck,
    DateTime? now,
  }) => BodyProgressCycle.calculate(
    baselineAt: baseline.establishedAt,
    latestCheckAt: latestCheck?.checkedAt,
    now: now ?? DateTime.now(),
  );

  BodyMeasurements comparisonForCheck({
    required BodyProgressCheck check,
    required List<BodyProgressCheck> history,
    required BodyProgressBaseline baseline,
  }) {
    final ordered = _orderedHistory(history);
    final index = ordered.indexWhere((item) => item.id == check.id);
    if (index >= 0 && index + 1 < ordered.length) {
      return ordered[index + 1].measurements;
    }
    return baseline.measurements;
  }

  Future<List<VisionBodyProgressCheck>> loadVisionChecks() async =>
      (await loadHistory()).map((item) => item.toVisionCheck()).toList();

  BodyProgressCheck _latest(List<BodyProgressCheck> history) =>
      _orderedHistory(history).first;

  List<BodyProgressCheck> _orderedHistory(List<BodyProgressCheck> history) =>
      [...history]..sort((a, b) {
        final checkedAt = b.checkedAt.compareTo(a.checkedAt);
        return checkedAt != 0 ? checkedAt : b.createdAt.compareTo(a.createdAt);
      });
}
