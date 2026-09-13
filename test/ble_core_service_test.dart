import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_core_service.dart';
import 'package:future_project/services/ble/ble_transport.dart';

void main() {
  group('BleCoreService', () {
    test(
      'permission denied is controlled and does not start scanning',
      () async {
        final transport = _FakeTransport();
        final service = BleCoreService(
          transport: transport,
          permissions: _Permission(false),
        );

        await expectLater(
          service.scan(),
          emitsError(
            isA<BleUnavailableException>().having(
              (error) => error.availability,
              'availability',
              BleAvailability.permissionDenied,
            ),
          ),
        );
        expect(transport.scanCalls, 0);
        await service.dispose();
      },
    );

    test('Bluetooth off is reported without scanning', () async {
      final transport = _FakeTransport(
        initialAvailability: BleAvailability.bluetoothOff,
      );
      final service = _service(transport);
      await expectLater(
        service.scan(),
        emitsError(isA<BleUnavailableException>()),
      );
      expect(transport.scanCalls, 0);
      await service.dispose();
    });

    test('deduplicates identical scan results by device identifier', () async {
      final transport = _FakeTransport();
      final service = _service(transport);
      final results = <BleDiscoveredDevice>[];
      final subscription = service.scan().listen(results.add);
      await Future<void>.delayed(Duration.zero);
      const device = BleDiscoveredDevice(id: 'a', name: 'Band', rssi: -50);
      transport.scanController.add(device);
      transport.scanController.add(device);
      await Future<void>.delayed(Duration.zero);
      expect(results, hasLength(1));
      await subscription.cancel();
      await service.dispose();
    });

    test('connect succeeds and disconnect is forwarded', () async {
      final transport = _FakeTransport();
      final service = _service(transport);
      transport.onConnect = (id) {
        Timer.run(
          () => transport.connectionController.add(
            const BleConnectionUpdate('a', BleDeviceConnectionState.connected),
          ),
        );
      };
      await service.connect('a');
      await service.disconnect('a');
      expect(transport.disconnected, contains('a'));
      await service.dispose();
    });

    test('connect timeout disconnects cleanly', () async {
      final transport = _FakeTransport();
      final service = BleCoreService(
        transport: transport,
        permissions: _Permission(true),
        connectionTimeout: const Duration(milliseconds: 5),
      );
      await expectLater(service.connect('a'), throwsA(isA<TimeoutException>()));
      expect(transport.disconnected, contains('a'));
      await service.dispose();
    });

    test('bounded reconnect retries a known device', () async {
      final transport = _FakeTransport();
      var attempts = 0;
      transport.onConnect = (id) {
        attempts++;
        scheduleMicrotask(() {
          transport.connectionController.add(
            BleConnectionUpdate(
              id,
              attempts == 1
                  ? BleDeviceConnectionState.failed
                  : BleDeviceConnectionState.connected,
            ),
          );
        });
      };
      final service = BleCoreService(
        transport: transport,
        permissions: _Permission(true),
        delay: (_) async {},
      );
      final connected = await service.reconnectKnown(
        KnownBleWearable(
          id: 'a',
          displayName: 'Band',
          adapterType: 'standard_heart_rate',
          lastConnectedAt: DateTime(2026),
          reconnectEnabled: true,
        ),
      );
      expect(connected, isTrue);
      expect(attempts, 2);
      await service.dispose();
    });

    test('service discovery failure remains an explicit error', () async {
      final transport = _FakeTransport()..discoveryError = StateError('gatt');
      final service = _service(transport);
      await expectLater(
        service.discoverServices('a'),
        throwsA(isA<StateError>()),
      );
      await service.dispose();
    });
  });
}

BleCoreService _service(_FakeTransport transport) => BleCoreService(
  transport: transport,
  permissions: _Permission(true),
  connectionTimeout: const Duration(milliseconds: 50),
);

class _Permission implements BlePermissionGateway {
  final bool granted;
  _Permission(this.granted);
  @override
  Future<bool> requestScanAndConnect() async => granted;
}

class _FakeTransport implements BleTransport {
  final BleAvailability initialAvailability;
  final scanController = StreamController<BleDiscoveredDevice>.broadcast();
  final connectionController =
      StreamController<BleConnectionUpdate>.broadcast();
  int scanCalls = 0;
  final disconnected = <String>[];
  void Function(String)? onConnect;
  Object? discoveryError;

  _FakeTransport({this.initialAvailability = BleAvailability.ready});

  @override
  Stream<BleAvailability> get availability => Stream.value(initialAvailability);
  @override
  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) {
    scanCalls++;
    return scanController.stream;
  }

  @override
  Future<void> stopScan() async {}
  @override
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  }) {
    onConnect?.call(deviceId);
    return connectionController.stream;
  }

  @override
  Future<void> disconnect(String deviceId) async => disconnected.add(deviceId);
  @override
  Future<List<BleGattService>> discoverServices(String deviceId) async {
    if (discoveryError != null) throw discoveryError!;
    return const [];
  }

  @override
  Future<List<int>> read(BleCharacteristic characteristic) async => const [];
  @override
  Future<void> write(BleCharacteristic characteristic, List<int> value) async {}
  @override
  Stream<List<int>> subscribe(BleCharacteristic characteristic) =>
      const Stream.empty();
  @override
  Future<void> dispose() async {
    await scanController.close();
    await connectionController.close();
  }
}
