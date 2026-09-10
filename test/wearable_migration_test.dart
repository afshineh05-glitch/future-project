import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609090001_create_wearable_daily_records.sql',
  ).readAsStringSync();

  test('wearable daily schema is owner-only and idempotent', () {
    expect(sql, contains('primary key (user_id, local_date)'));
    expect(sql, contains('enable row level security'));
    expect(sql, contains('for select to authenticated'));
    expect(sql, contains('for insert to authenticated'));
    expect(sql, contains('for update to authenticated'));
    expect(sql, contains('for delete to authenticated'));
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('security invoker'));
  });

  test('sync preserves absent metrics and rejects stale replacement', () {
    expect(sql, contains('on conflict (user_id, local_date) do update'));
    expect(sql, contains('coalesce(excluded.steps'));
    expect(
      sql,
      contains(
        'where excluded.source_updated_at >= wearable_daily_records.source_updated_at',
      ),
    );
  });
}
