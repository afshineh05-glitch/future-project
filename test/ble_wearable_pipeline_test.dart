import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/services/ble/ble_core_service.dart';
import 'package:future_project/services/ble/ble_wearable_adapter.dart';
import 'package:future_project/services/ble/ble_wearable_pipeline.dart';
import 'package:future_project/services/health/wearable_sync_service.dart';

void main() {
  final now = DateTime(2026, 9, 11, 18);

  test('BLE data reaches canonical normalization and validation', () async {
    final adapter = _Adapter(_heartRateData(now, 72));
    final pipeline = BleWearablePipeline(
      sync: WearableSyncService(store: _Store()),
    );

    final validated = await pipeline.readValidated(adapter, now: now);

    expect(validated?.averageHeartRateBpm.value, 72);
    expect(
      validated?.averageHeartRateBpm.status,
      WearableValidationStatus.valid,
    );
    expect(validated?.steps.value, isNull);
  });

  test('impossible BLE measurement is rejected before persistence', () async {
    final store = _Store();
    final pipeline = BleWearablePipeline(
      sync: WearableSyncService(store: store),
    );
    final result = await pipeline.sync(
      _Adapter(_heartRateData(now, 500)),
      now: now,
    );

    expect(result, isNull);
    expect(store.writeCount, 0);
  });

  test('valid BLE measurement uses canonical idempotent daily sync', () async {
    final store = _Store();
    final pipeline = BleWearablePipeline(
      sync: WearableSyncService(store: store),
    );
    final adapter = _Adapter(_heartRateData(now, 74));

    await pipeline.sync(adapter, now: now);
    await pipeline.sync(adapter, now: now);

    expect(store.rows, hasLength(1));
    expect(store.rows.single.averageHeartRateBpm, 74);
  });

  test('Apple Health remains a distinct canonical source path', () {
    expect(
      WearablePermissionStatus.values,
      contains(WearablePermissionStatus.authorized),
    );
    expect(
      _Adapter(_heartRateData(now, 70)).adapterType,
      isNot('apple_health'),
    );
  });
}

WearableData _heartRateData(DateTime now, double bpm) => WearableData(
  rangeStart: DateTime(now.year, now.month, now.day),
  rangeEnd: now,
  permissionStatus: WearablePermissionStatus.authorized,
  averageHeartRateBpm: bpm,
  workouts: const [],
  unavailableMetrics: const {
    'STEPS',
    'ACTIVE_ENERGY_BURNED',
    'RESTING_HEART_RATE',
    'WORKOUT',
    'DISTANCE_DELTA',
    'SLEEP_ASLEEP',
    'WEIGHT',
  },
  sourceDates: {WearableMetric.heartRate: now},
);

class _Adapter implements BleWearableAdapter {
  final WearableData data;
  _Adapter(this.data);
  @override
  String get adapterType => 'standard_heart_rate';
  @override
  Future<void> disconnect() async {}
  @override
  Future<WearableData?> readAndNormalize({DateTime? now}) async => data;
  @override
  Future<void> setup(
    BleCoreService ble,
    BleDiscoveredDevice device,
    List<BleGattService> services,
  ) async {}
  @override
  Stream<WearableData> subscribeAndNormalize() => Stream.value(data);
  @override
  bool supportsDevice(
    BleDiscoveredDevice device,
    List<BleGattService> services,
  ) => true;
}

class _Store implements WearableHistoryStore {
  final rows = <WearableDailyRecord>[];
  int writeCount = 0;
  @override
  String? get currentUserId => 'user';
  @override
  Future<WearableDailyRecord?> loadLatest() async =>
      rows.isEmpty ? null : rows.last;
  @override
  Future<WearableDailyRecord?> upsertDaily(WearableDailyRecord record) async {
    writeCount++;
    final index = rows.indexWhere((item) => item.localDate == record.localDate);
    if (index < 0) {
      rows.add(record);
    } else {
      rows[index] = record;
    }
    return record;
  }
}
