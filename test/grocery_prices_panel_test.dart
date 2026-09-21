import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/grocery_item_deals_controller.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';
import 'package:future_project/widgets/grocery_prices_panel.dart';

void main() {
  testWidgets('Regular Price card is compact and opens its verified link', (
    tester,
  ) async {
    Uri? opened;
    final source = Uri.parse(
      'https://www.nofrills.ca/en/free-from-boneless-skinless-turkey-breast/p/21124845_KG',
    );
    await _pump(
      tester,
      _resultsState(
        'turkey',
        online: [_recommendation('regular', source: source)],
      ),
      onOpen: (value) => opened = value,
    );

    expect(find.text('Grocery Prices · Turkey Breast'), findsOneWidget);
    expect(find.text('Online Store Prices'), findsOneWidget);
    expect(find.text('No Frills'), findsOneWidget);
    expect(
      find.text('Free From Boneless Skinless Turkey Breast'),
      findsOneWidget,
    );
    expect(find.text(r'$9.70'), findsOneWidget);
    expect(find.text('Regular Price'), findsOneWidget);
    expect(find.text('View at No Frills'), findsOneWidget);
    expect(find.textContaining(source.toString()), findsNothing);
    expect(find.textContaining('not confirmed'), findsNothing);
    expect(find.textContaining('not verified'), findsNothing);

    await tester.tap(find.text('View at No Frills'));
    expect(opened, source);
  });

  testWidgets('Deals Near You is hidden without a verified local deal', (
    tester,
  ) async {
    await _pump(
      tester,
      _resultsState(
        'turkey',
        nearby: [_recommendation('unverified-deal', deal: true, local: false)],
        online: [_recommendation('regular')],
      ),
    );

    expect(find.text('Deals Near You'), findsNothing);
    expect(find.text('Online Store Prices'), findsOneWidget);
  });

  testWidgets('verified nearby deal appears first with supported savings', (
    tester,
  ) async {
    await _pump(
      tester,
      _resultsState(
        'turkey',
        nearby: [
          _recommendation(
            'deal',
            deal: true,
            local: true,
            price: 6.99,
            regularPrice: 8.99,
            discountPercent: 22.25,
          ),
        ],
        online: [_recommendation('regular')],
      ),
    );

    expect(find.text('Deals Near You'), findsOneWidget);
    expect(find.text('Online Store Prices'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Deals Near You')).dy,
      lessThan(tester.getTopLeft(find.text('Online Store Prices')).dy),
    );
    expect(find.text(r'Regular $8.99 · Save $2.00 · 22% off'), findsOneWidget);
    expect(find.text('2.4 km away'), findsOneWidget);
    expect(find.text('View Deal'), findsOneWidget);
  });

  testWidgets('deal without reference price does not fabricate savings', (
    tester,
  ) async {
    await _pump(
      tester,
      _resultsState(
        'turkey',
        nearby: [
          _recommendation('deal', deal: true, local: true, regularPrice: null),
        ],
      ),
    );

    expect(find.text('Deals Near You'), findsOneWidget);
    expect(find.textContaining('Save'), findsNothing);
    expect(find.textContaining('% off'), findsNothing);
    expect(find.textContaining(r'Regular $'), findsNothing);
  });

  testWidgets('selected grocery item updates the header and results', (
    tester,
  ) async {
    await _pump(
      tester,
      _resultsState('turkey', online: [_recommendation('turkey-result')]),
    );
    expect(find.text('Grocery Prices · Turkey Breast'), findsOneWidget);

    await _pump(
      tester,
      _resultsState(
        'chicken_breast',
        online: [
          _recommendation(
            'chicken-result',
            product: 'Boneless Skinless Chicken Breast',
          ),
        ],
      ),
    );
    expect(find.text('Grocery Prices · Chicken Breast'), findsOneWidget);
    expect(find.text('Grocery Prices · Turkey Breast'), findsNothing);
    expect(find.text('Boneless Skinless Chicken Breast'), findsOneWidget);
  });

  testWidgets('multiple grocery items render in their own ingredient groups', (
    tester,
  ) async {
    final chicken = _need('chicken_breast');
    final turkey = _need('turkey');
    await _pump(
      tester,
      GroceryItemDealsState(
        requestedItems: [chicken, turkey],
        shoppingArea: const UserShoppingArea(
          postalCode: 'H2X 1Y4',
          radiusKm: 15,
        ),
        searchedItemCount: 2,
        totalItemCount: 2,
        outcome: GroceryDealsOutcome(
          status: DealsResultStatus.regularPricesFound,
          onlineRecommendations: [
            _recommendation(
              'chicken-result',
              foodId: 'chicken_breast',
              foodName: 'Chicken Breast',
              product: 'Boneless Skinless Chicken Breast',
            ),
            _recommendation(
              'turkey-result',
              foodId: 'turkey',
              foodName: 'Turkey Breast',
              product: 'Fresh Turkey Breast',
            ),
          ],
        ),
      ),
    );

    expect(find.text('Grocery Deals & Prices'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('grocery-price-group-chicken_breast')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('grocery-price-group-turkey')),
      findsOneWidget,
    );
    expect(find.text('Boneless Skinless Chicken Breast'), findsOneWidget);
    expect(find.text('Fresh Turkey Breast'), findsOneWidget);
  });

  testWidgets('loading, empty, and provider failure use consumer copy', (
    tester,
  ) async {
    final selected = _need('turkey');
    await _pump(
      tester,
      GroceryItemDealsState(selectedItem: selected, isLoading: true),
    );
    expect(find.text('Finding prices...'), findsOneWidget);

    await _pump(
      tester,
      GroceryItemDealsState(
        selectedItem: selected,
        outcome: const GroceryDealsOutcome(
          status: DealsResultStatus.noReliablePrice,
        ),
      ),
    );
    expect(find.text('No store prices found yet.'), findsOneWidget);

    await _pump(
      tester,
      GroceryItemDealsState(
        selectedItem: selected,
        error: StateError('Search provider 500'),
      ),
    );
    expect(find.text('Prices are temporarily unavailable.'), findsOneWidget);
    expect(find.textContaining('500'), findsNothing);
    expect(find.textContaining('provider'), findsNothing);
  });
}

Future<void> _pump(
  WidgetTester tester,
  GroceryItemDealsState state, {
  ValueChanged<Uri>? onOpen,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: GroceryPricesPanel(
          state: state,
          onChangeArea: () {},
          onRetry: () {},
          onLoadMore: () {},
          onOpenSource: onOpen ?? (_) {},
        ),
      ),
    ),
  ),
);

GroceryItemDealsState _resultsState(
  String foodKey, {
  List<GroceryRecommendation> nearby = const [],
  List<GroceryRecommendation> online = const [],
}) => GroceryItemDealsState(
  selectedItem: _need(foodKey),
  shoppingArea: const UserShoppingArea(postalCode: 'H2X 1Y4', radiusKm: 15),
  outcome: GroceryDealsOutcome(
    status: nearby.isNotEmpty
        ? DealsResultStatus.dealsFound
        : DealsResultStatus.regularPricesFound,
    nearbyRecommendations: nearby,
    onlineRecommendations: online,
  ),
);

WeeklyFoodRequirement _need(String key) {
  final food = FridgeFoodCatalog.foods.firstWhere((item) => item.key == key);
  return WeeklyFoodRequirement(
    food: food,
    suggestedGrams: 1000,
    inFridgeGrams: 0,
  );
}

GroceryRecommendation _recommendation(
  String id, {
  String foodId = 'turkey',
  String foodName = 'Turkey Breast',
  bool deal = false,
  bool local = false,
  double price = 9.70,
  double? regularPrice,
  double? discountPercent,
  String product = 'Free From Boneless Skinless Turkey Breast',
  Uri? source,
}) => GroceryRecommendation(
  foodId: foodId,
  foodName: foodName,
  neededQuantity: 1000,
  result: GrocerySearchResult(
    id: id,
    productName: product,
    storeName: 'No Frills',
    storeLocation: StoreLocation(postalCode: local ? 'H2X 1Y4' : null),
    price: price,
    currency: 'CAD',
    priceKind: deal ? GroceryPriceKind.sale : GroceryPriceKind.regular,
    regularPrice: regularPrice,
    sourceUri: source ?? Uri.parse('https://www.nofrills.ca/en/product/$id'),
    dealVerified: deal,
    locationVerified: local,
    onlineOnly: !local,
    saleEvidence: deal,
  ),
  distanceKm: local ? 2.4 : null,
  tier: local
      ? GroceryResultTier.verifiedNearby
      : GroceryResultTier.onlineStore,
  normalizedPrice: null,
  discountPercent: discountPercent,
  score: 80,
);
