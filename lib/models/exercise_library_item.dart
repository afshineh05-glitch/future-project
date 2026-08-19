class ExerciseLibraryItem {
  final String exerciseId;
  final String exerciseName;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String? anatomyAsset;
  final String? exerciseEffect;
  final String? videoUrl;

  const ExerciseLibraryItem({
    required this.exerciseId,
    required this.exerciseName,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.anatomyAsset,
    required this.exerciseEffect,
    required this.videoUrl,
  });

  factory ExerciseLibraryItem.fromMap(Map<String, dynamic> map) {
    List<String> list(dynamic value) =>
        ((value as List?) ?? const <dynamic>[])
            .map((e) => e.toString())
            .toList();

    return ExerciseLibraryItem(
      exerciseId: map['exercise_id']?.toString() ?? '',
      exerciseName: map['exercise_name']?.toString() ?? '',
      primaryMuscles: list(map['primary_muscles']),
      secondaryMuscles: list(map['secondary_muscles']),
      anatomyAsset: map['anatomy_asset']?.toString(),
      exerciseEffect: map['exercise_effect']?.toString(),
      videoUrl: map['video_url']?.toString(),
    );
  }
}