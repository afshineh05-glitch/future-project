enum AnatomySex { male, female }

enum AnatomyJobStatus {
  pending,
  generating,
  pendingReview,
  approved,
  approvedExisting,
  rejected,
  failed,
}

class AnatomyGenerationJob {
  AnatomyGenerationJob({
    required this.canonicalId,
    required this.exerciseName,
    required this.sex,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.outputPath,
    required this.promptVersion,
    this.templateId,
    this.templatePath,
    this.templateSha256,
    this.templateRole,
    this.status = AnatomyJobStatus.pending,
    this.attempts = 0,
    this.validationResult,
    this.errorDetails,
  });

  final String canonicalId;
  final String exerciseName;
  final AnatomySex sex;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final String outputPath;
  final String promptVersion;
  final String? templateId;
  final String? templatePath;
  final String? templateSha256;
  final String? templateRole;
  AnatomyJobStatus status;
  int attempts;
  Map<String, Object?>? validationResult;
  String? errorDetails;

  String get jobId => '${canonicalId}_${sex.name}';

  Map<String, Object?> toJson() => <String, Object?>{
    'job_id': jobId,
    'canonical_id': canonicalId,
    'exercise_name': exerciseName,
    'sex': sex.name,
    'primary_muscles': primaryMuscles,
    'secondary_muscles': secondaryMuscles,
    'output_path': outputPath,
    'prompt_version': promptVersion,
    'template_id': templateId,
    'template_path': templatePath,
    'template_sha256': templateSha256,
    'template_role': templateRole,
    'status': _statusValue(status),
    'attempts': attempts,
    'validation_result': validationResult,
    'error_details': errorDetails,
  };

  factory AnatomyGenerationJob.fromJson(Map<String, dynamic> json) =>
      AnatomyGenerationJob(
        canonicalId: json['canonical_id'] as String,
        exerciseName: json['exercise_name'] as String,
        sex: AnatomySex.values.byName(json['sex'] as String),
        primaryMuscles: List<String>.from(json['primary_muscles'] as List),
        secondaryMuscles: List<String>.from(json['secondary_muscles'] as List),
        outputPath: json['output_path'] as String,
        promptVersion: json['prompt_version'] as String,
        templateId: json['template_id'] as String?,
        templatePath: json['template_path'] as String?,
        templateSha256: json['template_sha256'] as String?,
        templateRole: json['template_role'] as String?,
        status: _parseStatus(json['status'] as String),
        attempts: (json['attempts'] as num).toInt(),
        validationResult: (json['validation_result'] as Map?)
            ?.cast<String, Object?>(),
        errorDetails: json['error_details'] as String?,
      );

  static String _statusValue(AnatomyJobStatus value) => switch (value) {
    AnatomyJobStatus.pendingReview => 'pending_review',
    AnatomyJobStatus.approvedExisting => 'approved_existing',
    _ => value.name,
  };

  static AnatomyJobStatus _parseStatus(String value) => switch (value) {
    'pending_review' => AnatomyJobStatus.pendingReview,
    'approved_existing' => AnatomyJobStatus.approvedExisting,
    _ => AnatomyJobStatus.values.byName(value),
  };
}
