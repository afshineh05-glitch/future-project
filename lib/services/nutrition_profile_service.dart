import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/models/nutrition_profile.dart';

class NutritionProfileService {
  final SupabaseClient _supabase;

  NutritionProfileService({SupabaseClient? supabase})
    : _supabase = supabase ?? Supabase.instance.client;

  User get _currentUser {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw const NutritionProfileException(
        'Please sign in to manage your Nutrition Profile.',
      );
    }
    return user;
  }

  Future<NutritionProfile?> load() async {
    final user = _currentUser;
    final row = await _supabase
        .from('nutrition_profiles')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();

    return row == null ? null : NutritionProfile.fromMap(row);
  }

  Future<void> save(NutritionProfile profile) async {
    final user = _currentUser;
    if (profile.userId != user.id) {
      throw const NutritionProfileException(
        'Nutrition Profile user does not match the signed-in user.',
      );
    }

    await _supabase
        .from('nutrition_profiles')
        .upsert(profile.toMap(), onConflict: 'user_id');
  }

  String requireCurrentUserId() => _currentUser.id;
}

class NutritionProfileException implements Exception {
  final String message;

  const NutritionProfileException(this.message);

  @override
  String toString() => message;
}
