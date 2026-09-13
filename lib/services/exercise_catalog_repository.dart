import 'dart:convert';

import '../models/canonical_exercise.dart';

typedef CatalogTextLoader = Future<String> Function(String path);

class ExerciseCatalogRepository {
  static const String assetPath =
      'assets/data/exercise_library/movekit_complete_catalog.json';
  final CatalogTextLoader _loadText;
  List<CanonicalExercise>? _cache;

  ExerciseCatalogRepository(this._loadText);

  Future<List<CanonicalExercise>> load({bool refresh = false}) async {
    if (!refresh && _cache != null) return _cache!;
    final decoded = jsonDecode(await _loadText(assetPath));
    if (decoded is! Map<String, dynamic> || decoded['exercises'] is! List) {
      throw const FormatException('Invalid canonical exercise catalog.');
    }
    _cache = (decoded['exercises'] as List)
        .map(
          (value) => CanonicalExercise.fromJson(
            Map<String, dynamic>.from(value as Map),
          ),
        )
        .toList(growable: false);
    return _cache!;
  }

  Future<List<CanonicalExercise>> activeForCoach() async =>
      (await load()).where((item) => item.isCoachSelectable).toList();
}
