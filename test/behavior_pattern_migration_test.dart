import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609150001_create_behavior_patterns_v1.sql',
  ).readAsStringSync();
  test('deduplicates by owner and stable fingerprint', () {
    expect(sql, contains('primary key (user_id, fingerprint)'));
    expect(sql, contains('on conflict (user_id, fingerprint) do update'));
  });
  test('enforces the 42-day window and retires unsupported patterns', () {
    expect(sql, contains('window_end - window_start = 41'));
    expect(sql, contains('set retired_at = p_learned_at'));
  });
  test('uses authenticated owner RLS and invoker rights', () {
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('security invoker'));
  });
}
