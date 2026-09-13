enum ExerciseAnatomyProfile { male, female }

class ExerciseAnatomyService {
  static const Map<String, String> _legacyMaleAssets = <String, String>{
    'barbell bench press': 'assets/exercises/anatomy/barbell_bench_press.png',
    'barbell bent-over row':
        'assets/exercises/anatomy/barbell_bent_over_row.png',
    'barbell bent over row':
        'assets/exercises/anatomy/barbell_bent_over_row.png',
    'barbell squat': 'assets/exercises/anatomy/barbell_back_squat.png',
    'forward lunge': 'assets/exercises/anatomy/forward_lunge.png',
    'medicine ball chest pass (explosive)':
        'assets/exercises/anatomy/medicine_ball_chest_pass_explosive.png',
    'medicine ball chest pass':
        'assets/exercises/anatomy/medicine_ball_chest_pass_explosive.png',
    'weighted pull-up': 'assets/exercises/anatomy/weighted_pull_up.png',
    'weighted pull up': 'assets/exercises/anatomy/weighted_pull_up.png',
    'incline dumbbell press':
        'assets/exercises/anatomy/incline_dumbbell_press.png',
    'face pulls': 'assets/exercises/anatomy/face_pulls.png',
    'face pull': 'assets/exercises/anatomy/face_pulls.png',
  };

  static ExerciseAnatomyProfile? profileFromFoundationValue(dynamic value) {
    return switch (value?.toString().trim().toLowerCase()) {
      'male' => ExerciseAnatomyProfile.male,
      'female' => ExerciseAnatomyProfile.female,
      _ => null,
    };
  }

  static String? resolve({
    required ExerciseAnatomyProfile? profile,
    String? maleAsset,
    String? femaleAsset,
    String? legacyExerciseName,
  }) {
    if (profile == null) return null;
    if (profile == ExerciseAnatomyProfile.female) {
      final asset = femaleAsset?.trim();
      return asset == null || asset.isEmpty ? null : asset;
    }
    final asset = maleAsset?.trim();
    if (asset != null && asset.isNotEmpty) return asset;
    return legacyMaleAssetFor(legacyExerciseName ?? '');
  }

  static String? legacyMaleAssetFor(String exerciseName) {
    final String normalized = exerciseName.trim().toLowerCase().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );

    return _legacyMaleAssets[normalized];
  }

  @Deprecated('Use resolve with an explicit anatomy profile.')
  static String? assetFor(String exerciseName) =>
      legacyMaleAssetFor(exerciseName);
}
