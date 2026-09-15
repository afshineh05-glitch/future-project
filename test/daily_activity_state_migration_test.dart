import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609150002_create_daily_activity_state_v1.sql',
  ).readAsStringSync();

  test('uses one stable owner/date/activity identity', () {
    expect(
      sql,
      contains('primary key (user_id, local_date, activity_identity)'),
    );
    expect(
      sql,
      contains(
        'on conflict (user_id, local_date, activity_identity) do update',
      ),
    );
    expect(sql, contains('constraint daily_activity_identity_namespace'));
    expect(sql, contains("activity_identity like 'workout:%'"));
  });

  test('retires missing observations without deleting history', () {
    expect(sql, contains('set retired_at = p_synced_at'));
    expect(sql, isNot(contains('delete from public.daily_activity_state')));
    expect(sql, contains('retired_at = null'));
    expect(sql, contains('existing.local_date <> p_local_date'));
  });

  test('is owner-only and RPC is authenticated invoker', () {
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('language plpgsql security invoker'));
    expect(sql, contains('from public, anon'));
    expect(sql, contains('to authenticated'));
  });

  test('does not write authoritative source tables', () {
    for (final source in [
      'workout_sessions',
      'nutrition_food_logs',
      'vision_daily_reflections',
      'coach_weekly_plans',
    ]) {
      expect(sql, isNot(contains('insert into public.$source')));
      expect(sql, isNot(contains('update public.$source')));
    }
  });
}
