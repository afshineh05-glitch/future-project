import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/services/ble/ble_core_service.dart';
import 'package:future_project/services/ble/standard_gatt_parsers.dart';

abstract interface class BleWearableAdapter {
  String get adapterType;
  bool supportsDevice(
    BleDiscoveredDevice device,
    List<BleGattService> services,
  );
  Future<void> setup(
    BleCoreService ble,
    BleDiscoveredDevice device,
    List<BleGattService> services,
  );
  Future<WearableData?> readAndNormalize({DateTime? now});
  Stream<WearableData> subscribeAndNormalize();
  Future<void> disconnect();
}

/// Generic support for the Bluetooth SIG Heart Rate Service only. Proprietary
/// device protocols belong in separate adapters implementing [BleWearableAdapter].
class StandardHeartRateBleAdapter implements BleWearableAdapter {
  BleCoreService? _ble;
  BleDiscoveredDevice? _device;
  BleCharacteristic? _heartRate;
  final BleNotificationDeduplicator _deduplicator =
      BleNotificationDeduplicator();
  int? batteryLevel;
  String? manufacturerName;
  String? modelNumber;

  @override
  String get adapterType => 'standard_heart_rate';

  @override
  bool supportsDevice(
    BleDiscoveredDevice device,
    List<BleGattService> services,
  ) => services.any(
    (service) =>
        service.id == StandardGattUuids.heartRateService &&
        service.characteristicIds.contains(
          StandardGattUuids.heartRateMeasurement,
        ),
  );

  @override
  Future<void> setup(
    BleCoreService ble,
    BleDiscoveredDevice device,
    List<BleGattService> services,
  ) async {
    if (!supportsDevice(device, services)) {
      throw UnsupportedError('No supported standard health service found.');
    }
    _ble = ble;
    _device = device;
    _heartRate = BleCharacteristic(
      deviceId: device.id,
      serviceId: StandardGattUuids.heartRateService,
      characteristicId: StandardGattUuids.heartRateMeasurement,
    );
    batteryLevel = await _readOptionalInt(
      ble,
      device,
      services,
      StandardGattUuids.batteryService,
      StandardGattUuids.batteryLevel,
      StandardGattParsers.batteryLevel,
    );
    manufacturerName = await _readOptionalText(
      ble,
      device,
      services,
      StandardGattUuids.deviceInformationService,
      StandardGattUuids.manufacturerName,
    );
    modelNumber = await _readOptionalText(
      ble,
      device,
      services,
      StandardGattUuids.deviceInformationService,
      StandardGattUuids.modelNumber,
    );
  }

  @override
  Future<WearableData?> readAndNormalize({DateTime? now}) async {
    final packet = await _ble!.read(_heartRate!);
    return _normalize(packet, now ?? DateTime.now());
  }

  @override
  Stream<WearableData> subscribeAndNormalize() async* {
    await for (final packet in _ble!.subscribe(_heartRate!)) {
      final receivedAt = DateTime.now();
      if (_deduplicator.isDuplicate(packet, receivedAt)) continue;
      final normalized = _normalize(packet, receivedAt);
      if (normalized != null) yield normalized;
    }
  }

  WearableData? _normalize(List<int> packet, DateTime observedAt) {
    final measurement = StandardGattParsers.heartRate(packet);
    if (measurement == null) return null;
    final start = DateTime(observedAt.year, observedAt.month, observedAt.day);
    return WearableData(
      rangeStart: start,
      rangeEnd: observedAt,
      permissionStatus: WearablePermissionStatus.authorized,
      averageHeartRateBpm: measurement.beatsPerMinute.toDouble(),
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
      sourceDates: {WearableMetric.heartRate: observedAt},
    );
  }

  @override
  Future<void> disconnect() async {
    final ble = _ble;
    final device = _device;
    _ble = null;
    _device = null;
    _heartRate = null;
    if (ble != null && device != null) await ble.disconnect(device.id);
  }

  Future<int?> _readOptionalInt(
    BleCoreService ble,
    BleDiscoveredDevice device,
    List<BleGattService> services,
    String serviceId,
    String characteristicId,
    int? Function(List<int>) parser,
  ) async {
    if (!_hasCharacteristic(services, serviceId, characteristicId)) return null;
    try {
      return parser(
        await ble.read(
          BleCharacteristic(
            deviceId: device.id,
            serviceId: serviceId,
            characteristicId: characteristicId,
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readOptionalText(
    BleCoreService ble,
    BleDiscoveredDevice device,
    List<BleGattService> services,
    String serviceId,
    String characteristicId,
  ) async {
    if (!_hasCharacteristic(services, serviceId, characteristicId)) return null;
    try {
      return StandardGattParsers.deviceInformation(
        await ble.read(
          BleCharacteristic(
            deviceId: device.id,
            serviceId: serviceId,
            characteristicId: characteristicId,
          ),
        ),
      );
    } catch (_) {
      return null;
    }
  }
}

bool _hasCharacteristic(
  List<BleGattService> services,
  String serviceId,
  String characteristicId,
) => services.any(
  (service) =>
      service.id == serviceId &&
      service.characteristicIds.contains(characteristicId),
);

class BleNotificationDeduplicator {
  final Duration window;
  DateTime? _lastNotificationAt;
  List<int>? _lastPacket;

  BleNotificationDeduplicator({
    this.window = const Duration(milliseconds: 500),
  });

  bool isDuplicate(List<int> packet, DateTime receivedAt) {
    final duplicate =
        _lastPacket != null &&
        _sameBytes(_lastPacket!, packet) &&
        _lastNotificationAt != null &&
        receivedAt.difference(_lastNotificationAt!) < window;
    _lastPacket = List<int>.from(packet);
    _lastNotificationAt = receivedAt;
    return duplicate;
  }
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}
