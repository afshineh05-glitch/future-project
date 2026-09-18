import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/anatomy_generation_job.dart';
import 'package:future_project/models/canonical_exercise.dart';
import 'package:future_project/services/anatomy_production_service.dart';
import 'package:future_project/services/exercise_anatomy_service.dart';

void main() {
  late List<CanonicalExercise> catalog;
  late AnatomyProductionService service;

  setUpAll(() {
    final json =
        jsonDecode(
              File(
                'assets/data/exercise_library/movekit_complete_catalog.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    catalog = (json['exercises'] as List)
        .map((item) => CanonicalExercise.fromJson(item as Map<String, dynamic>))
        .toList();
    service = AnatomyProductionService();
  });

  test('builds exactly 784 jobs and excludes all 20 awaiting records', () {
    final jobs = service.buildManifest(catalog);
    expect(catalog, hasLength(412));
    expect(
      catalog.where((item) => item.metadataStatus == 'awaiting_video_license'),
      hasLength(20),
    );
    expect(jobs, hasLength(784));
    expect(jobs.where((job) => job.sex == AnatomySex.male), hasLength(392));
    expect(jobs.where((job) => job.sex == AnatomySex.female), hasLength(392));
    final excludedIds = catalog
        .where((item) => item.metadataStatus == 'awaiting_video_license')
        .map((item) => item.canonicalId)
        .toSet();
    expect(jobs.any((job) => excludedIds.contains(job.canonicalId)), isFalse);
  });

  test('male and female jobs have deterministic separate destinations', () {
    final jobs = service.buildManifest(catalog);
    for (final job in jobs) {
      expect(
        job.outputPath,
        'assets/exercises/anatomy/${job.sex.name}/${job.canonicalId}.png',
      );
    }
    expect(jobs.map((job) => job.jobId).toSet(), hasLength(784));
  });

  test('active locked male V4 anatomy master hash is exact', () async {
    for (final template in <(String, String)>[
      (
        AnatomyProductionService.maleTemplatePath,
        AnatomyProductionService.maleTemplateSha256,
      ),
    ]) {
      final digest = await Process.run('certutil', <String>[
        '-hashfile',
        template.$1,
        'SHA256',
      ]);
      expect(digest.exitCode, 0);
      final actual = RegExp(
        r'\b[A-Fa-f0-9]{64}\b',
      ).firstMatch(digest.stdout.toString())?.group(0)?.toUpperCase();
      expect(actual, template.$2);
    }
  });

  test('all 784 jobs use only their sex-specific locked master', () {
    final jobs = service.buildManifest(catalog);
    final female = jobs.where((job) => job.sex == AnatomySex.female).toList();
    final male = jobs.where((job) => job.sex == AnatomySex.male).toList();
    expect(female, hasLength(392));
    expect(male, hasLength(392));
    expect(
      female.every(
        (job) =>
            job.templateId == AnatomyProductionService.femaleTemplateId &&
            job.templatePath == AnatomyProductionService.femaleTemplatePath &&
            job.templateSha256 == AnatomyProductionService.femaleTemplateSha256,
      ),
      isTrue,
    );
    expect(
      male.every(
        (job) =>
            job.templateId == AnatomyProductionService.maleTemplateId &&
            job.templatePath == AnatomyProductionService.maleTemplatePath &&
            job.templateSha256 ==
                AnatomyProductionService.maleTemplateSha256,
      ),
      isTrue,
    );
  });

  test('manifest ordering and rebuild are deterministic and idempotent', () {
    final first = service.buildManifest(catalog);
    final second = service.buildManifest(catalog);
    expect(
      first.map((job) => jsonEncode(job.toJson())),
      orderedEquals(second.map((job) => jsonEncode(job.toJson()))),
    );
  });

  test('approved existing assets are protected from generation', () {
    final job = service
        .buildManifest(catalog)
        .firstWhere(
          (item) =>
              item.exerciseName == 'Barbell Bench Press' &&
              item.sex == AnatomySex.male,
        );
    expect(job.status, AnatomyJobStatus.approvedExisting);
    expect(service.shouldGenerate(job), isFalse);
  });

  test('approval and rejection require pending human review', () {
    final approved = AnatomyGenerationJob.fromJson(<String, dynamic>{
      ...service.buildManifest(catalog).first.toJson(),
      'status': 'pending_review',
    });
    service.approve(approved);
    expect(approved.status, AnatomyJobStatus.approved);
    expect(service.catalogPatchForApproval(approved), <String, Object?>{
      '${approved.sex.name}_anatomy_asset': approved.outputPath,
      '${approved.sex.name}_anatomy_status': 'approved',
    });

    final rejected = AnatomyGenerationJob.fromJson(<String, dynamic>{
      ...service.buildManifest(catalog).last.toJson(),
      'status': 'pending_review',
    });
    service.reject(rejected, 'Labels need correction');
    expect(rejected.status, AnatomyJobStatus.rejected);
    expect(service.shouldGenerate(rejected), isTrue);
  });

  test('spend guard rejects unknown or excessive provider costs', () {
    expect(
      () => service.enforceSpendGuard(
        imageCount: 4,
        costPerImageUsd: null,
        maximumSpendUsd: 10,
      ),
      throwsStateError,
    );
    expect(
      () => service.enforceSpendGuard(
        imageCount: 784,
        costPerImageUsd: 0.05,
        maximumSpendUsd: 30,
      ),
      throwsStateError,
    );
    service.enforceSpendGuard(
      imageCount: 4,
      costPerImageUsd: 0.05,
      maximumSpendUsd: 0.20,
    );
  });

  test('failed validation reasons can never be blank', () {
    expect(service.validationFailureReason(null), isNotEmpty);
    expect(service.validationFailureReason(<String, Object?>{'valid': false}), isNotEmpty);
    expect(
      service.validationFailureReason(<String, Object?>{
        'valid': false,
        'missing_back_view': true,
        'summary': '',
      }),
      contains('missing back view'),
    );
  });

  test('female anatomy never falls back to a male asset', () {
    expect(
      ExerciseAnatomyService.resolve(
        profile: ExerciseAnatomyProfile.female,
        maleAsset: 'assets/exercises/anatomy/male/example.png',
        femaleAsset: null,
        legacyExerciseName: 'Barbell Bench Press',
      ),
      isNull,
    );
  });

  test('pending-review anatomy is not exposed at runtime', () {
    expect(
      ExerciseAnatomyService.resolveApproved(
        profile: ExerciseAnatomyProfile.male,
        maleAsset: 'assets/exercises/anatomy/male/example.png',
        maleStatus: 'pending_review',
        femaleAsset: null,
        femaleStatus: 'pending_generation',
        legacyExerciseName: 'Unknown exercise',
      ),
      isNull,
    );
  });

  test('saved manifest contains only catalog data and PNG destinations', () {
    final json =
        jsonDecode(
              File(
                'assets/data/exercise_library/anatomy_generation_manifest.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final jobs = json['jobs'] as List;
    expect(jobs, hasLength(784));
    expect(
      jobs.every(
        (dynamic item) =>
            (item as Map<String, dynamic>)['output_path'].toString().endsWith(
              '.png',
            ) &&
            !item.containsKey('description') &&
            !item.containsKey('video_asset'),
      ),
      isTrue,
    );
  });
}
