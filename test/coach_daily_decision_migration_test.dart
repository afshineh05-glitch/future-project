import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609100001_create_coach_daily_decisions.sql',
  ).readAsStringSync();

  test('schema stores only a minimal canonical daily decision', () {
    expect(sql, contains('primary key (user_id, local_date)'));
    expect(sql, contains("decision in ('planned_session', 'lighter_session')"));
    expect(sql, isNot(contains('heart_rate')));
    expect(sql, isNot(contains('sleep_')));
    expect(sql, isNot(contains('wearable')));
  });

  test('all operations are authenticated and owner-only', () {
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('security invoker'));
  });

  test('upsert changes one row and retains server timestamp ownership', () {
    expect(sql, contains('on conflict (user_id, local_date) do update'));
    expect(sql, contains('updated_at = now()'));
    expect(sql, contains('created_at timestamptz not null default now()'));
  });
}
