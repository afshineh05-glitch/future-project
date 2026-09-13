import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_transport.dart';
import 'package:future_project/services/ble/ble_transport_factory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('selects the correct transport without leaking platform checks', () {
    BleTransport build(String name) => _NamedTransport(name);
    expect(
      (BleTransportFactory.createFor(
                BleRuntimePlatform.windows,
                windowsBuilder: () => build('windows'),
              )
              as _NamedTransport)
          .name,
      'windows',
    );
    expect(
      (BleTransportFactory.createFor(
                BleRuntimePlatform.androidOrIos,
                mobileBuilder: () => build('mobile'),
              )
              as _NamedTransport)
          .name,
      'mobile',
    );
    expect(
      (BleTransportFactory.createFor(
                BleRuntimePlatform.unsupported,
                unsupportedBuilder: () => build('unsupported'),
              )
              as _NamedTransport)
          .name,
      'unsupported',
    );
  });
}

class _NamedTransport implements BleTransport {
  final String name;
  _NamedTransport(this.name);
  @override
  Stream<BleAvailability> get availability =>
      Stream.value(BleAvailability.ready);
  @override
  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) =>
      const Stream.empty();
  @override
  Future<void> stopScan() async {}
  @override
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  }) => const Stream.empty();
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<List<BleGattService>> discoverServices(String deviceId) async =>
      const [];
  @override
  Future<List<int>> read(BleCharacteristic characteristic) async => const [];
  @override
  Future<void> write(BleCharacteristic characteristic, List<int> value) async {}
  @override
  Stream<List<int>> subscribe(BleCharacteristic characteristic) =>
      const Stream.empty();
  @override
  Future<void> dispose() async {}
}
