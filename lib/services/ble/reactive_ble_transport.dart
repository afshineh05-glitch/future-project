import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_transport.dart';
import 'package:permission_handler/permission_handler.dart';

class PlatformBlePermissionGateway implements BlePermissionGateway {
  final DeviceInfoPlugin _deviceInfo;

  PlatformBlePermissionGateway({DeviceInfoPlugin? deviceInfo})
    : _deviceInfo = deviceInfo ?? DeviceInfoPlugin();

  @override
  Future<bool> requestScanAndConnect() async {
    if (!Platform.isAndroid) return true;
    final sdk = (await _deviceInfo.androidInfo).version.sdkInt;
    if (sdk >= 31) {
      final results = await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();
      return results.values.every((status) => status.isGranted);
    }
    return (await Permission.locationWhenInUse.request()).isGranted;
  }
}

class ReactiveBleTransport implements BleTransport {
  final FlutterReactiveBle _ble;
  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  StreamController<BleDiscoveredDevice>? _scanController;
  final Map<String, StreamSubscription<ConnectionStateUpdate>> _connections =
      {};

  ReactiveBleTransport({FlutterReactiveBle? ble})
    : _ble = ble ?? FlutterReactiveBle();

  @override
  Stream<BleAvailability> get availability => _ble.statusStream.map((status) {
    return switch (status) {
      BleStatus.ready => BleAvailability.ready,
      BleStatus.poweredOff => BleAvailability.bluetoothOff,
      BleStatus.unauthorized => BleAvailability.permissionDenied,
      BleStatus.unsupported => BleAvailability.unsupported,
      _ => BleAvailability.unavailable,
    };
  }).distinct();

  @override
  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) {
    unawaited(stopScan());
    final controller = StreamController<BleDiscoveredDevice>.broadcast();
    _scanController = controller;
    _scanSubscription = _ble
        .scanForDevices(withServices: serviceIds.map(Uuid.parse).toList())
        .listen(
          (device) => controller.add(
            BleDiscoveredDevice(
              id: device.id,
              name: device.name.trim().isEmpty
                  ? 'Bluetooth wearable'
                  : device.name.trim(),
              rssi: device.rssi,
              serviceIds: device.serviceUuids
                  .map((uuid) => uuid.toString().toLowerCase())
                  .toSet(),
            ),
          ),
          onError: controller.addError,
        );
    return controller.stream;
  }

  @override
  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    final controller = _scanController;
    _scanController = null;
    if (controller != null && !controller.isClosed) await controller.close();
  }

  @override
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  }) {
    final controller = StreamController<BleConnectionUpdate>.broadcast();
    final stream = _ble.connectToDevice(
      id: deviceId,
      connectionTimeout: timeout,
    );
    _connections[deviceId]?.cancel();
    _connections[deviceId] = stream.listen(
      (update) => controller.add(
        BleConnectionUpdate(deviceId, switch (update.connectionState) {
          DeviceConnectionState.connecting =>
            BleDeviceConnectionState.connecting,
          DeviceConnectionState.connected => BleDeviceConnectionState.connected,
          DeviceConnectionState.disconnecting =>
            BleDeviceConnectionState.disconnecting,
          DeviceConnectionState.disconnected =>
            BleDeviceConnectionState.disconnected,
        }),
      ),
      onError: (Object error) {
        controller.add(
          BleConnectionUpdate(
            deviceId,
            BleDeviceConnectionState.failed,
            error: error,
          ),
        );
        controller.close();
      },
      onDone: controller.close,
    );
    return controller.stream;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    await _connections.remove(deviceId)?.cancel();
  }

  @override
  Future<List<BleGattService>> discoverServices(String deviceId) async {
    await _ble.discoverAllServices(deviceId);
    final services = await _ble.getDiscoveredServices(deviceId);
    return services
        .map(
          (service) => BleGattService(
            id: service.id.toString().toLowerCase(),
            characteristicIds: service.characteristics
                .map((item) => item.id.toString().toLowerCase())
                .toSet(),
          ),
        )
        .toList(growable: false);
  }

  QualifiedCharacteristic _qualified(BleCharacteristic characteristic) =>
      QualifiedCharacteristic(
        deviceId: characteristic.deviceId,
        serviceId: Uuid.parse(characteristic.serviceId),
        characteristicId: Uuid.parse(characteristic.characteristicId),
      );

  @override
  Future<List<int>> read(BleCharacteristic characteristic) =>
      _ble.readCharacteristic(_qualified(characteristic));

  @override
  Future<void> write(BleCharacteristic characteristic, List<int> value) =>
      _ble.writeCharacteristicWithResponse(
        _qualified(characteristic),
        value: value,
      );

  @override
  Stream<List<int>> subscribe(BleCharacteristic characteristic) =>
      _ble.subscribeToCharacteristic(_qualified(characteristic));

  @override
  Future<void> dispose() async {
    await stopScan();
    for (final subscription in _connections.values) {
      await subscription.cancel();
    }
    _connections.clear();
    await _ble.deinitialize();
  }
}
