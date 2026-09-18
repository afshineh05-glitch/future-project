import '../models/anatomy_generation_job.dart';
import '../models/canonical_exercise.dart';

class AnatomyProductionService {
  static const promptVersion = 'muscleup_anatomy_locked_v4';
  static const eligibleMetadataStatus = 'metadata_validated';
  static const femaleTemplateId = 'female_neutral_anatomy_master_v3';
  static const femaleTemplatePath =
      'assets/exercises/anatomy/templates/female_neutral_anatomy_master_v3.png';
  static const femaleTemplateSha256 =
      '08B6D1124802BD7CDBDA31107A3C4D68990FF5CC2AFD354F2F07F936998C5057';
  static const maleTemplateId = 'male_neutral_anatomy_master_v4';
  static const maleTemplatePath =
      'assets/exercises/anatomy/templates/male_neutral_anatomy_master_v4.png';
  static const maleTemplateSha256 =
      '5FFE7590F204E01A1A1EC95B5D2312404B32A1FA59D2464E254D453254B95BD9';

  List<AnatomyGenerationJob> buildManifest(
    Iterable<CanonicalExercise> exercises,
  ) {
    final eligible =
        exercises
            .where(
              (exercise) => exercise.metadataStatus == eligibleMetadataStatus,
            )
            .toList()
          ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
    return <AnatomyGenerationJob>[
      for (final exercise in eligible)
        for (final sex in AnatomySex.values)
          AnatomyGenerationJob(
            canonicalId: exercise.canonicalId,
            exerciseName: exercise.displayName,
            sex: sex,
            primaryMuscles: exercise.primaryMuscles,
            secondaryMuscles: exercise.secondaryMuscles,
            outputPath:
                'assets/exercises/anatomy/${sex.name}/${exercise.canonicalId}.png',
            promptVersion: promptVersion,
            templateId: sex == AnatomySex.female
                ? femaleTemplateId
                : maleTemplateId,
            templatePath: sex == AnatomySex.female
                ? femaleTemplatePath
                : maleTemplatePath,
            templateSha256: sex == AnatomySex.female
                ? femaleTemplateSha256
                : maleTemplateSha256,
            templateRole: 'card_template',
            status: _hasApprovedAsset(exercise, sex)
                ? AnatomyJobStatus.approvedExisting
                : AnatomyJobStatus.pending,
          ),
    ];
  }

  String promptFor(AnatomyGenerationJob job) =>
      '''
Create anatomical artwork only on a plain white or transparent background. Render
no text, letters, numbers, title, labels, exercise name, typography, icons, legend,
border, or logo. Show exactly two complete full-body ${job.sex.name} anatomical
figures in a neutral standing pose: one front view on the left and one back view on
the right. Highlight only these primary muscles in anatomical red:
${job.primaryMuscles.join(', ')}. Highlight only these secondary muscles in
anatomical orange: ${job.secondaryMuscles.join(', ')}. Use medically plausible
muscle shapes and placement, never circles or symbolic blobs. No exercise
demonstration, masks, overlays, recoloring workflow, old anatomy fragments, dark
background, duplicate front views, or cropped bodies.
''';

  void enforceSpendGuard({
    required int imageCount,
    required double? costPerImageUsd,
    required double maximumSpendUsd,
  }) {
    if (maximumSpendUsd < 0) throw ArgumentError.value(maximumSpendUsd);
    if (imageCount == 0) return;
    if (costPerImageUsd == null) {
      throw StateError(
        'Provider cost is unknown; spend guard cannot be enforced.',
      );
    }
    final estimate = imageCount * costPerImageUsd;
    if (estimate > maximumSpendUsd) {
      throw StateError(
        'Estimated spend \$${estimate.toStringAsFixed(2)} exceeds guard '
        '\$${maximumSpendUsd.toStringAsFixed(2)}.',
      );
    }
  }

  bool shouldGenerate(AnatomyGenerationJob job) =>
      job.status == AnatomyJobStatus.pending ||
      job.status == AnatomyJobStatus.rejected ||
      job.status == AnatomyJobStatus.failed;

  void approve(AnatomyGenerationJob job) {
    if (job.status != AnatomyJobStatus.pendingReview) {
      throw StateError('Only pending_review jobs can be approved.');
    }
    job.status = AnatomyJobStatus.approved;
  }

  void reject(AnatomyGenerationJob job, String reason) {
    if (job.status != AnatomyJobStatus.pendingReview) {
      throw StateError('Only pending_review jobs can be rejected.');
    }
    if (reason.trim().isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    job.status = AnatomyJobStatus.rejected;
    job.errorDetails = reason.trim();
  }

  String validationFailureReason(Map<String, Object?>? validation) {
    if (validation == null) return 'Validation returned no result.';
    final reasons = <String>[
      for (final entry in validation.entries)
        if (entry.value == true && entry.key != 'valid')
          entry.key.replaceAll('_', ' '),
    ];
    final summary = validation['summary']?.toString().trim();
    if (summary != null && summary.isNotEmpty) reasons.insert(0, summary);
    return reasons.isEmpty ? 'Validation failed without provider details.' : reasons.join('; ');
  }

  Map<String, Object?> catalogPatchForApproval(AnatomyGenerationJob job) {
    if (job.status != AnatomyJobStatus.approved) {
      throw StateError('The job must be approved before catalog attachment.');
    }
    return <String, Object?>{
      '${job.sex.name}_anatomy_asset': job.outputPath,
      '${job.sex.name}_anatomy_status': 'approved',
    };
  }

  static bool _hasApprovedAsset(CanonicalExercise exercise, AnatomySex sex) {
    final asset = sex == AnatomySex.male
        ? exercise.maleAnatomyAsset
        : exercise.femaleAnatomyAsset;
    final status = sex == AnatomySex.male
        ? exercise.maleAnatomyStatus
        : exercise.femaleAnatomyStatus;
    return asset != null && asset.isNotEmpty && status.startsWith('approved');
  }
}
