import 'dart:math' as math;

import 'package:future_project/models/grocery_deals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class DealsLocationService {
  String? get authenticatedUserId;
  Future<UserShoppingArea?> currentShoppingArea();
  Future<UserShoppingArea> saveShoppingArea({
    required String postalCode,
    required double radiusKm,
  });
}

class SupabaseDealsLocationService implements DealsLocationService {
  final SupabaseClient _supabase;

  SupabaseDealsLocationService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  String? get authenticatedUserId => _supabase.auth.currentUser?.id;

  @override
  Future<UserShoppingArea?> currentShoppingArea() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final row = await _supabase
        .from('user_shopping_areas')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (row == null) return null;
    if (_supabase.auth.currentUser?.id != user.id) return null;
    return UserShoppingArea(
      ownerUserId: user.id,
      latitude: (row['approximate_latitude'] as num?)?.toDouble(),
      longitude: (row['approximate_longitude'] as num?)?.toDouble(),
      city: row['city']?.toString(),
      postalCode: row['postal_code']?.toString(),
      radiusKm: (row['radius_km'] as num?)?.toDouble() ?? 15,
    );
  }

  @override
  Future<UserShoppingArea> saveShoppingArea({
    required String postalCode,
    required double radiusKm,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw StateError('Sign in to save a shopping area.');
    final normalized = CanadianPostalCode.normalize(postalCode);
    if (!CanadianPostalCode.isValid(normalized)) {
      throw const FormatException('Enter a valid Canadian postal code.');
    }
    if (!CanadianPostalCode.allowedRadiiKm.contains(radiusKm)) {
      throw const FormatException('Choose a supported search radius.');
    }
    await _supabase.from('user_shopping_areas').upsert({
      'user_id': user.id,
      'postal_code': normalized,
      'radius_km': radiusKm,
      'approximate_latitude': null,
      'approximate_longitude': null,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id');
    if (_supabase.auth.currentUser?.id != user.id) {
      throw StateError('The signed-in account changed while saving.');
    }
    return UserShoppingArea(
      ownerUserId: user.id,
      postalCode: normalized,
      radiusKm: radiusKm,
    );
  }
}

class FixedDealsLocationService implements DealsLocationService {
  final UserShoppingArea? area;
  final String? userId;
  const FixedDealsLocationService(this.area, {this.userId = 'test-user'});

  @override
  String? get authenticatedUserId => userId;

  @override
  Future<UserShoppingArea?> currentShoppingArea() async => area;

  @override
  Future<UserShoppingArea> saveShoppingArea({
    required String postalCode,
    required double radiusKm,
  }) => throw UnsupportedError('Fixed location service is read-only.');
}

class CanadianPostalCode {
  CanadianPostalCode._();

  static const allowedRadiiKm = <double>[2, 5, 10, 15, 25];
  static final RegExp _pattern = RegExp(
    r'^[ABCEGHJKLMNPRSTVXY]\d[ABCEGHJKLMNPRSTVWXYZ] \d[ABCEGHJKLMNPRSTVWXYZ]\d$',
  );

  static String normalize(String value) {
    final compact = value.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (compact.length != 6) return compact;
    return '${compact.substring(0, 3)} ${compact.substring(3)}';
  }

  static bool isValid(String value) => _pattern.hasMatch(normalize(value));
}

class StoreDistanceService {
  const StoreDistanceService();

  double? distanceKm(
    UserShoppingArea area,
    StoreLocation store, {
    double? providerDistanceKm,
  }) {
    if (area.hasCoordinates && store.hasCoordinates) {
      return _haversineKm(
        area.latitude!,
        area.longitude!,
        store.latitude!,
        store.longitude!,
      );
    }
    if (area.postalCode != null && store.postalCode != null) {
      final userPrefix = _postalPrefix(area.postalCode!);
      final storePrefix = _postalPrefix(store.postalCode!);
      if (userPrefix == storePrefix && providerDistanceKm != null) {
        return providerDistanceKm;
      }
    }
    return null;
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return radius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  String _postalPrefix(String value) => value
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9]'), '')
      .substring(
        0,
        math.min(3, value.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length),
      );
}
