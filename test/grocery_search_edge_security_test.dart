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
    expect(source, contains('Deno.env.get("SERPER_API_KEY")'));
    expect(source, contains('Deno.env.get("GOOGLE_MAPS_API_KEY")'));
    expect(source, contains('"X-API-KEY": apiKey'));
    for (final file in Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      final dart = file.readAsStringSync();
      expect(dart, isNot(contains('SERPER_API_KEY')), reason: file.path);
      expect(dart, isNot(contains('GOOGLE_MAPS_API_KEY')), reason: file.path);
    }
  });

  test('Serper queries are Canada-localized and domain restricted', () {
    expect(source, contains('https://google.serper.dev/search'));
    expect(source, contains('retailerDomains.map'));
    expect(source, contains(r'`site:${domain}`'));
    expect(source, contains('Montreal Quebec Canada'));
    expect(source, contains('location: "Montreal, Quebec, Canada"'));
    expect(source, contains('payload.organic'));
  });

  test('untrusted discovery results require explicit commerce evidence', () {
    expect(source, contains('explicitPrice(evidence)'));
    expect(source, contains('explicitRegularPrice(evidence)'));
    expect(source, contains('explicitPackage(evidence)'));
    expect(source, contains('explicitPostal(evidence)'));
    expect(source, contains('explicitValidUntil(evidence)'));
    expect(source, contains('availabilityVerified'));
    expect(source, contains('distanceKm > radius'));
  });
}
