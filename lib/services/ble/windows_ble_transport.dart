import 'dart:async';
import 'dart:typed_data';

import 'package:bluetooth_low_energy/bluetooth_low_energy.dart' as win;
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_transport.dart';

/// Windows BLE central transport backed by Windows Runtime Bluetooth APIs.
class WindowsBleTransport implements BleTransport {
  final win.CentralManager _manager;
  final Map<String, win.Peripheral> _peripherals = {};
  final Map<String, win.GATTCharacteristic> _characteristics = {};
  final Map<String, StreamController<BleConnectionUpdate>> _connections = {};
  StreamSubscription<win.DiscoveredEventArgs>? _discoverySubscription;
  StreamSubscription<win.PeripheralConnectionStateChangedEventArgs>?
  _connectionSubscription;
  StreamSubscription<win.GATTCharacteristicNotifiedEventArgs>?
  _notificationSubscription;
  final Map<String, StreamController<List<int>>> _notificationControllers = {};
  StreamController<BleDiscoveredDevice>? _scanController;
  bool _disposed = false;

  WindowsBleTransport({win.CentralManager? manager})
    : _manager = manager ?? win.CentralManager() {
    _connectionSubscription = _manager.connectionStateChanged.listen((event) {
      final id = event.peripheral.uuid.toString().toLowerCase();
      _connections[id]?.add(
        BleConnectionUpdate(
          id,
          event.state == win.ConnectionState.connected
              ? BleDeviceConnectionState.connected
              : BleDeviceConnectionState.disconnected,
        ),
      );
    });
    _notificationSubscription = _manager.characteristicNotified.listen((event) {
      final key = _characteristicKey(
        event.peripheral.uuid.toString(),
        event.characteristic.uuid.toString(),
      );
      _notificationControllers[key]?.add(event.value.toList(growable: false));
    });
  }

  @override
  Stream<BleAvailability> get availability async* {
    yield _mapState(_manager.state);
    yield* _manager.stateChanged
        .map((event) => _mapState(event.state))
        .distinct();
  }

  BleAvailability _mapState(win.BluetoothLowEnergyState state) =>
      switch (state) {
        win.BluetoothLowEnergyState.poweredOn => BleAvailability.ready,
        win.BluetoothLowEnergyState.poweredOff => BleAvailability.bluetoothOff,
        win.BluetoothLowEnergyState.unauthorized =>
          BleAvailability.permissionDenied,
        win.BluetoothLowEnergyState.unsupported => BleAvailability.unsupported,
        win.BluetoothLowEnergyState.unknown => BleAvailability.unavailable,
      };

  @override
  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) {
    if (_disposed) {
      return Stream.error(StateError('BLE transport is disposed.'));
    }
    final controller = StreamController<BleDiscoveredDevice>.broadcast();
    unawaited(_startScan(controller, serviceIds));
    return controller.stream;
  }

  Future<void> _startScan(
    StreamController<BleDiscoveredDevice> controller,
    Set<String> serviceIds,
  ) async {
    await stopScan();
    _scanController = controller;
    _discoverySubscription = _manager.discovered.listen(
      (event) {
        final id = event.peripheral.uuid.toString().toLowerCase();
        _peripherals[id] = event.peripheral;
        String? advertisedName;
        try {
          advertisedName = event.advertisement.name?.trim();
        } catch (_) {
          // Windows advertisements do not consistently expose a local name.
        }
        if (!controller.isClosed) {
          controller.add(
            BleDiscoveredDevice(
              id: id,
              name: advertisedName == null || advertisedName.isEmpty
                  ? 'Bluetooth wearable'
                  : advertisedName,
              rssi: event.rssi,
              serviceIds: event.advertisement.serviceUUIDs
                  .map((uuid) => uuid.toString().toLowerCase())
                  .toSet(),
            ),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!controller.isClosed) controller.addError(error, stack);
      },
    );
    try {
      await _manager.startDiscovery(
        serviceUUIDs: serviceIds.isEmpty
            ? null
            : serviceIds.map(win.UUID.fromString).toList(growable: false),
      );
    } catch (error, stack) {
      if (!controller.isClosed) controller.addError(error, stack);
      await stopScan();
    }
  }

  @override
  Future<void> stopScan() async {
    await _discoverySubscription?.cancel();
    _discoverySubscription = null;
    try {
      await _manager.stopDiscovery();
    } catch (_) {
      // Stopping an already-stopped Windows discovery is harmless.
    }
    final controller = _scanController;
    _scanController = null;
    if (controller != null && !controller.isClosed) await controller.close();
  }

  @override
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  }) {
    final id = deviceId.toLowerCase();
    final peripheral = _peripherals[id];
    if (peripheral == null) {
      return Stream.error(
        StateError('Scan for this device before connecting on Windows.'),
      );
    }
    final controller = StreamController<BleConnectionUpdate>.broadcast();
    _connections[id]?.close();
    _connections[id] = controller;
    controller.add(
      BleConnectionUpdate(id, BleDeviceConnectionState.connecting),
    );
    () async {
      try {
        await _manager.connect(peripheral).timeout(timeout);
        if (!controller.isClosed) {
          controller.add(
            BleConnectionUpdate(id, BleDeviceConnectionState.connected),
          );
        }
      } catch (error, stack) {
        if (!controller.isClosed) {
          controller.add(
            BleConnectionUpdate(
              id,
              BleDeviceConnectionState.failed,
              error: error,
            ),
          );
          controller.addError(error, stack);
        }
      }
    }();
    return controller.stream;
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final id = deviceId.toLowerCase();
    final peripheral = _peripherals[id];
    if (peripheral != null) await _manager.disconnect(peripheral);
    final controller = _connections.remove(id);
    if (controller != null && !controller.isClosed) await controller.close();
  }

  @override
  Future<List<BleGattService>> discoverServices(String deviceId) async {
    final peripheral = _requirePeripheral(deviceId);
    final services = await _manager.discoverGATT(peripheral);
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        _characteristics[_characteristicKey(
              deviceId,
              characteristic.uuid.toString(),
            )] =
            characteristic;
      }
    }
    return services
        .map(
          (service) => BleGattService(
            id: service.uuid.toString().toLowerCase(),
            characteristicIds: service.characteristics
                .map(
                  (characteristic) =>
                      characteristic.uuid.toString().toLowerCase(),
                )
                .toSet(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<int>> read(BleCharacteristic characteristic) async {
    final peripheral = _requirePeripheral(characteristic.deviceId);
    final gatt = _requireCharacteristic(characteristic);
    return (await _manager.readCharacteristic(peripheral, gatt)).toList();
  }

  @override
  Future<void> write(BleCharacteristic characteristic, List<int> value) async {
    final peripheral = _requirePeripheral(characteristic.deviceId);
    final gatt = _requireCharacteristic(characteristic);
    await _manager.writeCharacteristic(
      peripheral,
      gatt,
      value: Uint8List.fromList(value),
      type: win.GATTCharacteristicWriteType.withResponse,
    );
  }

  @override
  Stream<List<int>> subscribe(BleCharacteristic characteristic) {
    final peripheral = _requirePeripheral(characteristic.deviceId);
    final gatt = _requireCharacteristic(characteristic);
    final key = _characteristicKey(
      characteristic.deviceId,
      characteristic.characteristicId,
    );
    final controller = StreamController<List<int>>.broadcast(
      onListen: () =>
          _manager.setCharacteristicNotifyState(peripheral, gatt, state: true),
      onCancel: () =>
          _manager.setCharacteristicNotifyState(peripheral, gatt, state: false),
    );
    _notificationControllers[key]?.close();
    _notificationControllers[key] = controller;
    return controller.stream;
  }

  win.Peripheral _requirePeripheral(String deviceId) {
    final peripheral = _peripherals[deviceId.toLowerCase()];
    if (peripheral == null) throw StateError('BLE device is not available.');
    return peripheral;
  }

  win.GATTCharacteristic _requireCharacteristic(
    BleCharacteristic characteristic,
  ) {
    final value =
        _characteristics[_characteristicKey(
          characteristic.deviceId,
          characteristic.characteristicId,
        )];
    if (value == null) {
      throw StateError('BLE characteristic was not discovered.');
    }
    return value;
  }

  String _characteristicKey(String deviceId, String characteristicId) =>
      '${deviceId.toLowerCase()}|${characteristicId.toLowerCase()}';

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stopScan();
    await _connectionSubscription?.cancel();
    await _notificationSubscription?.cancel();
    for (final controller in _connections.values) {
      await controller.close();
    }
    for (final controller in _notificationControllers.values) {
      await controller.close();
    }
    _connections.clear();
    _notificationControllers.clear();
    _characteristics.clear();
    _peripherals.clear();
  }
}
