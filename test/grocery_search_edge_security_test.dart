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
    expect(source, contains(r'https://google.serper.dev/${path}'));
    expect(source, contains('const shoppingPayload = await serperRequest('));
    expect(source, contains('"shopping",'));
    expect(source, contains('shoppingPayload.shopping'));
    expect(source, contains(r'`${terms[0]} Montreal Canada`'));
    expect(source, contains('retailerDomains.map'));
    expect(source, contains(r'`site:${domain}`'));
    expect(source, contains('Montreal Quebec Canada'));
    expect(source, contains('location: "Montreal, Quebec, Canada"'));
    expect(source, contains('fallbackPayload.organic'));
    expect(source, contains('if (results.length === 0)'));
  });

  test('nearby deals retain the strict general-search path', () {
    expect(source, contains('if (pass === "regularPrice")'));
    expect(
      source,
      contains(
        'const dealPayload = await serperRequest("search", query, "deal")',
      ),
    );
    expect(source, contains('rejectionReasons(evidence, pass, terms)'));
    expect(source, contains('candidateDistance <= radius'));
    expect(source, contains('const blockingReasons = pass === "deal"'));
    expect(source, contains('? reasons'));
    expect(source, contains('if (pass === "deal" && distanceKm == null)'));
    expect(source, contains('dealVerified: pass === "deal"'));
    expect(source, contains('locationVerified: distanceKm != null'));
  });

  test('untrusted discovery results require explicit commerce evidence', () {
    expect(source, contains('parseRetailerPage(html)'));
    expect(source, contains('rejectionReasons(evidence, pass, terms)'));
    expect(source, contains('candidateDistance <= radius'));
    expect(source, contains('onlineOnly'));
  });

  test('retailer page fetching is bounded and SSRF defensive', () {
    expect(source, contains('PAGE_MAX_FETCHES'));
    expect(source, contains('PAGE_MAX_BYTES'));
    expect(source, contains('PAGE_TIMEOUT_MS'));
    expect(source, contains('redirect: "manual"'));
    expect(source, contains('Deno.resolveDns'));
    expect(source, contains('isPrivateOrReservedIp'));
    expect(source, contains('!url.port'));
    expect(source, contains('unsupported_content_type'));
    expect(source, contains('response_too_large'));
    expect(source, contains('unsafe_redirect'));
  });

  test('page evidence and aggregate rejection diagnostics remain safe', () {
    expect(source, contains('parseRetailerPage(html)'));
    expect(source, contains('rejectionReasons(evidence, pass, terms)'));
    expect(source, contains('fetchedPages,'));
    expect(source, contains('onlineOnly.missing_location'));
    expect(source, contains('onlineOnly.missing_package'));
    expect(source, contains('onlineOnly.missing_availability'));
    expect(source, contains('onlineOnly.outside_radius'));
    expect(source, contains('shoppingHttpStatus'));
    expect(source, contains('shoppingResultsReceived'));
    expect(source, contains('shoppingResultsWithParsedCadPrice'));
    expect(source, contains('shoppingResultsWithOffers'));
    expect(source, contains('shoppingOfferFieldNames'));
    expect(source, contains('organicFallbackRequested'));
    expect(source, contains('MAX_MERCHANT_RESOLUTIONS'));
    expect(source, contains(r'`site:${candidate.domain} "${title}"`'));
    expect(source, contains('merchantResolutionAttempted'));
    expect(source, contains('merchantResolutionSucceeded'));
    expect(source, contains('merchantResolutionRejected'));
    expect(source, contains('acceptedShopping'));
    expect(source, contains('shopping_provider_http_error'));
    expect(source, contains('duplicate'));
    expect(source, isNot(contains('SERPER_API_KEY:')));
    expect(
      File('supabase/functions/grocery-search/logic.ts').existsSync(),
      isTrue,
    );
    expect(
      File('supabase/functions/grocery-search/logic_test.ts').existsSync(),
      isTrue,
    );
  });
}
