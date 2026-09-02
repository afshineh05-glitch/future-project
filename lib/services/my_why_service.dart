import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:future_project/models/my_why_entry.dart';
import 'package:future_project/services/my_why_encryption_service.dart';
import 'package:future_project/services/my_why_key_store.dart';
import 'package:future_project/services/my_why_recovery_key_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum MyWhyMediaKind { voice, video }

class MyWhyService {
  static const bucket = 'my-why-private';
  static const maxTextCharacters = 5000;
  static const maxVoiceDuration = Duration(minutes: 5);
  static const maxVideoDuration = Duration(minutes: 2);
  static const maxVoiceBytes = 20 * 1024 * 1024;
  static const maxVideoBytes = 100 * 1024 * 1024;

  final SupabaseClient _supabase;
  final MyWhyEncryptionService _encryption;
  final MyWhyKeyStore _keyStore;
  final MyWhyRecoveryKeyService _recoveryKeys;
  final Set<String> _temporaryPlaybackPaths = {};

  MyWhyService({
    SupabaseClient? supabase,
    MyWhyEncryptionService? encryption,
    MyWhyKeyStore? keyStore,
    MyWhyRecoveryKeyService? recoveryKeys,
  }) : _supabase = supabase ?? Supabase.instance.client,
       _encryption = encryption ?? MyWhyEncryptionService(),
       _keyStore = keyStore ?? const PlatformMyWhyKeyStore(),
       _recoveryKeys =
           recoveryKeys ??
           MyWhyRecoveryKeyService(
             cache: const PlatformMyWhyRecoveryKeyCache(),
             api: SupabaseMyWhyRecoveryKeyApi(
               supabase ?? Supabase.instance.client,
             ),
           );

  Future<MyWhyViewState> load({String? legacyPlaintext}) async {
    final user = _requireUser();
    var entry = await _loadEntry(user.id);
    var migrated = false;
    final legacy = legacyPlaintext?.trim() ?? '';

    if (legacy.isNotEmpty && (entry == null || !entry.hasText)) {
      entry = await saveText(legacy);
      await _clearLegacyPlaintext(user.id);
      migrated = true;
    } else if (legacy.isNotEmpty && entry?.hasText == true) {
      if (entry!.isLegacyV1) {
        entry = await _migrateLegacyV1Entry(entry, user.id);
      }
      await _decryptEntryText(entry, user.id);
      await _clearLegacyPlaintext(user.id);
      migrated = true;
    }

    var hasUnrecoverableLegacy = false;
    if (entry?.isLegacyV1 == true) {
      try {
        entry = await _migrateLegacyV1Entry(entry!, user.id);
      } on MyWhyLegacyUnrecoverableException {
        hasUnrecoverableLegacy = true;
      }
    }

    final text = !hasUnrecoverableLegacy && entry?.hasText == true
        ? await _decryptEntryText(entry!, user.id)
        : null;
    return MyWhyViewState(
      entry: entry,
      text: text,
      migratedLegacyText: migrated,
      hasUnrecoverableLegacy: hasUnrecoverableLegacy,
    );
  }

  Future<MyWhyEntry> saveText(
    String text, {
    bool startFreshIfLegacyUnrecoverable = false,
  }) async {
    final normalized = text.trim();
    if (normalized.length > maxTextCharacters) {
      throw const MyWhyValidationException(
        'My Why text can be up to 5,000 characters.',
      );
    }
    final user = _requireUser();
    if (normalized.isEmpty) {
      final existing = await _prepareForV2Write(
        user.id,
        startFreshIfLegacyUnrecoverable: false,
      );
      if (existing == null) {
        throw const MyWhyValidationException(
          'There is no My Why text to save.',
        );
      }
      return _updateAndReturn(user.id, {
        'encrypted_text_payload': null,
        'encrypted_text_nonce': null,
        'encrypted_text_mac': null,
        'updated_at': _now(),
      });
    }
    final key = await _v2KeyForWrite(user.id);
    final payload = await _encryption.encryptText(
      plaintext: normalized,
      keyBytes: key,
      userId: user.id,
    );
    await _prepareForV2Write(
      user.id,
      startFreshIfLegacyUnrecoverable: startFreshIfLegacyUnrecoverable,
    );
    return _upsertAndReturn({
      'user_id': user.id,
      'encrypted_text_payload': payload.cipherTextBase64,
      'encrypted_text_nonce': payload.nonceBase64,
      'encrypted_text_mac': payload.macBase64,
      'encryption_version': payload.version,
      'updated_at': _now(),
    });
  }

  Future<MyWhyEntry> saveMedia({
    required MyWhyMediaKind kind,
    required Uint8List clearBytes,
    required Duration duration,
    required String playbackExtension,
    required String playbackMimeType,
    bool startFreshIfLegacyUnrecoverable = false,
  }) async {
    _validateMedia(kind, clearBytes.length, duration);
    final user = _requireUser();
    final key = await _v2KeyForWrite(user.id);
    final purpose = kind.name;
    final encrypted = await _encryption.encryptBytes(
      plaintext: clearBytes,
      keyBytes: key,
      userId: user.id,
      purpose: purpose,
    );
    final existing = await _prepareForV2Write(
      user.id,
      startFreshIfLegacyUnrecoverable: startFreshIfLegacyUnrecoverable,
    );
    final path = '${user.id}/$purpose/${_randomObjectName()}.bin';
    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          path,
          encrypted.cipherText,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            cacheControl: '0',
            upsert: false,
          ),
        );
    final prefix = purpose;
    var databaseSaved = false;
    try {
      final updated = await _upsertAndReturn({
        'user_id': user.id,
        '${prefix}_storage_path': path,
        '${prefix}_encryption_nonce': encrypted.nonceBase64,
        '${prefix}_encryption_mac': encrypted.macBase64,
        '${prefix}_metadata': {
          'duration_seconds': duration.inSeconds,
          'clear_byte_length': clearBytes.length,
          'playback_extension': _safeExtension(playbackExtension),
          'playback_mime_type': playbackMimeType,
        },
        'encryption_version': encrypted.version,
        'updated_at': _now(),
      });
      databaseSaved = true;
      final previous = kind == MyWhyMediaKind.voice
          ? existing?.voiceStoragePath
          : existing?.videoStoragePath;
      if (previous != null && previous != path) {
        try {
          await _supabase.storage.from(bucket).remove([previous]);
        } catch (_) {
          throw const MyWhyPartialFailureException(
            'The new private media was saved, but the previous encrypted object could not be cleaned up.',
          );
        }
      }
      return updated;
    } catch (_) {
      if (!databaseSaved) {
        try {
          await _supabase.storage.from(bucket).remove([path]);
        } catch (_) {
          // Never log paths or encrypted payloads. RLS still protects this orphan.
        }
      }
      rethrow;
    }
  }

  Future<String> createPlaybackFile(
    MyWhyEntry entry,
    MyWhyMediaKind kind,
  ) async {
    final user = _requireUser();
    if (entry.userId != user.id) throw const MyWhyAccessException();
    final path = kind == MyWhyMediaKind.voice
        ? entry.voiceStoragePath
        : entry.videoStoragePath;
    final nonce = kind == MyWhyMediaKind.voice
        ? entry.voiceEncryptionNonce
        : entry.videoEncryptionNonce;
    final mac = kind == MyWhyMediaKind.voice
        ? entry.voiceEncryptionMac
        : entry.videoEncryptionMac;
    final metadata = kind == MyWhyMediaKind.voice
        ? entry.voiceMetadata
        : entry.videoMetadata;
    if (path == null || nonce == null || mac == null || metadata == null) {
      throw const MyWhyValidationException(
        'This private media is unavailable.',
      );
    }
    final key = await _keyForEntry(entry, user.id);
    final encrypted = await _supabase.storage.from(bucket).download(path);
    final clear = await _encryption.decryptBytes(
      payload: MyWhyEncryptedPayload.fromBase64(
        cipherText: base64Encode(encrypted),
        nonce: nonce,
        mac: mac,
        version: entry.encryptionVersion,
      ),
      keyBytes: key,
      userId: user.id,
      purpose: kind.name,
    );
    final directory = await getTemporaryDirectory();
    final extension = Platform.isWindows && kind == MyWhyMediaKind.voice
        ? 'aac'
        : _safeExtension(
            metadata['playback_extension']?.toString() ??
                (kind == MyWhyMediaKind.voice ? 'm4a' : 'mp4'),
          );
    final file = File(
      '${directory.path}${Platform.pathSeparator}my_why_${kind.name}_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(clear, flush: true);
    _temporaryPlaybackPaths.add(file.path);
    return file.path;
  }

  Future<MyWhyEntry?> deleteMedia(MyWhyMediaKind kind) async {
    final user = _requireUser();
    final entry = await _loadEntry(user.id);
    if (entry == null) return null;
    final path = kind == MyWhyMediaKind.voice
        ? entry.voiceStoragePath
        : entry.videoStoragePath;
    if (path == null) return entry;
    await _supabase.storage.from(bucket).remove([path]);
    final prefix = kind.name;
    try {
      return await _updateAndReturn(user.id, {
        '${prefix}_storage_path': null,
        '${prefix}_encryption_nonce': null,
        '${prefix}_encryption_mac': null,
        '${prefix}_metadata': null,
        'updated_at': _now(),
      });
    } catch (_) {
      throw const MyWhyPartialFailureException(
        'The encrypted media was deleted, but its database metadata could not be cleared. Please retry.',
      );
    }
  }

  Future<void> deleteEntire() async {
    final user = _requireUser();
    final entry = await _loadEntry(user.id);
    if (entry == null) return;
    final paths = [
      if (entry.voiceStoragePath != null) entry.voiceStoragePath!,
      if (entry.videoStoragePath != null) entry.videoStoragePath!,
    ];
    if (paths.isNotEmpty) await _supabase.storage.from(bucket).remove(paths);
    try {
      await _supabase.from('my_why_entries').delete().eq('user_id', user.id);
    } catch (_) {
      throw const MyWhyPartialFailureException(
        'Private media was deleted, but the My Why database row could not be deleted. Please retry.',
      );
    }
    await clearPlaybackFiles();
    await _keyStore.delete(user.id);
    await _recoveryKeys.delete(user.id);
  }

  Future<void> clearPlaybackFiles() async {
    for (final path in _temporaryPlaybackPaths.toList()) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {
        // Best-effort cleanup; never log private temporary paths.
      }
      _temporaryPlaybackPaths.remove(path);
    }
  }

  Future<MyWhyEntry?> _loadEntry(String userId) async {
    final row = await _supabase
        .from('my_why_entries')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : MyWhyEntry.fromMap(row);
  }

  Future<String> _decryptEntryText(MyWhyEntry entry, String userId) async {
    final key = await _keyForEntry(entry, userId);
    return _encryption.decryptText(
      payload: MyWhyEncryptedPayload.fromBase64(
        cipherText: entry.encryptedTextPayload!,
        nonce: entry.encryptedTextNonce!,
        mac: entry.encryptedTextMac!,
        version: entry.encryptionVersion,
      ),
      keyBytes: key,
      userId: userId,
    );
  }

  Future<List<int>> _requiredLegacyV1Key(String userId) async =>
      await _keyStore.read(userId) ??
      (throw const MyWhyLegacyUnrecoverableException());

  Future<List<int>> _v2KeyForWrite(String userId) =>
      _recoveryKeys.recoverOrCreate(userId);

  Future<MyWhyEntry?> _prepareForV2Write(
    String userId, {
    required bool startFreshIfLegacyUnrecoverable,
  }) async {
    final existing = await _loadEntry(userId);
    if (existing?.isLegacyV1 != true) return existing;
    try {
      return await _migrateLegacyV1Entry(existing!, userId);
    } on MyWhyLegacyUnrecoverableException {
      if (!startFreshIfLegacyUnrecoverable) rethrow;
      return _archiveLegacyAndStartFresh(userId);
    }
  }

  Future<MyWhyEntry> _archiveLegacyAndStartFresh(String userId) async {
    final row = await _supabase.rpc('archive_legacy_my_why_and_start_v2');
    if (row is! Map) {
      throw const MyWhyPartialFailureException(
        'The legacy My Why could not be preserved, so no new content was saved.',
      );
    }
    return MyWhyEntry.fromMap(Map<String, dynamic>.from(row));
  }

  Future<List<int>> _keyForEntry(MyWhyEntry entry, String userId) =>
      entry.isLegacyV1
      ? _requiredLegacyV1Key(userId)
      : _recoveryKeys.recoverOrCreate(userId);

  Future<MyWhyEntry> _migrateLegacyV1Entry(
    MyWhyEntry entry,
    String userId,
  ) async {
    final legacyKey = await _requiredLegacyV1Key(userId);
    final recoveredKey = await _recoveryKeys.registerLegacyKey(
      userId,
      legacyKey,
    );
    final uploadedPaths = <String>[];
    try {
      final values = <String, dynamic>{
        'encryption_version': MyWhyEncryptionService.currentVersion,
        'updated_at': _now(),
      };
      if (entry.hasText) {
        final clear = await _encryption.decryptText(
          payload: MyWhyEncryptedPayload.fromBase64(
            cipherText: entry.encryptedTextPayload!,
            nonce: entry.encryptedTextNonce!,
            mac: entry.encryptedTextMac!,
            version: entry.encryptionVersion,
          ),
          keyBytes: legacyKey,
          userId: userId,
        );
        final encrypted = await _encryption.encryptText(
          plaintext: clear,
          keyBytes: recoveredKey,
          userId: userId,
        );
        values.addAll({
          'encrypted_text_payload': encrypted.cipherTextBase64,
          'encrypted_text_nonce': encrypted.nonceBase64,
          'encrypted_text_mac': encrypted.macBase64,
        });
      }
      final voice = await _migrateLegacyMedia(
        entry: entry,
        kind: MyWhyMediaKind.voice,
        legacyKey: legacyKey,
        recoveredKey: recoveredKey,
        uploadedPaths: uploadedPaths,
      );
      final video = await _migrateLegacyMedia(
        entry: entry,
        kind: MyWhyMediaKind.video,
        legacyKey: legacyKey,
        recoveredKey: recoveredKey,
        uploadedPaths: uploadedPaths,
      );
      if (voice != null) values.addAll(voice.databaseValues);
      if (video != null) values.addAll(video.databaseValues);
      final updated = await _updateAndReturn(userId, values);
      await _keyStore.delete(userId);
      final oldPaths = [
        if (voice != null) voice.oldPath,
        if (video != null) video.oldPath,
      ];
      if (oldPaths.isNotEmpty) {
        try {
          await _supabase.storage.from(bucket).remove(oldPaths);
        } catch (_) {
          // The V2 database record is authoritative; orphan cleanup is safe to retry later.
        }
      }
      return updated;
    } catch (_) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from(bucket).remove(uploadedPaths);
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<_MigratedMyWhyMedia?> _migrateLegacyMedia({
    required MyWhyEntry entry,
    required MyWhyMediaKind kind,
    required List<int> legacyKey,
    required List<int> recoveredKey,
    required List<String> uploadedPaths,
  }) async {
    final path = kind == MyWhyMediaKind.voice
        ? entry.voiceStoragePath
        : entry.videoStoragePath;
    if (path == null) return null;
    final nonce = kind == MyWhyMediaKind.voice
        ? entry.voiceEncryptionNonce
        : entry.videoEncryptionNonce;
    final mac = kind == MyWhyMediaKind.voice
        ? entry.voiceEncryptionMac
        : entry.videoEncryptionMac;
    final metadata = kind == MyWhyMediaKind.voice
        ? entry.voiceMetadata
        : entry.videoMetadata;
    if (nonce == null || mac == null || metadata == null) {
      throw const MyWhyValidationException(
        'Legacy private media is incomplete.',
      );
    }
    final purpose = kind.name;
    final legacyCipherText = await _supabase.storage
        .from(bucket)
        .download(path);
    final clear = await _encryption.decryptBytes(
      payload: MyWhyEncryptedPayload.fromBase64(
        cipherText: base64Encode(legacyCipherText),
        nonce: nonce,
        mac: mac,
        version: entry.encryptionVersion,
      ),
      keyBytes: legacyKey,
      userId: entry.userId,
      purpose: purpose,
    );
    final encrypted = await _encryption.encryptBytes(
      plaintext: clear,
      keyBytes: recoveredKey,
      userId: entry.userId,
      purpose: purpose,
    );
    final replacementPath =
        '${entry.userId}/$purpose/${_randomObjectName()}.bin';
    await _supabase.storage
        .from(bucket)
        .uploadBinary(
          replacementPath,
          encrypted.cipherText,
          fileOptions: const FileOptions(
            contentType: 'application/octet-stream',
            cacheControl: '0',
            upsert: false,
          ),
        );
    uploadedPaths.add(replacementPath);
    return _MigratedMyWhyMedia(
      oldPath: path,
      databaseValues: {
        '${kind.name}_storage_path': replacementPath,
        '${kind.name}_encryption_nonce': encrypted.nonceBase64,
        '${kind.name}_encryption_mac': encrypted.macBase64,
        '${kind.name}_metadata': metadata,
      },
    );
  }

  Future<MyWhyEntry> _upsertAndReturn(Map<String, dynamic> values) async {
    final row = await _supabase
        .from('my_why_entries')
        .upsert(values, onConflict: 'user_id')
        .select()
        .single();
    return MyWhyEntry.fromMap(row);
  }

  Future<MyWhyEntry> _updateAndReturn(
    String userId,
    Map<String, dynamic> values,
  ) async {
    final row = await _supabase
        .from('my_why_entries')
        .update(values)
        .eq('user_id', userId)
        .select()
        .single();
    return MyWhyEntry.fromMap(row);
  }

  Future<void> _clearLegacyPlaintext(String userId) => _supabase
      .from('vision_profiles')
      .update({'my_why': null, 'updated_at': _now()})
      .eq('user_id', userId);

  void _validateMedia(MyWhyMediaKind kind, int bytes, Duration duration) {
    final isVoice = kind == MyWhyMediaKind.voice;
    final maxBytes = isVoice ? maxVoiceBytes : maxVideoBytes;
    final maxDuration = isVoice ? maxVoiceDuration : maxVideoDuration;
    if (bytes <= 0) {
      throw const MyWhyValidationException('The recording is empty.');
    }
    if (bytes > maxBytes) {
      throw MyWhyValidationException(
        isVoice
            ? 'Voice recordings must be 20 MB or smaller.'
            : 'Videos must be 100 MB or smaller.',
      );
    }
    if (duration > maxDuration) {
      throw MyWhyValidationException(
        isVoice
            ? 'Voice recordings can be up to 5 minutes.'
            : 'Videos can be up to 2 minutes.',
      );
    }
  }

  String _randomObjectName() {
    final bytes = Uint8List(16);
    final random = Random.secure();
    for (var index = 0; index < bytes.length; index++) {
      bytes[index] = random.nextInt(256);
    }
    return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  String _safeExtension(String value) {
    final normalized = value.toLowerCase().replaceAll('.', '');
    return RegExp(r'^[a-z0-9]{1,5}$').hasMatch(normalized) ? normalized : 'bin';
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) throw const MyWhyAccessException();
    return user;
  }
}

class _MigratedMyWhyMedia {
  final String oldPath;
  final Map<String, dynamic> databaseValues;

  const _MigratedMyWhyMedia({
    required this.oldPath,
    required this.databaseValues,
  });
}

class MyWhyValidationException implements Exception {
  final String message;
  const MyWhyValidationException(this.message);
  @override
  String toString() => message;
}

class MyWhyAccessException implements Exception {
  const MyWhyAccessException();
  @override
  String toString() => 'Sign in to access My Why.';
}

class MyWhyPartialFailureException implements Exception {
  final String message;
  const MyWhyPartialFailureException(this.message);
  @override
  String toString() => message;
}
