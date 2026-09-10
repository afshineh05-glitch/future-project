class WearableDailyRecord {
  final String userId;
  final DateTime localDate;
  final int? steps;
  final double? activeEnergyKilocalories;
  final double? averageHeartRateBpm;
  final double? restingHeartRateBpm;
  final double? distanceMeters;
  final int? sleepMinutes;
  final double? bodyWeightKilograms;
  final DateTime sourceUpdatedAt;
  final DateTime? syncedAt;

  const WearableDailyRecord({
    required this.userId,
    required this.localDate,
    required this.sourceUpdatedAt,
    this.steps,
    this.activeEnergyKilocalories,
    this.averageHeartRateBpm,
    this.restingHeartRateBpm,
    this.distanceMeters,
    this.sleepMinutes,
    this.bodyWeightKilograms,
    this.syncedAt,
  });

  bool get hasMetrics =>
      steps != null ||
      activeEnergyKilocalories != null ||
      averageHeartRateBpm != null ||
      restingHeartRateBpm != null ||
      distanceMeters != null ||
      sleepMinutes != null ||
      bodyWeightKilograms != null;

  String get localDateKey =>
      '${localDate.year.toString().padLeft(4, '0')}-'
      '${localDate.month.toString().padLeft(2, '0')}-'
      '${localDate.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toSyncParameters() => {
    'p_local_date': localDateKey,
    'p_steps': steps,
    'p_active_energy_kcal': activeEnergyKilocalories,
    'p_average_heart_rate_bpm': averageHeartRateBpm,
    'p_resting_heart_rate_bpm': restingHeartRateBpm,
    'p_distance_meters': distanceMeters,
    'p_sleep_minutes': sleepMinutes,
    'p_body_weight_kg': bodyWeightKilograms,
    'p_source_updated_at': sourceUpdatedAt.toUtc().toIso8601String(),
  };

  factory WearableDailyRecord.fromMap(Map<String, dynamic> row) =>
      WearableDailyRecord(
        userId: row['user_id'].toString(),
        localDate: DateTime.parse(row['local_date'].toString()),
        steps: _int(row['steps']),
        activeEnergyKilocalories: _double(row['active_energy_kcal']),
        averageHeartRateBpm: _double(row['average_heart_rate_bpm']),
        restingHeartRateBpm: _double(row['resting_heart_rate_bpm']),
        distanceMeters: _double(row['distance_meters']),
        sleepMinutes: _int(row['sleep_minutes']),
        bodyWeightKilograms: _double(row['body_weight_kg']),
        sourceUpdatedAt: DateTime.parse(row['source_updated_at'].toString()),
        syncedAt: DateTime.tryParse(row['synced_at']?.toString() ?? ''),
      );

  static double? _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static int? _int(dynamic value) {
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

enum WearableSyncStatus { synced, noEligibleData, staleIgnored, failed }

class WearableSyncResult {
  final WearableSyncStatus status;
  final WearableDailyRecord? record;
  final String? message;

  const WearableSyncResult(this.status, {this.record, this.message});

  bool get isSuccess => status == WearableSyncStatus.synced;
}
