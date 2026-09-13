import '../models/canonical_exercise.dart';
import 'exercise_name_normalizer.dart';

enum LicensedVideoMatchStatus { exact, highConfidence, review, unmatched }

class LicensedVideoMatch {
  final LicensedVideoMatchStatus status;
  final CanonicalExercise? exercise;
  final List<CanonicalExercise> candidates;
  final double confidence;
  const LicensedVideoMatch(
    this.status, {
    this.exercise,
    this.candidates = const [],
    this.confidence = 0,
  });
}

abstract interface class LicensedVideoMatcher {
  LicensedVideoMatch matchFilename(String filename);
}

class CanonicalLicensedVideoMatcher implements LicensedVideoMatcher {
  final List<CanonicalExercise> exercises;
  const CanonicalLicensedVideoMatcher(this.exercises);

  @override
  LicensedVideoMatch matchFilename(String filename) {
    final stem = filename.replaceAll(RegExp(r'\.[^.]+$'), '');
    final key = ExerciseNameNormalizer.normalize(stem);
    final matches = exercises.where((item) {
      if (item.canonicalId == stem || item.normalizedName == key) return true;
      if (ExerciseNameNormalizer.normalize(item.sourceName) == key) return true;
      return item.aliases.any(
        (alias) => ExerciseNameNormalizer.normalize(alias) == key,
      );
    }).toList();
    if (matches.length == 1) {
      return LicensedVideoMatch(
        LicensedVideoMatchStatus.exact,
        exercise: matches.single,
        confidence: 1,
      );
    }
    if (matches.length > 1) {
      return LicensedVideoMatch(
        LicensedVideoMatchStatus.review,
        candidates: matches,
      );
    }
    final contained = exercises
        .where(
          (item) =>
              key.contains(item.normalizedName) ||
              item.normalizedName.contains(key),
        )
        .toList();
    if (contained.length == 1 && key.isNotEmpty) {
      return LicensedVideoMatch(
        LicensedVideoMatchStatus.highConfidence,
        exercise: contained.single,
        confidence: .9,
      );
    }
    if (contained.length > 1) {
      return LicensedVideoMatch(
        LicensedVideoMatchStatus.review,
        candidates: contained,
      );
    }
    return const LicensedVideoMatch(LicensedVideoMatchStatus.unmatched);
  }
}
