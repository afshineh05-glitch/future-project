import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/deals_location_service.dart';
import 'package:future_project/services/grocery_deals_engine.dart';
import 'package:future_project/services/grocery_item_deals_controller.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';
import 'package:future_project/widgets/grocery_list_row.dart';

void main() {
  testWidgets('the whole grocery row is tappable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GroceryListRow(
            title: 'Chicken Breast',
            quantityLabel: 'Need about 1.4 kg',
            selected: false,
            loading: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chicken Breast'));
    expect(taps, 1);
    await tester.tap(find.text('Need about 1.4 kg'));
    expect(taps, 2);
  });

  testWidgets('retailer source link is clickable', (tester) async {
    var opened = false;
    final source = Uri.parse('https://metro.ca/product/chicken');
    await tester.pumpWidget(
      MaterialApp(
        home: GrocerySourceLinkButton(
          source: source,
          onPressed: () => opened = true,
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open retailer source'));
    expect(opened, isTrue);
  });

  test(
    'selects one canonical item with its existing required quantity',
    () async {
      final provider = _Provider();
      final controller = _controller(provider: provider);
      final item = _need('eggs', 900);

      await controller.select(item);

      expect(provider.requests, hasLength(2));
      expect(provider.requests.first.food.foodId, 'eggs');
      expect(provider.requests.first.neededQuantity, 900);
      expect(provider.requests.map((request) => request.pass), [
        GrocerySearchPass.deal,
        GrocerySearchPass.regularPrice,
      ]);
      expect(controller.state.selectedItem, same(item));
    },
  );

  test('does not query when the shopping area is missing', () async {
    final provider = _Provider();
    final controller = _controller(provider: provider, area: null);

    await controller.select(_need('tofu', 500));

    expect(provider.requests, isEmpty);
    expect(
      controller.state.status,
      GroceryItemDealsViewStatus.shoppingAreaRequired,
    );
  });

  test('duplicate clicks share the in-flight item search', () async {
    final provider = _Provider()..gate = Completer<List<GrocerySearchResult>>();
    final controller = _controller(provider: provider);
    final item = _need('eggs', 900);

    final first = controller.select(item);
    final second = controller.select(item);
    expect(identical(first, second), isTrue);
    await Future<void>.delayed(Duration.zero);
    expect(provider.requests, hasLength(1));
    provider.gates.single.complete(const []);
    await first;
  });

  test('stale results are ignored after selecting another item', () async {
    final provider = _Provider();
    provider.gates.add(Completer<List<GrocerySearchResult>>());
    final controller = _controller(provider: provider);
    final eggs = _need('eggs', 900);
    final tofu = _need('tofu', 500);

    final first = controller.select(eggs);
    final second = controller.select(tofu);
    expect(controller.state.selectedItem, same(tofu));
    provider.gates[0].complete(const []);
    await first;
    await second;
    expect(controller.state.selectedItem, same(tofu));
    expect(controller.state.outcome, isNotNull);
  });

  test('results are ignored after the signed-in account changes', () async {
    final provider = _Provider();
    provider.gates.add(Completer<List<GrocerySearchResult>>());
    final location = _Location(
      const UserShoppingArea(postalCode: 'M5V 2T6', radiusKm: 15),
    );
    final controller = GroceryItemDealsController(
      locationService: location,
      expectedUserId: 'test-user',
      engine: GroceryDealsEngine(locationService: location, provider: provider),
    );
    final pending = controller.select(_need('eggs', 900));
    await Future<void>.delayed(Duration.zero);
    location.userId = 'other-user';
    controller.invalidate();
    provider.gates.single.complete(const []);
    await pending;
    expect(controller.state.status, GroceryItemDealsViewStatus.idle);
  });

  test('loading, empty, and error states are deterministic', () async {
    final provider = _Provider()..gate = Completer<List<GrocerySearchResult>>();
    final controller = _controller(provider: provider);
    final item = _need('eggs', 900);
    final pending = controller.select(item);
    expect(controller.state.status, GroceryItemDealsViewStatus.loading);
    provider.gate!.complete(const []);
    await pending;
    expect(controller.state.status, GroceryItemDealsViewStatus.empty);

    final resultsProvider = _Provider()
      ..results = [_result(pass: GrocerySearchPass.deal)];
    final resultsController = _controller(provider: resultsProvider);
    await resultsController.select(item);
    expect(resultsController.state.status, GroceryItemDealsViewStatus.results);

    final failing = _Provider()..error = StateError('offline');
    final failedController = _controller(provider: failing);
    await failedController.select(item);
    expect(failedController.state.status, GroceryItemDealsViewStatus.error);
  });

  test('multi-item search deduplicates and enforces five-item pages', () async {
    final provider = _Provider();
    final controller = _controller(provider: provider);
    final items = [
      _need('eggs', 900),
      _need('tofu', 500),
      _need('brown_rice', 1000),
      _need('chickpeas', 700),
      _need('olive_oil', 500),
      _need('milk', 1000),
      _need('cheese', 400),
      _need('eggs', 600),
    ];

    await controller.searchAll(items);

    expect(controller.state.totalItemCount, 7);
    expect(controller.state.searchedItemCount, 5);
    expect(controller.state.hasMore, isTrue);
    expect(provider.requests, hasLength(10));
    expect(provider.requests.map((request) => request.food.foodId).toSet(), {
      'eggs',
      'tofu',
      'brown_rice',
      'chickpeas',
      'olive_oil',
    });

    await controller.loadMore();
    expect(controller.state.searchedItemCount, 7);
    expect(controller.state.hasMore, isFalse);
    expect(provider.requests, hasLength(14));
  });

  test('unchanged multi-item search reuses recent results', () async {
    final provider = _Provider();
    final controller = _controller(provider: provider);
    final items = [_need('eggs', 900), _need('tofu', 500)];

    await controller.searchAll(items);
    final initialRequests = provider.requests.length;
    await controller.searchAll(items);

    expect(provider.requests, hasLength(initialRequests));
  });

  test('one failed grocery item preserves valid results for another', () async {
    final provider = _CallbackProvider((request) {
      if (request.food.foodId == 'turkey') throw StateError('offline');
      if (request.pass == GrocerySearchPass.deal) return const [];
      return [_resultForRequest(request)];
    });
    final controller = _controller(provider: provider);

    await controller.searchAll([
      _need('turkey', 900),
      _need('chicken_breast', 1000),
    ]);

    expect(controller.state.status, GroceryItemDealsViewStatus.results);
    expect(controller.state.outcome!.providerFailed, isTrue);
    expect(
      controller.state.outcome!.onlineRecommendations.single.foodId,
      'chicken_breast',
    );
  });

  test('focused item does not suppress the automatic collection', () async {
    final provider = _CallbackProvider((request) {
      if (request.pass == GrocerySearchPass.deal) return const [];
      return [_resultForRequest(request)];
    });
    final controller = _controller(provider: provider);
    final items = [_need('eggs', 900), _need('brown_rice', 1000)];

    await controller.searchAll(items);
    final requestsBeforeFocus = provider.requests.length;
    final outcomeBeforeFocus = controller.state.outcome;
    await controller.select(items.first);

    expect(controller.state.isBatch, isTrue);
    expect(controller.state.selectedItem, same(items.first));
    expect(controller.state.requestedItems, items);
    expect(controller.state.outcome, same(outcomeBeforeFocus));
    expect(controller.state.outcome!.onlineRecommendations, hasLength(2));
    expect(provider.requests, hasLength(requestsBeforeFocus));
  });

  test(
    'changing shopping area invalidates location-scoped cached results',
    () async {
      final location = _Location(
        const UserShoppingArea(postalCode: 'H2X 1Y4', radiusKm: 15),
      );
      final provider = _CallbackProvider((request) => const []);
      final controller = GroceryItemDealsController(
        locationService: location,
        expectedUserId: 'test-user',
        engine: GroceryDealsEngine(
          locationService: location,
          provider: provider,
        ),
      );
      final items = [_need('eggs', 900)];

      await controller.searchAll(items);
      final firstRequestCount = provider.requests.length;
      location.area = const UserShoppingArea(
        postalCode: 'K1P 1J1',
        radiusKm: 15,
      );
      controller.invalidate();
      await controller.searchAll(items);

      expect(provider.requests, hasLength(firstRequestCount * 2));
      expect(provider.requests.last.shoppingArea.postalCode, 'K1P 1J1');
      expect(controller.state.shoppingArea!.postalCode, 'K1P 1J1');
    },
  );
}

GroceryItemDealsController _controller({
  required GrocerySearchProvider provider,
  UserShoppingArea? area = const UserShoppingArea(
    postalCode: 'M5V 2T6',
    radiusKm: 15,
  ),
}) {
  final location = _Location(area);
  return GroceryItemDealsController(
    locationService: location,
    expectedUserId: 'test-user',
    engine: GroceryDealsEngine(
      locationService: location,
      provider: provider,
      now: () => DateTime.utc(2026, 9, 17),
    ),
  );
}

WeeklyFoodRequirement _need(String key, double purchaseGrams) {
  final food = FridgeFoodCatalog.foods.firstWhere((item) => item.key == key);
  return WeeklyFoodRequirement(
    food: food,
    suggestedGrams: purchaseGrams,
    inFridgeGrams: 0,
  );
}

class _Location implements DealsLocationService {
  UserShoppingArea? area;
  String userId = 'test-user';
  _Location(this.area);

  @override
  String? get authenticatedUserId => userId;

  @override
  Future<UserShoppingArea?> currentShoppingArea() async => area;

  @override
  Future<UserShoppingArea> saveShoppingArea({
    required String postalCode,
    required double radiusKm,
  }) => throw UnsupportedError('not used');
}

class _Provider implements GrocerySearchProvider {
  final List<GrocerySearchRequest> requests = [];
  final List<Completer<List<GrocerySearchResult>>> gates = [];
  Completer<List<GrocerySearchResult>>? gate;
  List<GrocerySearchResult> results = const [];
  Object? error;

  @override
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request) {
    requests.add(request);
    if (error != null) return Future.error(error!);
    if (gate != null) {
      final current = gate!;
      gate = null;
      gates.add(current);
      return current.future;
    }
    return Future.value(results);
  }
}

class _CallbackProvider implements GrocerySearchProvider {
  final List<GrocerySearchRequest> requests = [];
  final List<GrocerySearchResult> Function(GrocerySearchRequest) callback;
  _CallbackProvider(this.callback);

  @override
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request) async {
    requests.add(request);
    return callback(request);
  }
}

GrocerySearchResult _resultForRequest(GrocerySearchRequest request) =>
    GrocerySearchResult(
      id: '${request.food.foodId}-${request.pass.name}',
      productName: request.food.canonicalName,
      storeName: 'Online Store',
      storeLocation: const StoreLocation(),
      price: 8,
      currency: 'CAD',
      priceKind: GroceryPriceKind.regular,
      sourceUri: Uri.parse(
        'https://retailer.example/product/${request.food.foodId}',
      ),
      sourceName: 'retailer.example',
      verifiedAt: DateTime.utc(2026, 9, 17),
    );

GrocerySearchResult _result({required GrocerySearchPass pass}) =>
    GrocerySearchResult(
      id: 'verified',
      productName: 'Fresh Eggs',
      storeName: 'Local Store',
      storeLocation: const StoreLocation(postalCode: 'M5V 1A1'),
      price: 5,
      currency: 'CAD',
      priceKind: pass == GrocerySearchPass.deal
          ? GroceryPriceKind.sale
          : GroceryPriceKind.regular,
      regularPrice: pass == GrocerySearchPass.deal ? 7 : null,
      packageQuantity: 12,
      packageUnitType: FoodUnitType.count,
      providerDistanceKm: 2,
      sourceUri: Uri.parse('https://retailer.example/eggs'),
      sourceName: 'retailer.example',
      verifiedAt: DateTime.utc(2026, 9, 17),
      availabilityVerified: true,
      dealVerified: pass == GrocerySearchPass.deal,
      locationVerified: true,
      onlineOnly: false,
      saleEvidence: pass == GrocerySearchPass.deal,
      radiusKm: 15,
      validUntil: pass == GrocerySearchPass.deal
          ? DateTime.utc(2026, 9, 18)
          : null,
    );
