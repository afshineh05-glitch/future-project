import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class MyWhyRecoveryKeyCache {
  Future<List<int>?> read(String userId);
  Future<void> write(String userId, List<int> key);
  Future<void> delete(String userId);
}

class PlatformMyWhyRecoveryKeyCache implements MyWhyRecoveryKeyCache {
  static const _prefix = 'my_why_recovery_aes256_v2_';
  final FlutterSecureStorage _storage;

  const PlatformMyWhyRecoveryKeyCache({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  }) : _storage = storage;

  @override
  Future<List<int>?> read(String userId) async {
    final encoded = await _storage.read(key: '$_prefix$userId');
    return encoded == null ? null : base64Decode(encoded);
  }

  @override
  Future<void> write(String userId, List<int> key) =>
      _storage.write(key: '$_prefix$userId', value: base64Encode(key));

  @override
  Future<void> delete(String userId) => _storage.delete(key: '$_prefix$userId');
}

abstract interface class MyWhyRecoveryKeyApi {
  Future<List<int>> recoverOrCreate(String userId);
  Future<List<int>> registerLegacyKey(String userId, List<int> legacyKey);
  Future<void> deleteEnvelope(String userId);
}

class SupabaseMyWhyRecoveryKeyApi implements MyWhyRecoveryKeyApi {
  static const _functionName = 'my-why-recovery-key';
  final SupabaseClient _supabase;

  SupabaseMyWhyRecoveryKeyApi(this._supabase);

  @override
  Future<List<int>> recoverOrCreate(String userId) {
    _assertAuthenticatedUser(userId);
    return _invoke('recover_or_create');
  }

  @override
  Future<List<int>> registerLegacyKey(String userId, List<int> legacyKey) {
    _assertAuthenticatedUser(userId);
    return _invoke('register_legacy_key', {
      'legacy_key_base64': base64Encode(legacyKey),
    });
  }

  @override
  Future<void> deleteEnvelope(String userId) async {
    _assertAuthenticatedUser(userId);
    await _supabase.functions.invoke(
      _functionName,
      body: const {'operation': 'delete_envelope'},
    );
  }

  void _assertAuthenticatedUser(String userId) {
    if (_supabase.auth.currentUser?.id != userId) {
      throw const MyWhyRecoveryException('Sign in to recover My Why.');
    }
  }

  Future<List<int>> _invoke(
    String operation, [
    Map<String, dynamic>? values,
  ]) async {
    final response = await _supabase.functions.invoke(
      _functionName,
      body: {'operation': operation, ...?values},
    );
    final data = response.data;
    if (data is! Map || data['key_base64'] is! String) {
      throw const MyWhyRecoveryException('Key recovery did not return a key.');
    }
    final key = base64Decode(data['key_base64'] as String);
    if (key.length != 32) {
      throw const MyWhyRecoveryException(
        'Recovered key has an invalid length.',
      );
    }
    return key;
  }
}

class MyWhyRecoveryKeyService {
  final MyWhyRecoveryKeyCache _cache;
  final MyWhyRecoveryKeyApi _api;

  MyWhyRecoveryKeyService({
    required MyWhyRecoveryKeyCache cache,
    required MyWhyRecoveryKeyApi api,
  }) : _cache = cache,
       _api = api;

  Future<List<int>> recoverOrCreate(String userId) async {
    final cached = await _cache.read(userId);
    if (cached != null && cached.length == 32) return cached;
    final key = await _api.recoverOrCreate(userId);
    await _cache.write(userId, key);
    return key;
  }

  Future<List<int>> registerLegacyKey(
    String userId,
    List<int> legacyKey,
  ) async {
    if (legacyKey.length != 32) {
      throw const MyWhyRecoveryException('Legacy key has an invalid length.');
    }
    final recovered = await _api.registerLegacyKey(userId, legacyKey);
    await _cache.write(userId, recovered);
    return recovered;
  }

  Future<void> delete(String userId) async {
    await _api.deleteEnvelope(userId);
    await _cache.delete(userId);
  }
}

class MyWhyRecoveryException implements Exception {
  final String message;
  const MyWhyRecoveryException(this.message);

  @override
  String toString() => message;
}
