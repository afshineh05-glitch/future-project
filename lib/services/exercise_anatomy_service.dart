class ExerciseAnatomyService {
  static const Map<String, String> _assets = <String, String>{
    'barbell bench press':
        'assets/exercises/anatomy/barbell_bench_press.png',
    'barbell bent-over row':
        'assets/exercises/anatomy/barbell_bent_over_row.png',
    'barbell bent over row':
        'assets/exercises/anatomy/barbell_bent_over_row.png',
    'medicine ball chest pass (explosive)':
        'assets/exercises/anatomy/medicine_ball_chest_pass_explosive.png',
    'medicine ball chest pass':
        'assets/exercises/anatomy/medicine_ball_chest_pass_explosive.png',
    'weighted pull-up':
        'assets/exercises/anatomy/weighted_pull_up.png',
    'weighted pull up':
        'assets/exercises/anatomy/weighted_pull_up.png',
    'incline dumbbell press':
        'assets/exercises/anatomy/incline_dumbbell_press.png',
    'face pulls':
        'assets/exercises/anatomy/face_pulls.png',
    'face pull':
        'assets/exercises/anatomy/face_pulls.png',
  };

  static String? assetFor(String exerciseName) {
    final String normalized = exerciseName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ');

    return _assets[normalized];
  }

  static bool hasAsset(String exerciseName) {
    return assetFor(exerciseName) != null;
  }
}
