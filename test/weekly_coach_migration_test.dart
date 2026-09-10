import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609100002_create_coach_weekly_plans.sql',
  ).readAsStringSync();

  test('one canonical row per user and week with separate weeks supported', () {
    expect(sql, contains('primary key (user_id, week_start)'));
    expect(sql, contains('on conflict (user_id, week_start) do update'));
  });

  test('same-week update is server-owned and action count is capped', () {
    expect(sql, contains('updated_at = now()'));
    expect(sql, contains('jsonb_array_length(action_items) between 1 and 3'));
  });

  test('persistence is authenticated owner-only with deterministic enums', () {
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('security invoker'));
    expect(sql, contains("'partial_improvement'"));
    expect(sql, contains("'insufficient_data'"));
  });

  test('does not duplicate raw wearable or nutrition data', () {
    expect(sql, isNot(contains('sleep_minutes')));
    expect(sql, isNot(contains('heart_rate')));
    expect(sql, isNot(contains('calorie_target')));
  });
}
