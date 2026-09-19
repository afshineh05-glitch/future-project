import 'dart:math' as math;

import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/deals_location_service.dart';
import 'package:future_project/services/food_search_catalog.dart';

abstract interface class GrocerySearchProvider {
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request);
}

class UnconfiguredGrocerySearchProvider implements GrocerySearchProvider {
  const UnconfiguredGrocerySearchProvider();

  @override
  Future<List<GrocerySearchResult>> search(
    GrocerySearchRequest request,
  ) async => const [];
}

class GroceryDealsEngine {
  final DealsLocationService locationService;
  final GrocerySearchProvider provider;
  final StoreDistanceService distanceService;
  final DateTime Function() now;

  const GroceryDealsEngine({
    required this.locationService,
    required this.provider,
    this.distanceService = const StoreDistanceService(),
    this.now = DateTime.now,
  });

  Future<GroceryDealsOutcome> findPrices(
    List<WeeklyFoodRequirement> groceryList,
  ) async {
    final area = await locationService.currentShoppingArea();
    if (area == null || !area.isUsable) {
      return const GroceryDealsOutcome(
        status: DealsResultStatus.shoppingAreaRequired,
      );
    }
    final userId = locationService.authenticatedUserId;
    if (userId == null ||
        (area.ownerUserId != null && area.ownerUserId != userId)) {
      return const GroceryDealsOutcome(
        status: DealsResultStatus.shoppingAreaRequired,
      );
    }
    final needs = groceryList
        .where((need) => need.purchaseGrams >= 1)
        .map(
          (need) =>
              (need: need, food: FoodSearchCatalog.byFoodId(need.food.key)),
        )
        .where((entry) => entry.food != null)
        .toList(growable: false);
    if (needs.isEmpty) {
      return const GroceryDealsOutcome(
        status: DealsResultStatus.noReliablePrice,
      );
    }

    var failed = false;
    final dealsNearby = <GroceryRecommendation>[];
    final dealsOnline = <GroceryRecommendation>[];
    for (final entry in needs) {
      try {
        final results = await provider.search(
          _request(entry.need, entry.food!, area, GrocerySearchPass.deal),
        );
        final validated = _validateAndRank(
          entry.need,
          entry.food!,
          area,
          results,
          GrocerySearchPass.deal,
        );
        dealsNearby.addAll(validated.where((item) => item.isVerifiedNearby));
        dealsOnline.addAll(validated.where((item) => !item.isVerifiedNearby));
      } catch (_) {
        failed = true;
      }
    }
    if (dealsNearby.isNotEmpty || dealsOnline.isNotEmpty) {
      dealsNearby.sort(_compare);
      dealsOnline.sort(_compare);
      return GroceryDealsOutcome(
        status: DealsResultStatus.dealsFound,
        providerFailed: failed,
        nearbyRecommendations: dealsNearby,
        onlineRecommendations: dealsOnline,
      );
    }

    final regularNearby = <GroceryRecommendation>[];
    final regularOnline = <GroceryRecommendation>[];
    for (final entry in needs) {
      try {
        final results = await provider.search(
          _request(
            entry.need,
            entry.food!,
            area,
            GrocerySearchPass.regularPrice,
          ),
        );
        final validated = _validateAndRank(
          entry.need,
          entry.food!,
          area,
          results,
          GrocerySearchPass.regularPrice,
        );
        regularNearby.addAll(validated.where((item) => item.isVerifiedNearby));
        regularOnline.addAll(validated.where((item) => !item.isVerifiedNearby));
      } catch (_) {
        failed = true;
      }
    }
    regularNearby.sort(_compare);
    regularOnline.sort(_compare);
    return GroceryDealsOutcome(
      status: regularNearby.isEmpty && regularOnline.isEmpty
          ? DealsResultStatus.noReliablePrice
          : DealsResultStatus.regularPricesFound,
      providerFailed: failed,
      nearbyRecommendations: regularNearby,
      onlineRecommendations: regularOnline,
    );
  }

  GrocerySearchRequest _request(
    WeeklyFoodRequirement need,
    FoodSearchItem food,
    UserShoppingArea area,
    GrocerySearchPass pass,
  ) => GrocerySearchRequest(
    food: food,
    neededQuantity: need.purchaseGrams,
    unitType: food.unitType,
    shoppingArea: area,
    pass: pass,
  );

  List<GroceryRecommendation> _validateAndRank(
    WeeklyFoodRequirement need,
    FoodSearchItem food,
    UserShoppingArea area,
    List<GrocerySearchResult> results,
    GrocerySearchPass pass,
  ) {
    final timestamp = now().toUtc();
    return results
        .map((result) {
          if (!FoodSearchCatalog.productMatches(food, result.productName) ||
              result.storeName.trim().isEmpty ||
              !result.price.isFinite ||
              result.price <= 0 ||
              result.currency.trim().toUpperCase() != 'CAD' ||
              result.sourceUri == null ||
              result.sourceUri!.scheme != 'https' ||
              result.sourceUri!.host.isEmpty ||
              result.sourceUri!.userInfo.isNotEmpty ||
              (result.sourceUri!.hasPort && result.sourceUri!.port != 443) ||
              result.sourceName?.trim().isEmpty != false ||
              result.sourceName!.trim().toLowerCase() !=
                  result.sourceUri!.host.toLowerCase() ||
              result.verifiedAt == null ||
              timestamp.difference(result.verifiedAt!.toUtc()).abs() >
                  const Duration(hours: 48) ||
              result.sponsoredOnly ||
              result.matchConfidence < .7 ||
              (pass == GrocerySearchPass.deal &&
                  (result.priceKind != GroceryPriceKind.sale ||
                      result.dealConfidence < .7 ||
                      result.regularPrice == null ||
                      result.regularPrice! <= result.price ||
                      result.validUntil == null)) ||
              (pass == GrocerySearchPass.regularPrice &&
                  result.priceKind != GroceryPriceKind.regular) ||
              (result.validFrom != null &&
                  timestamp.isBefore(result.validFrom!.toUtc())) ||
              (result.validUntil != null &&
                  timestamp.isAfter(result.validUntil!.toUtc()))) {
            return null;
          }
          final distance = distanceService.distanceKm(
            area,
            result.storeLocation,
            providerDistanceKm: result.providerDistanceKm,
          );
          if (distance != null && distance < 0) {
            return null;
          }
          final packageConfirmed =
              result.packageQuantity != null &&
              result.packageUnitType != null &&
              result.packageQuantity!.isFinite &&
              result.packageQuantity! > 0;
          final nearbyEvidenceComplete =
              distance != null &&
              distance <= area.radiusKm &&
              packageConfirmed &&
              result.availabilityVerified;
          final normalized = PriceNormalizer.perCanonicalUnit(
            price: result.price,
            packageQuantity: result.packageQuantity,
            packageUnitType: result.packageUnitType,
            foodUnitType: food.unitType,
          );
          final discount =
              result.regularPrice != null &&
                  result.regularPrice! > result.price &&
                  result.regularPrice!.isFinite
              ? (result.regularPrice! - result.price) /
                    result.regularPrice! *
                    100
              : null;
          final packageFit = _packageFit(
            need.purchaseGrams,
            result.packageQuantity,
            food.unitType,
            result.packageUnitType,
          );
          final score =
              result.matchConfidence * 40 +
              result.dealConfidence *
                  (pass == GrocerySearchPass.deal ? 20 : 0) +
              (discount ?? 0).clamp(0, 50) * .3 +
              (distance == null
                  ? 0
                  : (1 - distance / area.radiusKm).clamp(0, 1) * 15) +
              packageFit * 20 +
              (normalized == null ? 0 : 5 / (1 + normalized));
          return GroceryRecommendation(
            foodId: food.foodId,
            foodName: food.canonicalName,
            neededQuantity: need.purchaseGrams,
            result: result,
            distanceKm: distance,
            tier: nearbyEvidenceComplete
                ? GroceryResultTier.verifiedNearby
                : GroceryResultTier.onlineStore,
            normalizedPrice: normalized,
            discountPercent: discount,
            score: score,
          );
        })
        .whereType<GroceryRecommendation>()
        .toList();
  }

  double _packageFit(
    double need,
    double? package,
    FoodUnitType foodUnit,
    FoodUnitType? packageUnit,
  ) {
    if (package == null || packageUnit != foodUnit || need <= 0) return .25;
    final packages = math.max(1, (need / package).ceil());
    final supplied = packages * package;
    return (1 - (supplied - need).abs() / need).clamp(0, 1).toDouble();
  }

  int _compare(GroceryRecommendation a, GroceryRecommendation b) {
    final score = b.score.compareTo(a.score);
    return score != 0 ? score : a.result.id.compareTo(b.result.id);
  }
}

class DealsSearchCoordinator {
  Future<GroceryDealsOutcome>? _inFlight;
  String? _inFlightUserId;
  Object? _token;

  Future<GroceryDealsOutcome> search({
    required String userId,
    required GroceryDealsEngine engine,
    required List<WeeklyFoodRequirement> groceryList,
  }) {
    final current = _inFlight;
    if (current != null && _inFlightUserId == userId) return current;
    final token = Object();
    final operation = _execute(token, engine, groceryList);
    _inFlight = operation;
    _inFlightUserId = userId;
    _token = token;
    return operation;
  }

  Future<GroceryDealsOutcome> _execute(
    Object token,
    GroceryDealsEngine engine,
    List<WeeklyFoodRequirement> groceryList,
  ) async {
    try {
      return await engine.findPrices(groceryList);
    } finally {
      if (identical(_token, token)) {
        _inFlight = null;
        _inFlightUserId = null;
        _token = null;
      }
    }
  }

  void clear() {
    _inFlight = null;
    _inFlightUserId = null;
    _token = null;
  }
}

class PriceNormalizer {
  const PriceNormalizer._();

  static double? perCanonicalUnit({
    required double price,
    required double? packageQuantity,
    required FoodUnitType? packageUnitType,
    required FoodUnitType foodUnitType,
  }) {
    if (packageQuantity == null ||
        packageUnitType == null ||
        packageUnitType != foodUnitType ||
        packageQuantity <= 0 ||
        price <= 0) {
      return null;
    }
    return packageUnitType == FoodUnitType.count
        ? price / packageQuantity
        : price / packageQuantity * 1000;
  }
}
