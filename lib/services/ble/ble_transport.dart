import 'package:future_project/models/ble_wearable.dart';

abstract interface class BlePermissionGateway {
  Future<bool> requestScanAndConnect();
}

abstract interface class BleTransport {
  Stream<BleAvailability> get availability;

  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}});
  Future<void> stopScan();
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  });
  Future<void> disconnect(String deviceId);
  Future<List<BleGattService>> discoverServices(String deviceId);
  Future<List<int>> read(BleCharacteristic characteristic);
  Future<void> write(BleCharacteristic characteristic, List<int> value);
  Stream<List<int>> subscribe(BleCharacteristic characteristic);
  Future<void> dispose();
}
