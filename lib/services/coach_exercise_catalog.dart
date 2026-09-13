import '../models/canonical_exercise.dart';
import 'canonical_exercise_resolver.dart';
import 'exercise_catalog_repository.dart';

class CoachExerciseCatalog {
  final ExerciseCatalogRepository repository;
  const CoachExerciseCatalog(this.repository);

  Future<List<CanonicalExercise>> selectableExercises() =>
      repository.load().then(
        (items) => items
            .where(
              (item) =>
                  item.active &&
                  item.validationStatus == 'verified' &&
                  item.metadataStatus == 'metadata_validated',
            )
            .toList(growable: false),
      );

  Future<CanonicalExercise?> resolveSelection({
    String? canonicalId,
    String? legacyName,
  }) async {
    final active = await selectableExercises();
    return CanonicalExerciseResolver(
      active,
    ).resolve(canonicalId: canonicalId, name: legacyName).exercise;
  }
}
