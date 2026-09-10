import 'package:future_project/models/coach_daily_decision.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class CoachDailyDecisionStore {
  String? get currentUserId;

  Future<CoachDailyDecision?> loadForDate(DateTime localDate);

  Future<CoachDailyDecision> upsertForDate(
    DateTime localDate,
    CoachDecision decision,
  );
}

class SupabaseCoachDailyDecisionStore implements CoachDailyDecisionStore {
  final SupabaseClient _supabase;

  SupabaseCoachDailyDecisionStore(this._supabase);

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<CoachDailyDecision?> loadForDate(DateTime localDate) async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _supabase
        .from('coach_daily_decisions')
        .select()
        .eq('user_id', userId)
        .eq('local_date', CoachDailyDecision.dateKey(localDate))
        .maybeSingle();
    return row == null ? null : CoachDailyDecision.fromMap(row);
  }

  @override
  Future<CoachDailyDecision> upsertForDate(
    DateTime localDate,
    CoachDecision decision,
  ) async {
    if (currentUserId == null) {
      throw StateError('Sign in to save today\'s Coach decision.');
    }
    final rows = await _supabase.rpc(
      'save_coach_daily_decision',
      params: {
        'p_local_date': CoachDailyDecision.dateKey(localDate),
        'p_decision': CoachDailyDecision.decisionKey(decision),
      },
    );
    if (rows is! List || rows.isEmpty) {
      throw StateError('Coach decision was not saved.');
    }
    return CoachDailyDecision.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}

class CoachDailyDecisionService {
  final CoachDailyDecisionStore _store;
  final DateTime Function() _clock;

  CoachDailyDecisionService({
    SupabaseClient? supabase,
    CoachDailyDecisionStore? store,
    DateTime Function()? clock,
  }) : _store =
           store ??
           SupabaseCoachDailyDecisionStore(
             supabase ?? Supabase.instance.client,
           ),
       _clock = clock ?? DateTime.now;

  /// Optional context for Today’s Coach or Training Plan consumers.
  Future<CoachDailyDecision?> loadToday() => _store.loadForDate(_clock());

  /// Call only in response to an explicit user choice.
  Future<CoachDailyDecision> saveToday(CoachDecision decision) =>
      _store.upsertForDate(_clock(), decision);
}
