import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class WearableHistoryStore {
  String? get currentUserId;

  Future<WearableDailyRecord?> upsertDaily(WearableDailyRecord record);

  Future<WearableDailyRecord?> loadLatest();
}

class SupabaseWearableHistoryStore implements WearableHistoryStore {
  final SupabaseClient _supabase;

  SupabaseWearableHistoryStore(this._supabase);

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<WearableDailyRecord?> upsertDaily(WearableDailyRecord record) async {
    final rows = await _supabase.rpc(
      'sync_wearable_daily_record',
      params: record.toSyncParameters(),
    );
    if (rows is! List || rows.isEmpty) return null;
    return WearableDailyRecord.fromMap(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  @override
  Future<WearableDailyRecord?> loadLatest() async {
    final userId = currentUserId;
    if (userId == null) return null;
    final row = await _supabase
        .from('wearable_daily_records')
        .select()
        .eq('user_id', userId)
        .order('local_date', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : WearableDailyRecord.fromMap(row);
  }
}

class WearableSyncService {
  final WearableHistoryStore _store;

  WearableSyncService({SupabaseClient? supabase, WearableHistoryStore? store})
    : _store =
          store ??
          SupabaseWearableHistoryStore(supabase ?? Supabase.instance.client);

  WearableDailyRecord? mapDaily(ValidatedWearableData data) {
    final userId = _store.currentUserId;
    if (userId == null) return null;
    final sourceDates = <DateTime>[
      if (data.steps.isEligibleForPersistence) data.steps.sourceDate!,
      if (data.activeEnergyKilocalories.isEligibleForPersistence)
        data.activeEnergyKilocalories.sourceDate!,
      if (data.averageHeartRateBpm.isEligibleForPersistence)
        data.averageHeartRateBpm.sourceDate!,
      if (data.restingHeartRateBpm.isEligibleForPersistence)
        data.restingHeartRateBpm.sourceDate!,
      if (data.distanceMeters.isEligibleForPersistence)
        data.distanceMeters.sourceDate!,
      if (data.sleepDuration.isEligibleForPersistence)
        data.sleepDuration.sourceDate!,
      if (data.bodyWeightKilograms.isEligibleForPersistence)
        data.bodyWeightKilograms.sourceDate!,
    ];
    if (sourceDates.isEmpty) return null;
    sourceDates.sort();
    final local = data.rangeStart.toLocal();
    return WearableDailyRecord(
      userId: userId,
      localDate: DateTime(local.year, local.month, local.day),
      steps: data.steps.isEligibleForPersistence ? data.steps.value : null,
      activeEnergyKilocalories:
          data.activeEnergyKilocalories.isEligibleForPersistence
          ? data.activeEnergyKilocalories.value
          : null,
      averageHeartRateBpm: data.averageHeartRateBpm.isEligibleForPersistence
          ? data.averageHeartRateBpm.value
          : null,
      restingHeartRateBpm: data.restingHeartRateBpm.isEligibleForPersistence
          ? data.restingHeartRateBpm.value
          : null,
      distanceMeters: data.distanceMeters.isEligibleForPersistence
          ? data.distanceMeters.value
          : null,
      sleepMinutes: data.sleepDuration.isEligibleForPersistence
          ? data.sleepDuration.value!.inMinutes
          : null,
      bodyWeightKilograms: data.bodyWeightKilograms.isEligibleForPersistence
          ? data.bodyWeightKilograms.value
          : null,
      sourceUpdatedAt: sourceDates.last,
    );
  }

  Future<WearableSyncResult> sync(ValidatedWearableData data) async {
    final record = mapDaily(data);
    if (record == null) {
      return WearableSyncResult(
        WearableSyncStatus.noEligibleData,
        message: _store.currentUserId == null
            ? 'Sign in to sync wearable data.'
            : 'No current validated metrics are eligible to sync.',
      );
    }
    try {
      final saved = await _store.upsertDaily(record);
      return saved == null
          ? const WearableSyncResult(WearableSyncStatus.staleIgnored)
          : WearableSyncResult(WearableSyncStatus.synced, record: saved);
    } catch (_) {
      return const WearableSyncResult(
        WearableSyncStatus.failed,
        message: 'Wearable sync could not be completed.',
      );
    }
  }

  Future<WearableDailyRecord?> loadLatest() => _store.loadLatest();
}
