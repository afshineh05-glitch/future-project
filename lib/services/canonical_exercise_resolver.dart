import '../models/canonical_exercise.dart';
import 'exercise_name_normalizer.dart';

enum ExerciseResolutionKind {
  canonicalId,
  exactName,
  alias,
  legacyName,
  unknown,
  ambiguous,
}

class ExerciseResolution {
  final ExerciseResolutionKind kind;
  final CanonicalExercise? exercise;
  final List<CanonicalExercise> candidates;
  const ExerciseResolution(
    this.kind, {
    this.exercise,
    this.candidates = const [],
  });
}

class CanonicalExerciseResolver {
  final List<CanonicalExercise> exercises;
  late final Map<String, CanonicalExercise> _byId = {
    for (final item in exercises) item.canonicalId: item,
  };

  CanonicalExerciseResolver(this.exercises);

  ExerciseResolution resolve({String? canonicalId, String? name}) {
    final byId = canonicalId == null ? null : _byId[canonicalId.trim()];
    if (byId != null) {
      return ExerciseResolution(
        ExerciseResolutionKind.canonicalId,
        exercise: byId,
      );
    }
    final key = ExerciseNameNormalizer.normalize(name ?? '');
    if (key.isEmpty) {
      return const ExerciseResolution(ExerciseResolutionKind.unknown);
    }
    final exact = exercises
        .where((item) => item.normalizedName == key)
        .toList();
    if (exact.length == 1) {
      return ExerciseResolution(
        ExerciseResolutionKind.exactName,
        exercise: exact.single,
      );
    }
    final aliases = exercises
        .where(
          (item) => item.aliases.any(
            (alias) => ExerciseNameNormalizer.normalize(alias) == key,
          ),
        )
        .toList();
    if (aliases.length == 1) {
      return ExerciseResolution(
        ExerciseResolutionKind.alias,
        exercise: aliases.single,
      );
    }
    if (aliases.length > 1 || exact.length > 1) {
      return ExerciseResolution(
        ExerciseResolutionKind.ambiguous,
        candidates: <CanonicalExercise>[...exact, ...aliases],
      );
    }
    return const ExerciseResolution(ExerciseResolutionKind.unknown);
  }
}
