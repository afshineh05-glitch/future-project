enum BleAvailability {
  ready,
  bluetoothOff,
  permissionDenied,
  unsupported,
  unavailable,
}

enum BleDeviceConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
  failed,
}

class BleDiscoveredDevice {
  final String id;
  final String name;
  final int rssi;
  final Set<String> serviceIds;

  const BleDiscoveredDevice({
    required this.id,
    required this.name,
    required this.rssi,
    this.serviceIds = const {},
  });
}

class BleConnectionUpdate {
  final String deviceId;
  final BleDeviceConnectionState state;
  final Object? error;

  const BleConnectionUpdate(this.deviceId, this.state, {this.error});
}

class BleGattService {
  final String id;
  final Set<String> characteristicIds;

  const BleGattService({required this.id, required this.characteristicIds});
}

class BleCharacteristic {
  final String deviceId;
  final String serviceId;
  final String characteristicId;

  const BleCharacteristic({
    required this.deviceId,
    required this.serviceId,
    required this.characteristicId,
  });
}

class KnownBleWearable {
  final String id;
  final String displayName;
  final String adapterType;
  final DateTime lastConnectedAt;
  final bool reconnectEnabled;

  const KnownBleWearable({
    required this.id,
    required this.displayName,
    required this.adapterType,
    required this.lastConnectedAt,
    required this.reconnectEnabled,
  });

  Map<String, Object?> toJson() => {
    'id': id,
    'display_name': displayName,
    'adapter_type': adapterType,
    'last_connected_at': lastConnectedAt.toUtc().toIso8601String(),
    'reconnect_enabled': reconnectEnabled,
  };

  factory KnownBleWearable.fromJson(Map<String, dynamic> json) =>
      KnownBleWearable(
        id: json['id'] as String,
        displayName: json['display_name'] as String,
        adapterType: json['adapter_type'] as String,
        lastConnectedAt: DateTime.parse(json['last_connected_at'] as String),
        reconnectEnabled: json['reconnect_enabled'] as bool? ?? false,
      );
}

class BleHeartRateMeasurement {
  final int beatsPerMinute;
  final int? energyExpended;
  final List<Duration> rrIntervals;

  const BleHeartRateMeasurement({
    required this.beatsPerMinute,
    this.energyExpended,
    this.rrIntervals = const [],
  });
}
