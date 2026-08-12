import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/meal_analysis_result.dart';

class MealService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadMealImage(File imageFile) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      final String fileExtension =
          imageFile.path.split('.').last.toLowerCase();

      final String fileName =
          '${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

      final String storagePath =
          'uploads/${user.id}/$fileName';

      debugPrint('Starting image upload...');
      debugPrint('Bucket: meal-images');
      debugPrint('Storage path: $storagePath');

      await _supabase.storage
          .from('meal-images')
          .upload(
            storagePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      final String publicUrl = _supabase.storage
          .from('meal-images')
          .getPublicUrl(storagePath);

      debugPrint('UPLOAD SUCCESS');
      debugPrint('Public URL: $publicUrl');

      return publicUrl;
    } catch (error, stackTrace) {
      debugPrint('UPLOAD ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> saveMeal({
    required MealAnalysisResult result,
    required String imagePath,
  }) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      await _supabase.from('meal_scans').insert({
        'user_id': user.id,
        'meal_name': result.mealName,
        'calories': result.calories,
        'protein': result.protein,
        'carbs': result.carbs,
        'fat': result.fat,
        'detected_foods': result.detectedFoods,
        'confidence': result.confidence,
        'image_path': imagePath,
      });

      debugPrint('MEAL SAVED SUCCESSFULLY');
    } catch (error, stackTrace) {
      debugPrint('SAVE MEAL ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRecentMeals({
    int limit = 10,
  }) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      final List<Map<String, dynamic>> data =
          await _supabase
              .from('meal_scans')
              .select()
              .eq('user_id', user.id)
              .order(
                'created_at',
                ascending: false,
              )
              .limit(limit);

      return data;
    } catch (error, stackTrace) {
      debugPrint('LOAD RECENT MEALS ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getMeal(
    String id,
  ) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      final Map<String, dynamic>? data =
          await _supabase
              .from('meal_scans')
              .select()
              .eq('id', id)
              .eq('user_id', user.id)
              .maybeSingle();

      return data;
    } catch (error, stackTrace) {
      debugPrint('GET MEAL ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteMeal(String id) async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      await _supabase
          .from('meal_scans')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      debugPrint('MEAL DELETED SUCCESSFULLY');
    } catch (error, stackTrace) {
      debugPrint('DELETE MEAL ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }

  Future<void> deleteAllMeals() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw Exception('User is not logged in');
      }

      await _supabase
          .from('meal_scans')
          .delete()
          .eq('user_id', user.id);

      debugPrint('ALL USER MEALS DELETED SUCCESSFULLY');
    } catch (error, stackTrace) {
      debugPrint('DELETE ALL MEALS ERROR: $error');
      debugPrint('STACK TRACE: $stackTrace');
      rethrow;
    }
  }
}