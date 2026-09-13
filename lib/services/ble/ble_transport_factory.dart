import 'dart:io';

import 'package:future_project/services/ble/ble_transport.dart';
import 'package:future_project/services/ble/reactive_ble_transport.dart';
import 'package:future_project/services/ble/windows_ble_transport.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_core_service.dart';

enum BleRuntimePlatform { androidOrIos, windows, unsupported }

abstract final class BleTransportFactory {
  static BleTransport create() {
    final platform = Platform.isWindows
        ? BleRuntimePlatform.windows
        : Platform.isAndroid || Platform.isIOS
        ? BleRuntimePlatform.androidOrIos
        : BleRuntimePlatform.unsupported;
    return createFor(platform);
  }

  static BleTransport createFor(
    BleRuntimePlatform platform, {
    BleTransport Function()? windowsBuilder,
    BleTransport Function()? mobileBuilder,
    BleTransport Function()? unsupportedBuilder,
  }) => switch (platform) {
    BleRuntimePlatform.windows =>
      windowsBuilder?.call() ?? WindowsBleTransport(),
    BleRuntimePlatform.androidOrIos =>
      mobileBuilder?.call() ?? ReactiveBleTransport(),
    BleRuntimePlatform.unsupported =>
      unsupportedBuilder?.call() ?? UnsupportedBleTransport(),
  };
}

class UnsupportedBleTransport implements BleTransport {
  @override
  Stream<BleAvailability> get availability =>
      Stream.value(BleAvailability.unsupported);
  @override
  Stream<BleDiscoveredDevice> scan({Set<String> serviceIds = const {}}) =>
      Stream.error(const BleUnavailableException(BleAvailability.unsupported));
  @override
  Future<void> stopScan() async {}
  @override
  Stream<BleConnectionUpdate> connect(
    String deviceId, {
    required Duration timeout,
  }) =>
      Stream.error(const BleUnavailableException(BleAvailability.unsupported));
  @override
  Future<void> disconnect(String deviceId) async {}
  @override
  Future<List<BleGattService>> discoverServices(String deviceId) async =>
      throw const BleUnavailableException(BleAvailability.unsupported);
  @override
  Future<List<int>> read(BleCharacteristic characteristic) async =>
      throw const BleUnavailableException(BleAvailability.unsupported);
  @override
  Future<void> write(BleCharacteristic characteristic, List<int> value) async =>
      throw const BleUnavailableException(BleAvailability.unsupported);
  @override
  Stream<List<int>> subscribe(BleCharacteristic characteristic) =>
      Stream.error(const BleUnavailableException(BleAvailability.unsupported));
  @override
  Future<void> dispose() async {}
}
