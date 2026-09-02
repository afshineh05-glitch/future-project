import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('migration enforces own-row RLS and private own-path storage', () {
    final sql = File(
      'supabase/migrations/202608260002_create_my_why_v1.sql',
    ).readAsStringSync();

    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('auth.uid() = user_id'));
    expect(sql, contains("'my-why-private'"));
    expect(sql, contains('public = false'));
    expect(sql, contains('(storage.foldername(name))[1] = auth.uid()::text'));
    expect(sql, isNot(contains('to service_role')));
  });

  test(
    'client persistence contains ciphertext fields but no plaintext field',
    () {
      final source = File(
        'lib/services/my_why_service.dart',
      ).readAsStringSync();

      expect(source, contains("'encrypted_text_payload'"));
      expect(source, contains('encryptText('));
      expect(source, isNot(contains("'plaintext_text'")));
      expect(source, isNot(contains('createSignedUrl')));
      expect(source, isNot(contains('serviceRole')));
    },
  );

  test('legacy plaintext is cleared only after encrypted save completes', () {
    final source = File('lib/services/my_why_service.dart').readAsStringSync();
    final saveIndex = source.indexOf('entry = await saveText(legacy);');
    final clearIndex = source.indexOf('await _clearLegacyPlaintext(user.id);');

    expect(saveIndex, greaterThan(-1));
    expect(clearIndex, greaterThan(saveIndex));
  });

  test('My Why is not wired into coach services or prompts', () {
    final coachSources = [
      File('lib/services/adaptive_training_service.dart').readAsStringSync(),
      File('lib/services/future_vision_service.dart').readAsStringSync(),
    ].join('\n').toLowerCase();

    expect(coachSources, isNot(contains('my_why_entries')));
    expect(coachSources, isNot(contains('encrypted_text_payload')));
  });

  test(
    'V2 keeps raw recovery keys out of Postgres and allows only own envelopes',
    () {
      final sql = File(
        'supabase/migrations/202609010001_add_my_why_recovery_v2.sql',
      ).readAsStringSync();

      expect(sql, contains('my_why_key_envelopes'));
      expect(sql, contains('wrapped_key_ciphertext'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('auth.uid() = user_id'));
      expect(sql, isNot(contains('raw_encryption_key')));
    },
  );

  test(
    'unrecoverable V1 is archived intact before the active row becomes V2',
    () {
      final sql = File(
        'supabase/migrations/202609010002_archive_unrecoverable_my_why_v1.sql',
      ).readAsStringSync();

      expect(sql, contains('my_why_legacy_archives'));
      expect(sql, contains('source_entry_id uuid not null unique'));
      expect(sql, contains('security definer'));
      expect(sql, contains('auth.uid()'));
      expect(sql, contains('legacy.encrypted_text_payload'));
      expect(sql, contains('legacy.voice_storage_path'));
      expect(sql, contains('legacy.video_storage_path'));
      expect(sql, contains('encryption_version = 2'));
      expect(sql, contains('enable row level security'));
      expect(sql, contains('auth.uid() = user_id'));
      expect(sql, isNot(contains('for delete to authenticated')));
      expect(sql, isNot(contains('for update to authenticated')));
    },
  );

  test('fresh V2 writes require the explicit unrecoverable-legacy path', () {
    final service = File('lib/services/my_why_service.dart').readAsStringSync();
    final widget = File('lib/widgets/my_why_section.dart').readAsStringSync();

    expect(service, contains('startFreshIfLegacyUnrecoverable = false'));
    expect(service, contains("rpc('archive_legacy_my_why_and_start_v2')"));
    expect(service, contains('on MyWhyLegacyUnrecoverableException'));
    expect(widget, contains('state.hasUnrecoverableLegacy'));
    expect(
      widget,
      contains('startFreshIfLegacyUnrecoverable: _hasUnrecoverableLegacy'),
    );
  });
}
