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
}
