enum GrocerySearchPass { deal, regularPrice }

enum GroceryPriceKind { sale, regular }

enum GroceryResultTier { verifiedNearby, onlineStore }

enum FoodUnitType { mass, volume, count }

enum DealsResultStatus {
  dealsFound,
  regularPricesFound,
  shoppingAreaRequired,
  noReliablePrice,
}

class UserShoppingArea {
  final String? ownerUserId;
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? postalCode;
  final double radiusKm;

  const UserShoppingArea({
    this.ownerUserId,
    this.latitude,
    this.longitude,
    this.city,
    this.postalCode,
    this.radiusKm = 15,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
  bool get isUsable =>
      hasCoordinates || (postalCode?.trim().isNotEmpty ?? false);
}

class StoreLocation {
  final double? latitude;
  final double? longitude;
  final String? city;
  final String? postalCode;

  const StoreLocation({
    this.latitude,
    this.longitude,
    this.city,
    this.postalCode,
  });

  bool get hasCoordinates => latitude != null && longitude != null;
}

class FoodSearchItem {
  final String foodId;
  final String canonicalName;
  final List<String> allowedSearchTerms;
  final String category;
  final bool searchEnabled;
  final FoodUnitType unitType;

  const FoodSearchItem({
    required this.foodId,
    required this.canonicalName,
    required this.allowedSearchTerms,
    required this.category,
    required this.searchEnabled,
    required this.unitType,
  });
}

class GrocerySearchRequest {
  final FoodSearchItem food;
  final double neededQuantity;
  final FoodUnitType unitType;
  final UserShoppingArea shoppingArea;
  final GrocerySearchPass pass;

  const GrocerySearchRequest({
    required this.food,
    required this.neededQuantity,
    required this.unitType,
    required this.shoppingArea,
    required this.pass,
  });
}

class GrocerySearchResult {
  final String id;
  final String productName;
  final String storeName;
  final StoreLocation storeLocation;
  final double price;
  final String currency;
  final GroceryPriceKind priceKind;
  final double? regularPrice;
  final double? packageQuantity;
  final FoodUnitType? packageUnitType;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final double matchConfidence;
  final double dealConfidence;
  final double? providerDistanceKm;
  final Uri? sourceUri;
  final String? sourceName;
  final DateTime? verifiedAt;
  final bool availabilityVerified;
  final bool sponsoredOnly;
  final bool dealVerified;
  final bool locationVerified;
  final bool onlineOnly;
  final bool saleEvidence;
  final double? radiusKm;

  const GrocerySearchResult({
    required this.id,
    required this.productName,
    required this.storeName,
    required this.storeLocation,
    required this.price,
    required this.currency,
    required this.priceKind,
    this.regularPrice,
    this.packageQuantity,
    this.packageUnitType,
    this.validFrom,
    this.validUntil,
    this.matchConfidence = 1,
    this.dealConfidence = 1,
    this.providerDistanceKm,
    this.sourceUri,
    this.sourceName,
    this.verifiedAt,
    this.availabilityVerified = false,
    this.sponsoredOnly = false,
    this.dealVerified = false,
    this.locationVerified = false,
    this.onlineOnly = true,
    this.saleEvidence = false,
    this.radiusKm,
  });

  double get currentPrice => price;
  double? get salePrice => priceKind == GroceryPriceKind.sale ? price : null;
}

class GroceryRecommendation {
  final String foodId;
  final String foodName;
  final double neededQuantity;
  final GrocerySearchResult result;
  final double? distanceKm;
  final GroceryResultTier tier;
  final double? normalizedPrice;
  final double? discountPercent;
  final double score;

  const GroceryRecommendation({
    required this.foodId,
    required this.foodName,
    required this.neededQuantity,
    required this.result,
    required this.distanceKm,
    this.tier = GroceryResultTier.verifiedNearby,
    required this.normalizedPrice,
    required this.discountPercent,
    required this.score,
  });

  bool get isDeal => result.priceKind == GroceryPriceKind.sale;
  bool get isVerifiedNearby => tier == GroceryResultTier.verifiedNearby;
}

class GroceryDealsOutcome {
  final DealsResultStatus status;
  final bool providerFailed;
  final List<GroceryRecommendation> nearbyRecommendations;
  final List<GroceryRecommendation> onlineRecommendations;

  const GroceryDealsOutcome({
    required this.status,
    this.providerFailed = false,
    this.nearbyRecommendations = const [],
    this.onlineRecommendations = const [],
  });

  List<GroceryRecommendation> get recommendations => allRecommendations;

  List<GroceryRecommendation> get allRecommendations => [
    ...nearbyRecommendations,
    ...onlineRecommendations,
  ];
}

class DealNotificationCandidate {
  final GroceryRecommendation recommendation;
  final bool foodIsNeeded;
  final bool savingIsMeaningful;
  final bool duplicateSuppressionPassed;

  const DealNotificationCandidate({
    required this.recommendation,
    required this.foodIsNeeded,
    required this.savingIsMeaningful,
    required this.duplicateSuppressionPassed,
  });

  bool get isEligible =>
      foodIsNeeded &&
      recommendation.isDeal &&
      savingIsMeaningful &&
      duplicateSuppressionPassed;
}
