import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/health/wearable_sync_service.dart';

void main() {
  final now = DateTime(2026, 9, 9, 12);

  ValidatedWearableMetric<T> metric<T>(
    T? value, {
    WearableValidationStatus status = WearableValidationStatus.valid,
    DateTime? sourceDate,
  }) => ValidatedWearableMetric(
    rawValue: value,
    value: status == WearableValidationStatus.valid ? value : null,
    sourceDate: sourceDate ?? now,
    status: status,
  );

  ValidatedWearableData data({
    ValidatedWearableMetric<int>? steps,
    ValidatedWearableMetric<double>? activeEnergy,
    ValidatedWearableMetric<double>? heartRate,
    ValidatedWearableMetric<double>? restingHeartRate,
    ValidatedWearableMetric<double>? distance,
    ValidatedWearableMetric<Duration>? sleep,
    ValidatedWearableMetric<double>? weight,
  }) => ValidatedWearableData(
    rangeStart: DateTime(2026, 9, 9),
    rangeEnd: now,
    permissionStatus: WearablePermissionStatus.authorized,
    unavailableMetrics: const {},
    steps: steps ?? metric<int>(null, status: WearableValidationStatus.missing),
    activeEnergyKilocalories:
        activeEnergy ??
        metric<double>(null, status: WearableValidationStatus.missing),
    averageHeartRateBpm:
        heartRate ??
        metric<double>(null, status: WearableValidationStatus.missing),
    restingHeartRateBpm:
        restingHeartRate ??
        metric<double>(null, status: WearableValidationStatus.missing),
    workouts: metric<List<WearableWorkout>>(
      null,
      status: WearableValidationStatus.missing,
    ),
    workoutDuration: metric<Duration>(
      null,
      status: WearableValidationStatus.missing,
    ),
    distanceMeters:
        distance ??
        metric<double>(null, status: WearableValidationStatus.missing),
    sleepDuration:
        sleep ??
        metric<Duration>(null, status: WearableValidationStatus.missing),
    bodyWeightKilograms:
        weight ??
        metric<double>(null, status: WearableValidationStatus.missing),
  );

  test('maps only validated metrics to the local daily record', () {
    final store = _MemoryStore();
    final service = WearableSyncService(store: store);
    final record = service.mapDaily(
      data(
        steps: metric(12000),
        activeEnergy: metric(450.5),
        sleep: metric(const Duration(hours: 7, minutes: 30)),
      ),
    );

    expect(record!.userId, 'user-1');
    expect(record.localDateKey, '2026-09-09');
    expect(record.steps, 12000);
    expect(record.activeEnergyKilocalories, 450.5);
    expect(record.sleepMinutes, 450);
    expect(record.averageHeartRateBpm, isNull);
  });

  test('missing, implausible, and unavailable metrics remain absent', () {
    final service = WearableSyncService(store: _MemoryStore());
    final record = service.mapDaily(
      data(
        steps: metric(1000),
        heartRate: metric(500, status: WearableValidationStatus.implausible),
        weight: metric(80, status: WearableValidationStatus.unavailable),
        distance: metric(5000, status: WearableValidationStatus.stale),
      ),
    );

    expect(record!.steps, 1000);
    expect(record.averageHeartRateBpm, isNull);
    expect(record.bodyWeightKilograms, isNull);
    expect(record.distanceMeters, isNull);
  });

  test('repeated sync uses one user and local-date identity', () async {
    final store = _MemoryStore();
    final service = WearableSyncService(store: store);
    final validated = data(steps: metric(1000));

    expect((await service.sync(validated)).isSuccess, isTrue);
    expect((await service.sync(validated)).isSuccess, isTrue);
    expect(store.records, hasLength(1));
  });

  test('an older source snapshot cannot overwrite a newer record', () async {
    final store = _MemoryStore();
    final service = WearableSyncService(store: store);
    await service.sync(data(steps: metric(2000, sourceDate: now)));
    final result = await service.sync(
      data(
        steps: metric(1000, sourceDate: now.subtract(const Duration(hours: 1))),
      ),
    );

    expect(result.status, WearableSyncStatus.staleIgnored);
    expect(store.records.single.steps, 2000);
  });

  test('store failure does not mutate validated wearable data', () async {
    final validated = data(steps: metric(4321));
    final service = WearableSyncService(store: _FailingStore());
    final result = await service.sync(validated);

    expect(result.status, WearableSyncStatus.failed);
    expect(validated.steps.value, 4321);
    expect(validated.steps.status, WearableValidationStatus.valid);
  });
}

class _MemoryStore implements WearableHistoryStore {
  final List<WearableDailyRecord> records = [];

  @override
  String? get currentUserId => 'user-1';

  @override
  Future<WearableDailyRecord?> loadLatest() async =>
      records.isEmpty ? null : records.last;

  @override
  Future<WearableDailyRecord?> upsertDaily(WearableDailyRecord record) async {
    final index = records.indexWhere(
      (item) =>
          item.userId == record.userId &&
          item.localDateKey == record.localDateKey,
    );
    if (index >= 0) {
      if (record.sourceUpdatedAt.isBefore(records[index].sourceUpdatedAt)) {
        return null;
      }
      records[index] = record;
    } else {
      records.add(record);
    }
    return record;
  }
}

class _FailingStore implements WearableHistoryStore {
  @override
  String? get currentUserId => 'user-1';

  @override
  Future<WearableDailyRecord?> loadLatest() async => null;

  @override
  Future<WearableDailyRecord?> upsertDaily(WearableDailyRecord record) =>
      throw StateError('offline');
}
