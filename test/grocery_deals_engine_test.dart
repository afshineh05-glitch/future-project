import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/deals_location_service.dart';
import 'package:future_project/services/food_search_catalog.dart';
import 'package:future_project/services/grocery_deals_engine.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';

void main() {
  test('Canadian postal codes validate and normalize safely', () {
    expect(CanadianPostalCode.normalize('h2x1y4'), 'H2X 1Y4');
    expect(CanadianPostalCode.isValid('H2X 1Y4'), isTrue);
    expect(CanadianPostalCode.isValid('D2X 1Y4'), isFalse);
    expect(CanadianPostalCode.isValid('90210'), isFalse);
  });

  test('whitelist accepts canonical food and blocks unrelated searches', () {
    expect(
      FoodSearchCatalog.resolveApprovedTerm('Chicken Breast')?.foodId,
      'chicken_breast',
    );
    expect(FoodSearchCatalog.resolveApprovedTerm('BMW X5'), isNull);
    expect(
      FoodSearchCatalog.resolveApprovedTerm('unrecognized product'),
      isNull,
    );
  });

  test('missing quantity is requirement minus fridge inventory', () {
    final requirement = WeeklyFoodRequirement(
      food: _food('chicken_breast'),
      suggestedGrams: 2000,
      inFridgeGrams: 600,
    );
    expect(requirement.purchaseGrams, 1400);
  });

  test('location radius keeps a store outside the nearby tier', () async {
    final provider = _Provider(
      (request) => [
        _result('far', pass: request.pass, postalCode: 'M5V 1A1', distance: 16),
      ],
    );
    final outcome = await _engine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.regularPricesFound);
    expect(outcome.nearbyRecommendations, isEmpty);
    expect(outcome.onlineRecommendations.single.isVerifiedNearby, isFalse);
  });

  test('deal pass executes first and prevents regular-price pass', () async {
    final provider = _Provider(
      (request) => [
        _result('deal', pass: request.pass, postalCode: 'M5V 1A1', distance: 2),
      ],
    );
    final outcome = await _engine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.dealsFound);
    expect(provider.passes, [GrocerySearchPass.deal]);
  });

  test('regular-price fallback runs only when no valid deal exists', () async {
    final provider = _Provider(
      (request) => request.pass == GrocerySearchPass.deal
          ? const []
          : [
              _result(
                'regular',
                pass: request.pass,
                postalCode: 'M5V 1A1',
                distance: 3,
              ),
            ],
    );
    final outcome = await _engine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.regularPricesFound);
    expect(provider.passes, [
      GrocerySearchPass.deal,
      GrocerySearchPass.regularPrice,
    ]);
    expect(outcome.recommendations.single.isDeal, isFalse);
  });

  test(
    'verified online regular prices survive without store postal evidence',
    () async {
      final provider = _Provider(
        (request) => request.pass == GrocerySearchPass.deal
            ? const []
            : [
                _result(
                  'online-regular',
                  pass: request.pass,
                  postalCode: null,
                  distance: null,
                ),
              ],
      );
      final outcome = await _engine(provider).findPrices([_need()]);

      expect(outcome.status, DealsResultStatus.regularPricesFound);
      expect(outcome.nearbyRecommendations, isEmpty);
      expect(outcome.onlineRecommendations, hasLength(1));
      expect(outcome.onlineRecommendations.single.distanceKm, isNull);
      expect(outcome.onlineRecommendations.single.isVerifiedNearby, isFalse);
    },
  );

  test('online-only sale falls back to a regular price', () async {
    final provider = _Provider(
      (request) => request.pass == GrocerySearchPass.deal
          ? [
              _result(
                'online-deal',
                pass: request.pass,
                postalCode: null,
                distance: null,
              ),
            ]
          : [
              _result(
                'regular-fallback',
                pass: request.pass,
                postalCode: null,
                distance: null,
              ),
            ],
    );
    final outcome = await _engine(provider).findPrices([_need()]);

    expect(outcome.status, DealsResultStatus.regularPricesFound);
    expect(outcome.onlineRecommendations.single.isDeal, isFalse);
    expect(outcome.nearbyRecommendations, isEmpty);
    expect(provider.passes, [
      GrocerySearchPass.deal,
      GrocerySearchPass.regularPrice,
    ]);
  });

  test('price normalization calculates comparable mass and volume prices', () {
    expect(
      PriceNormalizer.perCanonicalUnit(
        price: 10,
        packageQuantity: 500,
        packageUnitType: FoodUnitType.mass,
        foodUnitType: FoodUnitType.mass,
      ),
      20,
    );
    expect(
      PriceNormalizer.perCanonicalUnit(
        price: 4,
        packageQuantity: 2000,
        packageUnitType: FoodUnitType.volume,
        foodUnitType: FoodUnitType.volume,
      ),
      2,
    );
    expect(
      PriceNormalizer.perCanonicalUnit(
        price: 4,
        packageQuantity: null,
        packageUnitType: null,
        foodUnitType: FoodUnitType.mass,
      ),
      isNull,
    );
  });

  test(
    'package fit can rank a useful package above an oversized package',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            'oversized',
            pass: request.pass,
            postalCode: 'M5V 1A1',
            distance: 2,
            price: 20,
            packageQuantity: 4000,
          ),
          _result(
            'fitted',
            pass: request.pass,
            postalCode: 'M5V 1A1',
            distance: 2,
            price: 12,
            packageQuantity: 1500,
          ),
        ],
      );
      final outcome = await _engine(provider).findPrices([_need()]);
      expect(outcome.recommendations.first.result.id, 'fitted');
    },
  );

  test(
    'unrelated products are rejected even when provider returns them',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            'car',
            pass: request.pass,
            postalCode: 'M5V 1A1',
            distance: 2,
            productName: 'BMW X5',
          ),
        ],
      );
      final outcome = await _engine(provider).findPrices([_need()]);
      expect(outcome.status, DealsResultStatus.noReliablePrice);
    },
  );

  test('unavailable location requests shopping-area configuration', () async {
    final provider = _Provider((_) => throw StateError('must not search'));
    final engine = GroceryDealsEngine(
      locationService: const FixedDealsLocationService(null),
      provider: provider,
    );
    final outcome = await engine.findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.shoppingAreaRequired);
    expect(provider.passes, isEmpty);
  });

  test('provider failure is contained and regular pass is attempted', () async {
    final provider = _Provider((_) => throw StateError('provider unavailable'));
    final outcome = await _engine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.noReliablePrice);
    expect(outcome.providerFailed, isTrue);
    expect(provider.passes, [
      GrocerySearchPass.deal,
      GrocerySearchPass.regularPrice,
    ]);
  });

  test(
    'stale, non-CAD, and sponsored results are rejected while unverified stays online',
    () async {
      final bad = [
        _result(
          'stale',
          pass: GrocerySearchPass.deal,
          postalCode: 'M5V 1A1',
          distance: 2,
          verifiedAt: DateTime.utc(2026, 9, 14),
        ),
        _result(
          'unverified',
          pass: GrocerySearchPass.deal,
          postalCode: 'M5V 1A1',
          distance: 2,
          availabilityVerified: false,
        ),
        _result(
          'usd',
          pass: GrocerySearchPass.deal,
          postalCode: 'M5V 1A1',
          distance: 2,
          currency: 'USD',
        ),
        _result(
          'sponsored',
          pass: GrocerySearchPass.deal,
          postalCode: 'M5V 1A1',
          distance: 2,
          sponsoredOnly: true,
        ),
      ];
      final provider = _Provider(
        (request) => request.pass == GrocerySearchPass.deal ? bad : const [],
      );
      final outcome = await _engine(provider).findPrices([_need()]);
      expect(outcome.status, DealsResultStatus.dealsFound);
      expect(outcome.nearbyRecommendations.single.result.id, 'unverified');
    },
  );

  test(
    'results without explicit package evidence remain online-only',
    () async {
      final provider = _Provider(
        (request) => [
          GrocerySearchResult(
            id: 'missing-package',
            productName: 'Fresh Chicken Breast',
            storeName: 'Local Store',
            storeLocation: const StoreLocation(postalCode: 'M5V 1A1'),
            price: 10,
            currency: 'CAD',
            priceKind: request.pass == GrocerySearchPass.deal
                ? GroceryPriceKind.sale
                : GroceryPriceKind.regular,
            regularPrice: request.pass == GrocerySearchPass.deal ? 15 : null,
            validUntil: request.pass == GrocerySearchPass.deal
                ? DateTime.utc(2026, 9, 18)
                : null,
            providerDistanceKm: 2,
            sourceUri: Uri.parse('https://retailer.example/chicken'),
            sourceName: 'retailer.example',
            verifiedAt: DateTime.utc(2026, 9, 17),
            availabilityVerified: true,
            dealVerified: request.pass == GrocerySearchPass.deal,
            locationVerified: true,
            onlineOnly: false,
            saleEvidence: request.pass == GrocerySearchPass.deal,
            radiusKm: 15,
          ),
        ],
      );

      final outcome = await _engine(provider).findPrices([_need()]);

      expect(outcome.status, DealsResultStatus.dealsFound);
      expect(outcome.nearbyRecommendations.single.normalizedPrice, isNull);
    },
  );

  test('duplicate concurrent searches share one provider operation', () async {
    final gate = Completer<List<GrocerySearchResult>>();
    final provider = _AsyncProvider((_) => gate.future);
    final engine = _engine(provider);
    final coordinator = DealsSearchCoordinator();
    final first = coordinator.search(
      userId: 'test-user',
      engine: engine,
      groceryList: [_need()],
    );
    final second = coordinator.search(
      userId: 'test-user',
      engine: engine,
      groceryList: [_need()],
    );
    expect(identical(first, second), isTrue);
    gate.complete([
      _result(
        'deal',
        pass: GrocerySearchPass.deal,
        postalCode: 'M5V 1A1',
        distance: 2,
      ),
    ]);
    await first;
    expect(provider.calls, 1);
  });

  test('shopping area from another account is never used', () async {
    final provider = _Provider((_) => throw StateError('must not search'));
    final engine = GroceryDealsEngine(
      locationService: const FixedDealsLocationService(
        UserShoppingArea(ownerUserId: 'other-user', postalCode: 'M5V 2T6'),
        userId: 'current-user',
      ),
      provider: provider,
    );
    final outcome = await engine.findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.shoppingAreaRequired);
    expect(provider.passes, isEmpty);
  });

  test('deal-pass results must actually be valid sale prices', () async {
    final provider = _Provider(
      (request) => [
        GrocerySearchResult(
          id: 'mislabelled',
          productName: 'Chicken Breast',
          storeName: 'Local Store',
          storeLocation: const StoreLocation(postalCode: 'M5V 1A1'),
          price: 10,
          currency: 'CAD',
          priceKind: GroceryPriceKind.regular,
          packageQuantity: 1500,
          packageUnitType: FoodUnitType.mass,
          providerDistanceKm: 2,
          sourceUri: Uri.parse('https://retailer.example/chicken'),
          sourceName: 'retailer.example',
          verifiedAt: DateTime.utc(2026, 9, 17),
          availabilityVerified: true,
        ),
      ],
    );
    final outcome = await _engine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.regularPricesFound);
    expect(provider.passes.length, 2);
  });

  test(
    'Montreal user with verified Montreal deal accepts Nearby Deal',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            'montreal-deal',
            pass: request.pass,
            postalCode: 'H2X 1Y4',
            distance: 2,
          ),
        ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.nearbyRecommendations.single.result.id, 'montreal-deal');
      expect(outcome.nearbyRecommendations.single.result.dealVerified, isTrue);
      expect(
        outcome.nearbyRecommendations.single.result.locationVerified,
        isTrue,
      );
    },
  );

  test(
    'Montreal user with Toronto deal rejects Nearby Deal and uses regular price',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            request.pass == GrocerySearchPass.deal ? 'toronto-deal' : 'regular',
            pass: request.pass,
            postalCode: request.pass == GrocerySearchPass.deal
                ? 'M5V 1A1'
                : null,
            distance: request.pass == GrocerySearchPass.deal ? 504 : null,
          ),
        ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.nearbyRecommendations, isEmpty);
      expect(outcome.onlineRecommendations.single.result.id, 'regular');
    },
  );

  test(
    'Montreal user with Ottawa deal rejects Nearby Deal and uses regular price',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            request.pass == GrocerySearchPass.deal ? 'ottawa-deal' : 'regular',
            pass: request.pass,
            postalCode: request.pass == GrocerySearchPass.deal
                ? 'K1P 1J1'
                : null,
            distance: request.pass == GrocerySearchPass.deal ? 199 : null,
          ),
        ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.nearbyRecommendations, isEmpty);
      expect(outcome.onlineRecommendations.single.result.id, 'regular');
    },
  );

  test(
    'remote regular price remains online and never becomes Nearby',
    () async {
      final provider = _Provider(
        (request) => request.pass == GrocerySearchPass.deal
            ? const []
            : [
                _result(
                  'ottawa-online',
                  pass: request.pass,
                  postalCode: 'K1P 1J1',
                  distance: null,
                  locationVerified: false,
                ),
              ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.nearbyRecommendations, isEmpty);
      expect(
        outcome.onlineRecommendations.single.tier,
        GroceryResultTier.onlineStore,
      );
      expect(outcome.onlineRecommendations.single.result.id, 'ottawa-online');
    },
  );

  test(
    'sale without location verification falls back to Regular Price',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            request.pass == GrocerySearchPass.deal
                ? 'unlocated-sale'
                : 'regular',
            pass: request.pass,
            postalCode: null,
            distance: null,
          ),
        ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.status, DealsResultStatus.regularPricesFound);
      expect(outcome.onlineRecommendations.single.result.id, 'regular');
    },
  );

  test('local product without explicit sale evidence is not a deal', () async {
    final provider = _Provider(
      (request) => [
        _result(
          request.pass == GrocerySearchPass.deal ? 'ordinary-local' : 'regular',
          pass: request.pass,
          postalCode: 'H2X 1Y4',
          distance: 2,
          saleEvidence: request.pass != GrocerySearchPass.deal,
        ),
      ],
    );
    final outcome = await _montrealEngine(provider).findPrices([_need()]);
    expect(outcome.status, DealsResultStatus.regularPricesFound);
    expect(outcome.nearbyRecommendations, isEmpty);
  });

  test('delivery-only evidence never verifies deal location', () async {
    final provider = _Provider(
      (request) => [
        _result(
          request.pass == GrocerySearchPass.deal ? 'delivery-sale' : 'regular',
          pass: request.pass,
          postalCode: null,
          distance: null,
          availabilityVerified: true,
          locationVerified: false,
        ),
      ],
    );
    final outcome = await _montrealEngine(provider).findPrices([_need()]);
    expect(outcome.nearbyRecommendations, isEmpty);
    expect(outcome.onlineRecommendations.single.result.id, 'regular');
  });

  test('valid sale and reference price calculate savings percentage', () async {
    final provider = _Provider(
      (request) => [
        _result(
          'sale',
          pass: request.pass,
          postalCode: 'H2X 1Y4',
          distance: 1,
          price: 10,
          regularPrice: 16,
        ),
      ],
    );
    final outcome = await _montrealEngine(provider).findPrices([_need()]);
    expect(outcome.nearbyRecommendations.single.discountPercent, 37.5);
  });

  test(
    'sale without reference price remains a deal without fabricated discount',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            'sale-no-reference',
            pass: request.pass,
            postalCode: 'H2X 1Y4',
            distance: 1,
            includeRegularPrice: false,
          ),
        ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.nearbyRecommendations.single.isDeal, isTrue);
      expect(outcome.nearbyRecommendations.single.discountPercent, isNull);
    },
  );

  test(
    'Nearby Deal ranks ahead of Regular Price for the requested item',
    () async {
      final provider = _Provider(
        (request) => request.pass == GrocerySearchPass.deal
            ? [
                _result(
                  'nearby-deal',
                  pass: request.pass,
                  postalCode: 'H2X 1Y4',
                  distance: 2,
                ),
              ]
            : [
                _result(
                  'regular',
                  pass: request.pass,
                  postalCode: null,
                  distance: null,
                ),
              ],
      );
      final outcome = await _montrealEngine(provider).findPrices([_need()]);
      expect(outcome.recommendations.single.result.id, 'nearby-deal');
      expect(provider.passes, [GrocerySearchPass.deal]);
    },
  );

  test(
    '17.5 km offer is not Nearby at 15 km but remains an Online Store Price',
    () async {
      final provider = _Provider(
        (request) => [
          _result(
            'same-product-${request.pass.name}',
            pass: request.pass,
            postalCode: 'H2X 1Y4',
            distance: 17.5,
            productName: 'Fresh Chicken Breast',
          ),
        ],
      );

      final outcome = await _montrealEngine(provider).findPrices([_need()]);

      expect(outcome.nearbyRecommendations, isEmpty);
      expect(outcome.onlineRecommendations, hasLength(1));
      expect(
        outcome.onlineRecommendations.single.tier,
        GroceryResultTier.onlineStore,
      );
      expect(outcome.onlineRecommendations.single.distanceKm, 17.5);
      expect(outcome.onlineRecommendations.single.isDeal, isFalse);
      expect(provider.passes, [
        GrocerySearchPass.deal,
        GrocerySearchPass.regularPrice,
      ]);
    },
  );
}

GroceryDealsEngine _engine(GrocerySearchProvider provider) =>
    GroceryDealsEngine(
      locationService: const FixedDealsLocationService(
        UserShoppingArea(postalCode: 'M5V 2T6', radiusKm: 15),
      ),
      provider: provider,
      now: () => DateTime.utc(2026, 9, 17),
    );

GroceryDealsEngine _montrealEngine(GrocerySearchProvider provider) =>
    GroceryDealsEngine(
      locationService: const FixedDealsLocationService(
        UserShoppingArea(postalCode: 'H2X 1Y4', radiusKm: 15),
      ),
      provider: provider,
      now: () => DateTime.utc(2026, 9, 17),
    );

WeeklyFoodRequirement _need() => WeeklyFoodRequirement(
  food: _food('chicken_breast'),
  suggestedGrams: 2000,
  inFridgeGrams: 600,
);

FridgeFoodReference _food(String key) =>
    FridgeFoodCatalog.foods.firstWhere((food) => food.key == key);

GrocerySearchResult _result(
  String id, {
  required GrocerySearchPass pass,
  required String? postalCode,
  required double? distance,
  String productName = 'Fresh Chicken Breast',
  double price = 10,
  double packageQuantity = 1500,
  String currency = 'CAD',
  DateTime? verifiedAt,
  bool availabilityVerified = true,
  bool sponsoredOnly = false,
  bool? dealVerified,
  bool? locationVerified,
  bool? saleEvidence,
  double? regularPrice,
  bool includeRegularPrice = true,
}) => GrocerySearchResult(
  id: id,
  productName: productName,
  storeName: 'Local Store',
  storeLocation: StoreLocation(postalCode: postalCode),
  price: price,
  currency: currency,
  priceKind: pass == GrocerySearchPass.deal
      ? GroceryPriceKind.sale
      : GroceryPriceKind.regular,
  regularPrice: includeRegularPrice
      ? (regularPrice ?? (pass == GrocerySearchPass.deal ? 15 : null))
      : null,
  packageQuantity: packageQuantity,
  packageUnitType: FoodUnitType.mass,
  providerDistanceKm: distance,
  sourceUri: Uri.parse('https://retailer.example/products/$id'),
  sourceName: 'retailer.example',
  verifiedAt: verifiedAt ?? DateTime.utc(2026, 9, 17),
  availabilityVerified: availabilityVerified,
  sponsoredOnly: sponsoredOnly,
  validUntil: pass == GrocerySearchPass.deal ? DateTime.utc(2026, 9, 18) : null,
  dealVerified: dealVerified ?? pass == GrocerySearchPass.deal,
  locationVerified: locationVerified ?? distance != null,
  onlineOnly: distance == null,
  saleEvidence: saleEvidence ?? pass == GrocerySearchPass.deal,
  radiusKm: 15,
);

class _Provider implements GrocerySearchProvider {
  final List<GrocerySearchPass> passes = [];
  final List<GrocerySearchResult> Function(GrocerySearchRequest) handler;

  _Provider(this.handler);

  @override
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request) async {
    passes.add(request.pass);
    return handler(request);
  }
}

class _AsyncProvider implements GrocerySearchProvider {
  final Future<List<GrocerySearchResult>> Function(GrocerySearchRequest)
  handler;
  int calls = 0;
  _AsyncProvider(this.handler);

  @override
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request) {
    calls++;
    return handler(request);
  }
}
