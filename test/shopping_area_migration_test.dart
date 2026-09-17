import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final sql = File(
    'supabase/migrations/202609170001_create_user_shopping_areas_v1.sql',
  ).readAsStringSync().toLowerCase();

  test('shopping areas are owner scoped for every operation', () {
    for (final operation in ['select', 'insert', 'update', 'delete']) {
      expect(sql, contains('for $operation to authenticated'));
    }
    expect(sql, contains('(select auth.uid()) = user_id'));
    expect(sql, contains('user_id uuid primary key'));
  });

  test('migration constrains postal format and safe radii', () {
    expect(sql, contains('radius_km in (2, 5, 10, 15, 25)'));
    expect(sql, contains('abceghjklmnprstvxy'));
    expect(sql, contains('enable row level security'));
  });

  test('search quota is authenticated, atomic, and table-private', () {
    expect(sql, contains('claim_grocery_search_request'));
    expect(sql, contains("interval '5 minutes'"));
    expect(sql, contains('limits.request_count < 20'));
    expect(sql, contains('security definer'));
    expect(sql, contains('set search_path = public, pg_temp'));
    expect(
      sql,
      contains(
        'revoke all on public.grocery_search_rate_limits from anon, authenticated',
      ),
    );
    expect(
      sql,
      contains(
        'grant execute on function public.claim_grocery_search_request() to authenticated',
      ),
    );
  });
}
