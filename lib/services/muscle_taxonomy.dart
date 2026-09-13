import 'exercise_name_normalizer.dart';

class MuscleTaxonomy {
  static const Set<String> ids = <String>{
    'chest',
    'anterior_deltoids',
    'lateral_deltoids',
    'posterior_deltoids',
    'triceps',
    'biceps',
    'forearms',
    'lats',
    'traps',
    'upper_back',
    'spinal_erectors',
    'core',
    'obliques',
    'glutes',
    'quadriceps',
    'hamstrings',
    'adductors',
    'abductors',
    'hip_flexors',
    'calves',
  };

  static const Map<String, String> _aliases = <String, String>{
    'pectorals': 'chest',
    'front delts': 'anterior_deltoids',
    'side delts': 'lateral_deltoids',
    'rear delts': 'posterior_deltoids',
    'latissimus dorsi': 'lats',
    'trapezius': 'traps',
    'lower back': 'spinal_erectors',
    'abdominals': 'core',
    'quads': 'quadriceps',
  };

  static String? resolve(String value) {
    final normalized = ExerciseNameNormalizer.normalize(value);
    final candidate = normalized.replaceAll(' ', '_');
    if (ids.contains(candidate)) return candidate;
    return _aliases[normalized];
  }
}
