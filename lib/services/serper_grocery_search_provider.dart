import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/services/grocery_deals_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps Serper credentials and provider-specific behavior behind the Edge
/// Function. Flutter sends and receives only the stable Deals Engine contract.
class SerperGrocerySearchProvider implements GrocerySearchProvider {
  final SupabaseClient _supabase;

  SerperGrocerySearchProvider({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  Future<List<GrocerySearchResult>> search(GrocerySearchRequest request) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Authentication is required.');
    final response = await _supabase.functions.invoke(
      'grocery-search',
      body: {
        'foodId': request.food.foodId,
        'neededQuantity': request.neededQuantity,
        'pass': request.pass.name,
        'postalCode': request.shoppingArea.postalCode,
        'radiusKm': request.shoppingArea.radiusKm,
      },
    );
    if (_supabase.auth.currentUser?.id != user.id) return const [];
    final data = response.data;
    if (data is! Map || data['results'] is! List) return const [];
    return (data['results'] as List)
        .whereType<Map>()
        .map((raw) => _parse(Map<String, dynamic>.from(raw)))
        .whereType<GrocerySearchResult>()
        .toList(growable: false);
  }

  GrocerySearchResult? _parse(Map<String, dynamic> raw) {
    final sourceUri = Uri.tryParse(raw['sourceUrl']?.toString() ?? '');
    final kind = switch (raw['priceKind']) {
      'sale' => GroceryPriceKind.sale,
      'regular' => GroceryPriceKind.regular,
      _ => null,
    };
    final unit = switch (raw['packageUnitType']) {
      'mass' => FoodUnitType.mass,
      'volume' => FoodUnitType.volume,
      'count' => FoodUnitType.count,
      _ => null,
    };
    if (kind == null || sourceUri == null) return null;
    DateTime? date(String key) => DateTime.tryParse(raw[key]?.toString() ?? '');
    return GrocerySearchResult(
      id: raw['id']?.toString() ?? sourceUri.toString(),
      productName: raw['productName']?.toString() ?? '',
      storeName: raw['storeName']?.toString() ?? '',
      storeLocation: StoreLocation(
        latitude: (raw['storeLatitude'] as num?)?.toDouble(),
        longitude: (raw['storeLongitude'] as num?)?.toDouble(),
        city: raw['storeCity']?.toString(),
        postalCode: raw['storePostalCode']?.toString(),
      ),
      price: (raw['price'] as num?)?.toDouble() ?? double.nan,
      currency: raw['currency']?.toString() ?? '',
      priceKind: kind,
      regularPrice: (raw['regularPrice'] as num?)?.toDouble(),
      packageQuantity: (raw['packageQuantity'] as num?)?.toDouble(),
      packageUnitType: unit,
      validFrom: date('validFrom'),
      validUntil: date('validUntil'),
      matchConfidence: (raw['matchConfidence'] as num?)?.toDouble() ?? 0,
      dealConfidence: (raw['dealConfidence'] as num?)?.toDouble() ?? 0,
      providerDistanceKm: (raw['distanceKm'] as num?)?.toDouble(),
      sourceUri: sourceUri,
      sourceName: raw['sourceName']?.toString(),
      verifiedAt: date('verifiedAt'),
      availabilityVerified: raw['availabilityVerified'] == true,
      sponsoredOnly: raw['sponsoredOnly'] == true,
      dealVerified: raw['dealVerified'] == true,
      locationVerified: raw['locationVerified'] == true,
      onlineOnly: raw['onlineOnly'] != false,
      saleEvidence: raw['saleEvidence'] == true,
      radiusKm: (raw['radiusKm'] as num?)?.toDouble(),
    );
  }
}
