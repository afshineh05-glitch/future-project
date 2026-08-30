import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class MyWhyKeyStore {
  Future<List<int>?> read(String userId);
  Future<List<int>> create(String userId);
  Future<void> delete(String userId);
}

class PlatformMyWhyKeyStore implements MyWhyKeyStore {
  static const _prefix = 'my_why_aes256_v1_';
  final FlutterSecureStorage _storage;

  const PlatformMyWhyKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<List<int>?> read(String userId) async {
    final encoded = await _storage.read(key: '$_prefix$userId');
    return encoded == null ? null : base64Decode(encoded);
  }

  @override
  Future<List<int>> create(String userId) async {
    final existing = await read(userId);
    if (existing != null) return existing;
    final random = Random.secure();
    final key = List<int>.generate(32, (_) => random.nextInt(256));
    await _storage.write(key: '$_prefix$userId', value: base64Encode(key));
    return key;
  }

  @override
  Future<void> delete(String userId) => _storage.delete(key: '$_prefix$userId');
}

class MyWhyKeyUnavailableException implements Exception {
  const MyWhyKeyUnavailableException();

  @override
  String toString() =>
      'This My Why was encrypted on another installation and cannot be opened on this device. V1 encryption is device-bound unless secure key recovery is implemented.';
}
