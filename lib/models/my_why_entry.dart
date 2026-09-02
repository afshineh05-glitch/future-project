class MyWhyEntry {
  final String id;
  final String userId;
  final bool hasText;
  final bool hasVoice;
  final bool hasVideo;
  final String? encryptedTextPayload;
  final String? encryptedTextNonce;
  final String? encryptedTextMac;
  final String? voiceStoragePath;
  final String? voiceEncryptionNonce;
  final String? voiceEncryptionMac;
  final Map<String, dynamic>? voiceMetadata;
  final String? videoStoragePath;
  final String? videoEncryptionNonce;
  final String? videoEncryptionMac;
  final Map<String, dynamic>? videoMetadata;
  final int encryptionVersion;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isLegacyV1 => encryptionVersion == 1;

  const MyWhyEntry({
    required this.id,
    required this.userId,
    required this.hasText,
    required this.hasVoice,
    required this.hasVideo,
    required this.encryptedTextPayload,
    required this.encryptedTextNonce,
    required this.encryptedTextMac,
    required this.voiceStoragePath,
    required this.voiceEncryptionNonce,
    required this.voiceEncryptionMac,
    required this.voiceMetadata,
    required this.videoStoragePath,
    required this.videoEncryptionNonce,
    required this.videoEncryptionMac,
    required this.videoMetadata,
    required this.encryptionVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MyWhyEntry.fromMap(Map<String, dynamic> map) => MyWhyEntry(
    id: map['id']?.toString() ?? '',
    userId: map['user_id']?.toString() ?? '',
    hasText: map['has_text'] == true,
    hasVoice: map['has_voice'] == true,
    hasVideo: map['has_video'] == true,
    encryptedTextPayload: map['encrypted_text_payload']?.toString(),
    encryptedTextNonce: map['encrypted_text_nonce']?.toString(),
    encryptedTextMac: map['encrypted_text_mac']?.toString(),
    voiceStoragePath: map['voice_storage_path']?.toString(),
    voiceEncryptionNonce: map['voice_encryption_nonce']?.toString(),
    voiceEncryptionMac: map['voice_encryption_mac']?.toString(),
    voiceMetadata: _map(map['voice_metadata']),
    videoStoragePath: map['video_storage_path']?.toString(),
    videoEncryptionNonce: map['video_encryption_nonce']?.toString(),
    videoEncryptionMac: map['video_encryption_mac']?.toString(),
    videoMetadata: _map(map['video_metadata']),
    encryptionVersion: (map['encryption_version'] as num?)?.toInt() ?? 1,
    createdAt: DateTime.parse(map['created_at'].toString()),
    updatedAt: DateTime.parse(map['updated_at'].toString()),
  );

  static Map<String, dynamic>? _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;
}

class MyWhyViewState {
  final MyWhyEntry? entry;
  final String? text;
  final bool migratedLegacyText;
  final bool hasUnrecoverableLegacy;

  const MyWhyViewState({
    required this.entry,
    required this.text,
    this.migratedLegacyText = false,
    this.hasUnrecoverableLegacy = false,
  });
}
