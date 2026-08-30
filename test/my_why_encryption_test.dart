import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/services/my_why_encryption_service.dart';

void main() {
  final service = MyWhyEncryptionService();
  final key = List<int>.generate(32, (index) => index);

  test('plaintext roundtrips through versioned AES-GCM', () async {
    const plaintext = 'A private reason worth protecting.';
    final encrypted = await service.encryptText(
      plaintext: plaintext,
      keyBytes: key,
      userId: 'user-a',
    );

    expect(encrypted.version, MyWhyEncryptionService.currentVersion);
    expect(
      utf8.decode(encrypted.cipherText, allowMalformed: true),
      isNot(plaintext),
    );
    expect(
      await service.decryptText(
        payload: encrypted,
        keyBytes: key,
        userId: 'user-a',
      ),
      plaintext,
    );
  });

  test('wrong key fails safely', () async {
    final encrypted = await service.encryptText(
      plaintext: 'private',
      keyBytes: key,
      userId: 'user-a',
    );

    expect(
      () => service.decryptText(
        payload: encrypted,
        keyBytes: List<int>.filled(32, 99),
        userId: 'user-a',
      ),
      throwsA(isA<MyWhyDecryptionException>()),
    );
  });

  test('unsupported payload version fails explicitly', () async {
    final payload = MyWhyEncryptedPayload(
      cipherText: Uint8List(1),
      nonce: Uint8List(12),
      mac: Uint8List(16),
      version: 99,
    );
    expect(
      () => service.decryptBytes(
        payload: payload,
        keyBytes: key,
        userId: 'user-a',
        purpose: 'voice',
      ),
      throwsA(isA<MyWhyDecryptionException>()),
    );
  });
}
