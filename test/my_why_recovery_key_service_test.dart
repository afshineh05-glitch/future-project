import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/my_why_entry.dart';
import 'package:future_project/services/my_why_encryption_service.dart';
import 'package:future_project/services/my_why_key_store.dart';
import 'package:future_project/services/my_why_recovery_key_service.dart';

void main() {
  test('new content encrypts and decrypts with a recovered V2 key', () async {
    final api = FakeRecoveryApi('user-a');
    final firstDevice = MyWhyRecoveryKeyService(
      cache: FakeKeyCache(),
      api: api,
    );
    final secondDevice = MyWhyRecoveryKeyService(
      cache: FakeKeyCache(),
      api: api,
    );
    final encryption = MyWhyEncryptionService();
    final key = await firstDevice.recoverOrCreate('user-a');
    final payload = await encryption.encryptText(
      plaintext: 'Private across devices',
      keyBytes: key,
      userId: 'user-a',
    );

    expect(payload.version, MyWhyEncryptionService.currentVersion);
    expect(
      await encryption.decryptText(
        payload: payload,
        keyBytes: await secondDevice.recoverOrCreate('user-a'),
        userId: 'user-a',
      ),
      'Private across devices',
    );
  });

  test(
    'a different authenticated user cannot recover another users key',
    () async {
      final api = FakeRecoveryApi('user-a');
      final recovery = MyWhyRecoveryKeyService(cache: FakeKeyCache(), api: api);

      await expectLater(
        recovery.recoverOrCreate('user-b'),
        throwsA(isA<MyWhyRecoveryException>()),
      );
    },
  );

  test(
    'a new installation recovers the same key after local cache loss',
    () async {
      final api = FakeRecoveryApi('user-a');
      final initial = MyWhyRecoveryKeyService(cache: FakeKeyCache(), api: api);
      final initialKey = await initial.recoverOrCreate('user-a');
      final reinstalled = MyWhyRecoveryKeyService(
        cache: FakeKeyCache(),
        api: api,
      );

      expect(await reinstalled.recoverOrCreate('user-a'), initialKey);
    },
  );

  test(
    'accessible V1 key registers a recovery envelope for migration',
    () async {
      final api = FakeRecoveryApi('user-a');
      final recovery = MyWhyRecoveryKeyService(cache: FakeKeyCache(), api: api);
      final legacyKey = List<int>.generate(32, (index) => index);
      final legacyEntry = MyWhyEntry(
        id: 'legacy',
        userId: 'user-a',
        hasText: true,
        hasVoice: false,
        hasVideo: false,
        encryptedTextPayload: 'payload',
        encryptedTextNonce: 'nonce',
        encryptedTextMac: 'mac',
        voiceStoragePath: null,
        voiceEncryptionNonce: null,
        voiceEncryptionMac: null,
        voiceMetadata: null,
        videoStoragePath: null,
        videoEncryptionNonce: null,
        videoEncryptionMac: null,
        videoMetadata: null,
        encryptionVersion: 1,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      expect(legacyEntry.isLegacyV1, isTrue);
      expect(await recovery.registerLegacyKey('user-a', legacyKey), legacyKey);
    },
  );

  test('missing V1 device key remains explicitly unrecoverable', () {
    const error = MyWhyLegacyUnrecoverableException();

    expect(error.toString(), contains('original device key is unavailable'));
  });

  test('view state can preserve an unrecoverable V1 entry for fresh V2', () {
    final legacyEntry = MyWhyEntry(
      id: 'legacy',
      userId: 'user-a',
      hasText: true,
      hasVoice: true,
      hasVideo: true,
      encryptedTextPayload: 'ciphertext',
      encryptedTextNonce: 'nonce',
      encryptedTextMac: 'mac',
      voiceStoragePath: 'user-a/voice/legacy.bin',
      voiceEncryptionNonce: 'voice-nonce',
      voiceEncryptionMac: 'voice-mac',
      voiceMetadata: const {'duration_seconds': 10},
      videoStoragePath: 'user-a/video/legacy.bin',
      videoEncryptionNonce: 'video-nonce',
      videoEncryptionMac: 'video-mac',
      videoMetadata: const {'duration_seconds': 20},
      encryptionVersion: 1,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final state = MyWhyViewState(
      entry: legacyEntry,
      text: null,
      hasUnrecoverableLegacy: true,
    );

    expect(state.hasUnrecoverableLegacy, isTrue);
    expect(state.entry, same(legacyEntry));
    expect(state.text, isNull);
  });
}

class FakeKeyCache implements MyWhyRecoveryKeyCache {
  List<int>? value;
  @override
  Future<void> delete(String userId) async => value = null;
  @override
  Future<List<int>?> read(String userId) async => value;
  @override
  Future<void> write(String userId, List<int> key) async => value = key;
}

class FakeRecoveryApi implements MyWhyRecoveryKeyApi {
  final String authenticatedUserId;
  final Map<String, List<int>> _keys = {};
  FakeRecoveryApi(this.authenticatedUserId);

  void _check(String userId) {
    if (userId != authenticatedUserId) {
      throw const MyWhyRecoveryException('Unauthorized recovery attempt.');
    }
  }

  @override
  Future<void> deleteEnvelope(String userId) async {
    _check(userId);
    _keys.remove(userId);
  }

  @override
  Future<List<int>> recoverOrCreate(String userId) async {
    _check(userId);
    return _keys.putIfAbsent(userId, () => List<int>.generate(32, (i) => i));
  }

  @override
  Future<List<int>> registerLegacyKey(
    String userId,
    List<int> legacyKey,
  ) async {
    _check(userId);
    return _keys.putIfAbsent(userId, () => List<int>.from(legacyKey));
  }
}
