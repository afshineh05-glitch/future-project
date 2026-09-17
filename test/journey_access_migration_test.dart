import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Journey access is server-controlled and owner-scoped', () {
    final sql = File(
      'supabase/migrations/202609150003_create_internal_feature_access_v1.sql',
    ).readAsStringSync();
    expect(sql, contains('internal_feature_access'));
    expect(sql, contains('primary key (user_id, feature_key)'));
    expect(sql, contains('auth.uid()) = user_id'));
    expect(
      sql,
      contains(
        'revoke all on table public.internal_feature_access from public, anon',
      ),
    );
    expect(
      sql,
      contains(
        'grant select on table public.internal_feature_access to authenticated',
      ),
    );
    expect(sql, contains('revoke insert, update, delete'));
    expect(sql, isNot(contains("insert into public.internal_feature_access")));
  });
}
