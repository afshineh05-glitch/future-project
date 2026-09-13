import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:future_project/models/ble_wearable.dart';

abstract interface class BleDeviceRepository {
  Future<KnownBleWearable?> load();
  Future<void> save(KnownBleWearable device);
  Future<void> clear();
}

class SecureBleDeviceRepository implements BleDeviceRepository {
  final FlutterSecureStorage _storage;
  final String _key;

  SecureBleDeviceRepository({
    required String userId,
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage,
       _key = 'ble_known_device_$userId';

  @override
  Future<KnownBleWearable?> load() async {
    final encoded = await _storage.read(key: _key);
    if (encoded == null) return null;
    try {
      return KnownBleWearable.fromJson(
        Map<String, dynamic>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      await clear();
      return null;
    }
  }

  @override
  Future<void> save(KnownBleWearable device) =>
      _storage.write(key: _key, value: jsonEncode(device.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class VolatileBleDeviceRepository implements BleDeviceRepository {
  KnownBleWearable? _device;
  @override
  Future<KnownBleWearable?> load() async => _device;
  @override
  Future<void> save(KnownBleWearable device) async => _device = device;
  @override
  Future<void> clear() async => _device = null;
}
