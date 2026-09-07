import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/my_why_entry.dart';

void main() {
  test('voice history schema is owner-only and stores encrypted envelopes', () {
    final sql = File(
      'supabase/migrations/202609040001_add_my_why_voice_history_v1.sql',
    ).readAsStringSync();

    expect(
      sql,
      contains('create table if not exists public.my_why_voice_recordings'),
    );
    expect(sql, contains('entry_id uuid not null'));
    expect(sql, contains('user_id uuid not null'));
    expect(sql, contains('storage_path text not null unique'));
    expect(sql, contains('encryption_nonce text not null'));
    expect(sql, contains('encryption_mac text not null'));
    expect(sql, contains('encryption_version integer not null'));
    expect(sql, contains('created_at timestamptz not null'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('auth.uid() = user_id'));
    expect(sql, isNot(contains('plaintext')));
  });

  test('voice saves are additive and individual deletes are scoped by id', () {
    final service = File('lib/services/my_why_service.dart').readAsStringSync();
    final addStart = service.indexOf('addVoiceRecording({');
    final playbackStart = service.indexOf('createVoicePlaybackFile(');
    final addVoice = service.substring(addStart, playbackStart);

    expect(addVoice, contains("from('my_why_voice_recordings')"));
    expect(addVoice, contains('.insert({'));
    expect(addVoice, isNot(contains("'voice_storage_path': path")));
    expect(addVoice, isNot(contains('final previous')));
    expect(service, contains(".eq('id', recording.id)"));
    expect(service, contains(".eq('user_id', user.id)"));
  });

  test('voice UI exposes history, pause, progress, and seek', () {
    final widget = File('lib/widgets/my_why_section.dart').readAsStringSync();

    expect(widget, contains("'Add Voice'"));
    expect(widget, isNot(contains("'Replace Voice'")));
    expect(widget, contains('_voiceRecordings.map(_voiceRecordingCard)'));
    expect(widget, contains('Icons.pause_rounded'));
    expect(widget, contains('Slider('));
    expect(widget, contains('_windowsVoicePlayer?.seek(position)'));
    expect(widget, contains('_audioPlayer?.seek(position)'));
    expect(widget, contains('_activeVoiceId'));
  });

  test('existing single voice maps to a stable legacy history item', () {
    final entry = MyWhyEntry(
      id: 'entry-1',
      userId: 'user-1',
      hasText: false,
      hasVoice: true,
      hasVideo: false,
      encryptedTextPayload: null,
      encryptedTextNonce: null,
      encryptedTextMac: null,
      voiceStoragePath: 'encrypted-object',
      voiceEncryptionNonce: 'nonce',
      voiceEncryptionMac: 'mac',
      voiceMetadata: const {'duration_seconds': 67},
      videoStoragePath: null,
      videoEncryptionNonce: null,
      videoEncryptionMac: null,
      videoMetadata: null,
      encryptionVersion: 2,
      createdAt: DateTime.utc(2026, 9, 1),
      updatedAt: DateTime.utc(2026, 9, 4),
    );

    final recording = MyWhyVoiceRecording.fromLegacyEntry(entry);

    expect(recording.id, 'legacy:entry-1');
    expect(recording.isLegacyEntryVoice, isTrue);
    expect(recording.duration, const Duration(seconds: 67));
    expect(recording.encryptionVersion, 2);
  });
}
