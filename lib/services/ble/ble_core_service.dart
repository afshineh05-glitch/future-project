import 'dart:async';

import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_transport.dart';

class BleUnavailableException implements Exception {
  final BleAvailability availability;
  const BleUnavailableException(this.availability);
  @override
  String toString() => 'BLE unavailable: ${availability.name}';
}

class BleCoreService {
  final BleTransport _transport;
  final BlePermissionGateway _permissions;
  final Duration connectionTimeout;
  final Future<void> Function(Duration) _delay;
  final _connectionStates = StreamController<BleConnectionUpdate>.broadcast();
  StreamSubscription<BleDiscoveredDevice>? _scanSubscription;
  StreamSubscription<BleConnectionUpdate>? _connectionSubscription;
  final Set<String> _manualDisconnects = {};
  bool _disposed = false;

  BleCoreService({
    required BleTransport transport,
    required BlePermissionGateway permissions,
    this.connectionTimeout = const Duration(seconds: 15),
    Future<void> Function(Duration)? delay,
  }) : _transport = transport,
       _permissions = permissions,
       _delay = delay ?? Future.delayed;

  Stream<BleAvailability> get availability => _transport.availability;
  Stream<BleConnectionUpdate> get connectionStates => _connectionStates.stream;

  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) {
    final controller = StreamController<BleDiscoveredDevice>();
    final seen = <String, BleDiscoveredDevice>{};
    () async {
      try {
        if (!await _permissions.requestScanAndConnect()) {
          throw const BleUnavailableException(BleAvailability.permissionDenied);
        }
        final state = await availability
            .firstWhere((value) => value != BleAvailability.unavailable)
            .timeout(
              const Duration(seconds: 5),
              onTimeout: () => BleAvailability.unavailable,
            );
        if (state != BleAvailability.ready) {
          throw BleUnavailableException(state);
        }
        await _scanSubscription?.cancel();
        _scanSubscription = _transport
            .scan(serviceIds: serviceIds)
            .listen(
              (device) {
                final previous = seen[device.id];
                if (previous != null &&
                    previous.name == device.name &&
                    previous.rssi == device.rssi &&
                    _sameSet(previous.serviceIds, device.serviceIds)) {
                  return;
                }
                seen[device.id] = device;
                controller.add(device);
              },
              onError: controller.addError,
              onDone: controller.close,
            );
      } catch (error, stack) {
        controller.addError(error, stack);
        await controller.close();
      }
    }();
    controller.onCancel = stopScan;
    return controller.stream;
  }

  Future<void> stopScan() async {
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _transport.stopScan();
  }

  Future<void> connect(String deviceId) async {
    if (_disposed) throw StateError('BLE service is disposed.');
    if (!await _permissions.requestScanAndConnect()) {
      throw const BleUnavailableException(BleAvailability.permissionDenied);
    }
    _manualDisconnects.remove(deviceId);
    await _connectionSubscription?.cancel();
    final completer = Completer<void>();
    _connectionSubscription = _transport
        .connect(deviceId, timeout: connectionTimeout)
        .listen(
          (update) {
            if (!_connectionStates.isClosed) _connectionStates.add(update);
            if (update.state == BleDeviceConnectionState.connected &&
                !completer.isCompleted) {
              completer.complete();
            } else if ((update.state == BleDeviceConnectionState.failed ||
                    update.state == BleDeviceConnectionState.disconnected) &&
                !completer.isCompleted) {
              completer.completeError(
                update.error ?? StateError('BLE connection failed.'),
              );
            }
          },
          onError: (Object error, StackTrace stack) {
            if (!completer.isCompleted) completer.completeError(error, stack);
          },
        );
    try {
      await completer.future.timeout(connectionTimeout);
    } on TimeoutException {
      await _transport.disconnect(deviceId);
      rethrow;
    }
  }

  Future<bool> reconnectKnown(
    KnownBleWearable device, {
    int maxAttempts = 2,
    Duration initialBackoff = const Duration(seconds: 2),
  }) async {
    if (!device.reconnectEnabled || _manualDisconnects.contains(device.id)) {
      return false;
    }
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) await _delay(initialBackoff * (1 << (attempt - 1)));
      try {
        await connect(device.id);
        return true;
      } catch (_) {
        if (_manualDisconnects.contains(device.id)) return false;
      }
    }
    return false;
  }

  Future<void> disconnect(String deviceId, {bool manual = true}) async {
    if (manual) _manualDisconnects.add(deviceId);
    if (!_connectionStates.isClosed) {
      _connectionStates.add(
        BleConnectionUpdate(deviceId, BleDeviceConnectionState.disconnecting),
      );
    }
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    await _transport.disconnect(deviceId);
    if (!_connectionStates.isClosed) {
      _connectionStates.add(
        BleConnectionUpdate(deviceId, BleDeviceConnectionState.disconnected),
      );
    }
  }

  Future<List<BleGattService>> discoverServices(String deviceId) =>
      _transport.discoverServices(deviceId);
  Future<List<int>> read(BleCharacteristic characteristic) =>
      _transport.read(characteristic);
  Future<void> write(BleCharacteristic characteristic, List<int> value) =>
      _transport.write(characteristic, value);
  Stream<List<int>> subscribe(BleCharacteristic characteristic) =>
      _transport.subscribe(characteristic);

  Future<void> dispose() async {
    _disposed = true;
    await stopScan();
    await _connectionSubscription?.cancel();
    await _transport.dispose();
    await _connectionStates.close();
  }
}

bool _sameSet(Set<String> a, Set<String> b) =>
    a.length == b.length && a.containsAll(b);
