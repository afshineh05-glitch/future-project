import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'supabase/functions/grocery-search/index.ts',
  ).readAsStringSync();

  test('requires auth and binds requests to the saved shopping area', () {
    expect(source, contains('supabase.auth.getUser()'));
    expect(source, contains('.from("user_shopping_areas")'));
    expect(source, contains('.eq("user_id", user.id)'));
    expect(source, contains('area.postal_code !== postal'));
    expect(source, contains('area.radius_km'));
  });

  test('enforces server whitelist, request limits, and retailer domains', () {
    expect(source, contains('const foods: Record<string, string[]>'));
    expect(source, contains('claim_grocery_search_request'));
    expect(source, contains('contentLength > 4096'));
    expect(source, contains('neededQuantity > 100000'));
    expect(source, contains('retailerDomains'));
    expect(source, contains('isRetailerUrl(sourceUrl)'));
  });

  test('keeps provider secrets server-side', () {
    expect(source, contains('Deno.env.get("GOOGLE_CSE_API_KEY")'));
    expect(source, contains('Deno.env.get("GOOGLE_CSE_CX")'));
    expect(source, contains('Deno.env.get("GOOGLE_MAPS_API_KEY")'));
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final dart = file.readAsStringSync();
      expect(dart, isNot(contains('GOOGLE_CSE_API_KEY')), reason: file.path);
      expect(dart, isNot(contains('GOOGLE_MAPS_API_KEY')), reason: file.path);
    }
  });
}
