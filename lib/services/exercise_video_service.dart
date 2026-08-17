import 'package:supabase_flutter/supabase_flutter.dart';

enum ExerciseVideoStatus {
  ready,
  comingSoon,
  unavailable,
}

class ExerciseVideoSource {
  final ExerciseVideoStatus status;
  final String? url;
  final String provider;
  final String? exerciseId;
  final String? message;

  const ExerciseVideoSource({
    required this.status,
    required this.provider,
    this.url,
    this.exerciseId,
    this.message,
  });

  bool get isReady =>
      status == ExerciseVideoStatus.ready &&
      url != null &&
      url!.trim().isNotEmpty;

  factory ExerciseVideoSource.fromJson(
    Map<String, dynamic> json,
  ) {
    final rawStatus =
        json['status']?.toString().trim().toLowerCase();

    final status = switch (rawStatus) {
      'ready' => ExerciseVideoStatus.ready,
      'unavailable' => ExerciseVideoStatus.unavailable,
      _ => ExerciseVideoStatus.comingSoon,
    };

    return ExerciseVideoSource(
      status: status,
      provider:
          json['provider']?.toString().trim().isNotEmpty == true
              ? json['provider'].toString().trim()
              : 'movekit',
      url: json['video_url']?.toString(),
      exerciseId: json['exercise_id']?.toString(),
      message: json['message']?.toString(),
    );
  }
}

class ExerciseVideoService {
  final SupabaseClient _supabase;

  ExerciseVideoService({
    SupabaseClient? supabase,
  }) : _supabase = supabase ?? Supabase.instance.client;

  Future<ExerciseVideoSource> resolveVideo({
    required String exerciseName,
    String? existingVideoUrl,
  }) async {
    final cleanName = exerciseName.trim();

    if (cleanName.isEmpty) {
      return const ExerciseVideoSource(
        status: ExerciseVideoStatus.unavailable,
        provider: 'movekit',
        message: 'Exercise name is missing.',
      );
    }

    final directUrl = existingVideoUrl?.trim();
    if (directUrl != null && directUrl.isNotEmpty) {
      return ExerciseVideoSource(
        status: ExerciseVideoStatus.ready,
        provider: 'stored',
        url: directUrl,
        message: 'Using the video already assigned to this exercise.',
      );
    }

    try {
      final response = await _supabase.functions.invoke(
        'exercise-video',
        body: <String, dynamic>{
          'exercise_name': cleanName,
        },
      );

      if (response.status < 200 || response.status >= 300) {
        return ExerciseVideoSource(
          status: ExerciseVideoStatus.unavailable,
          provider: 'movekit',
          message:
              'Video service returned ${response.status}.',
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        return ExerciseVideoSource.fromJson(data);
      }

      if (data is Map) {
        return ExerciseVideoSource.fromJson(
          Map<String, dynamic>.from(data),
        );
      }

      return const ExerciseVideoSource(
        status: ExerciseVideoStatus.unavailable,
        provider: 'movekit',
        message: 'Video service returned an invalid response.',
      );
    } catch (_) {
      return const ExerciseVideoSource(
        status: ExerciseVideoStatus.comingSoon,
        provider: 'movekit',
        message:
            'Exercise video will become available when the video provider is connected.',
      );
    }
  }
}