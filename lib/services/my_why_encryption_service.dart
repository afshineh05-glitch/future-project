import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class MyWhyEncryptedPayload {
  final Uint8List cipherText;
  final Uint8List nonce;
  final Uint8List mac;
  final int version;

  const MyWhyEncryptedPayload({
    required this.cipherText,
    required this.nonce,
    required this.mac,
    this.version = MyWhyEncryptionService.currentVersion,
  });

  String get cipherTextBase64 => base64Encode(cipherText);
  String get nonceBase64 => base64Encode(nonce);
  String get macBase64 => base64Encode(mac);

  factory MyWhyEncryptedPayload.fromBase64({
    required String cipherText,
    required String nonce,
    required String mac,
    required int version,
  }) => MyWhyEncryptedPayload(
    cipherText: Uint8List.fromList(base64Decode(cipherText)),
    nonce: Uint8List.fromList(base64Decode(nonce)),
    mac: Uint8List.fromList(base64Decode(mac)),
    version: version,
  );
}

class MyWhyEncryptionService {
  static const legacyVersion = 1;
  static const currentVersion = 2;
  final Cipher _cipher;

  MyWhyEncryptionService({Cipher? cipher})
    : _cipher = cipher ?? AesGcm.with256bits();

  Future<MyWhyEncryptedPayload> encryptText({
    required String plaintext,
    required List<int> keyBytes,
    required String userId,
    int version = currentVersion,
  }) => encryptBytes(
    plaintext: Uint8List.fromList(utf8.encode(plaintext)),
    keyBytes: keyBytes,
    userId: userId,
    purpose: 'text',
    version: version,
  );

  Future<String> decryptText({
    required MyWhyEncryptedPayload payload,
    required List<int> keyBytes,
    required String userId,
  }) async => utf8.decode(
    await decryptBytes(
      payload: payload,
      keyBytes: keyBytes,
      userId: userId,
      purpose: 'text',
    ),
  );

  Future<MyWhyEncryptedPayload> encryptBytes({
    required Uint8List plaintext,
    required List<int> keyBytes,
    required String userId,
    required String purpose,
    int version = currentVersion,
  }) async {
    _validateVersion(version);
    final box = await _cipher.encrypt(
      plaintext,
      secretKey: SecretKey(keyBytes),
      aad: _aad(userId, purpose, version),
    );
    return MyWhyEncryptedPayload(
      cipherText: Uint8List.fromList(box.cipherText),
      nonce: Uint8List.fromList(box.nonce),
      mac: Uint8List.fromList(box.mac.bytes),
      version: version,
    );
  }

  Future<Uint8List> decryptBytes({
    required MyWhyEncryptedPayload payload,
    required List<int> keyBytes,
    required String userId,
    required String purpose,
  }) async {
    _validateVersion(payload.version);
    try {
      final clear = await _cipher.decrypt(
        SecretBox(
          payload.cipherText,
          nonce: payload.nonce,
          mac: Mac(payload.mac),
        ),
        secretKey: SecretKey(keyBytes),
        aad: _aad(userId, purpose, payload.version),
      );
      return Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const MyWhyDecryptionException(
        'This My Why content could not be decrypted with this device key.',
      );
    }
  }

  List<int> _aad(String userId, String purpose, int version) =>
      utf8.encode('my-why:v$version:$userId:$purpose');

  void _validateVersion(int version) {
    if (version != legacyVersion && version != currentVersion) {
      throw MyWhyDecryptionException(
        'Unsupported My Why encryption version: $version.',
      );
    }
  }
}

class MyWhyDecryptionException implements Exception {
  final String message;
  const MyWhyDecryptionException(this.message);

  @override
  String toString() => message;
}
