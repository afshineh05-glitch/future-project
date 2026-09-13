import '../models/canonical_exercise.dart';
import 'exercise_name_normalizer.dart';
import 'muscle_taxonomy.dart';

class CatalogValidationIssue {
  final String code;
  final String? canonicalId;
  final String message;
  const CatalogValidationIssue(this.code, this.message, {this.canonicalId});
}

class CatalogValidationReport {
  final int recordCount;
  final List<CatalogValidationIssue> issues;
  const CatalogValidationReport(this.recordCount, this.issues);
  bool get isValid => recordCount == 412 && issues.isEmpty;
}

class ExerciseCatalogValidationService {
  static const Set<String> movementPatterns = <String>{
    'horizontal_push',
    'vertical_push',
    'horizontal_pull',
    'vertical_pull',
    'squat',
    'hip_hinge',
    'lunge',
    'isolation',
    'core',
    'cardio',
    'mobility',
  };
  static const Set<String> equipmentValues = <String>{
    'bodyweight',
    'barbell',
    'dumbbell',
    'bench',
    'pull_up_bar',
    'cardio_machine',
  };

  CatalogValidationReport validate(List<CanonicalExercise> exercises) {
    final issues = <CatalogValidationIssue>[];
    final ids = <String>{};
    final slugs = <String>{};
    final identities = <String>{};
    final allIds = exercises.map((item) => item.canonicalId).toSet();
    for (final item in exercises) {
      void issue(String code, String message) => issues.add(
        CatalogValidationIssue(code, message, canonicalId: item.canonicalId),
      );
      if (item.canonicalId.isEmpty ||
          item.slug.isEmpty ||
          item.sourceName.trim().isEmpty ||
          item.displayName.trim().isEmpty) {
        issue('missing_name_or_identity', 'Required identity field is empty.');
      }
      if (!ids.add(item.canonicalId)) issue('duplicate_id', item.canonicalId);
      if (!slugs.add(item.slug)) issue('duplicate_slug', item.slug);
      if (!identities.add(item.normalizedName)) {
        issue('duplicate_identity', item.normalizedName);
      }
      if (ExerciseNameNormalizer.canonicalIdForSlug(item.slug) !=
          item.canonicalId) {
        issue(
          'unstable_id',
          'Canonical ID does not match the stable slug rule.',
        );
      }
      if (item.metadataStatus == 'verified') {
        if (!movementPatterns.contains(item.movementPattern)) {
          issue('invalid_movement_pattern', '${item.movementPattern}');
        }
        for (final value in item.equipment) {
          if (!equipmentValues.contains(value)) {
            issue('invalid_equipment', value);
          }
        }
        for (final muscle in <String>[
          ...item.primaryMuscles,
          ...item.secondaryMuscles,
          ...item.stabilizerMuscles,
        ]) {
          if (!MuscleTaxonomy.ids.contains(muscle)) {
            issue('invalid_muscle', muscle);
          }
        }
      }
      for (final reference in <String>[
        ...item.regressionIds,
        ...item.progressionIds,
        ...item.alternativeIds,
      ]) {
        if (!allIds.contains(reference)) issue('broken_reference', reference);
      }
      if (item.maleAnatomyStatus.isEmpty || item.femaleAnatomyStatus.isEmpty) {
        issue('missing_anatomy_status', 'Both anatomy statuses are required.');
      }
      if (item.femaleAnatomyAsset == null &&
          item.femaleAnatomyStatus != 'pending_generation') {
        issue('invalid_female_anatomy_status', item.femaleAnatomyStatus);
      }
      if (item.videoAsset != null && item.videoStatus == 'pending_license') {
        issue(
          'unexpected_video_asset',
          'Pending-license record contains a video.',
        );
      }
    }
    if (exercises.length != 412) {
      issues.add(
        CatalogValidationIssue(
          'incorrect_count',
          'Expected 412 records, found ${exercises.length}.',
        ),
      );
    }
    return CatalogValidationReport(exercises.length, issues);
  }

  List<List<CanonicalExercise>> duplicateCandidates(
    List<CanonicalExercise> exercises,
  ) {
    final groups = <String, List<CanonicalExercise>>{};
    for (final item in exercises) {
      final key = item.normalizedName.replaceAll(' ', '');
      groups.putIfAbsent(key, () => <CanonicalExercise>[]).add(item);
    }
    return groups.values.where((group) => group.length > 1).toList();
  }
}
