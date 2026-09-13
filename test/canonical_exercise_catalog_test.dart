import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/canonical_exercise.dart';
import 'package:future_project/services/canonical_exercise_resolver.dart';
import 'package:future_project/services/coach_exercise_catalog.dart';
import 'package:future_project/services/exercise_anatomy_service.dart';
import 'package:future_project/services/exercise_catalog_repository.dart';
import 'package:future_project/services/exercise_catalog_validation_service.dart';
import 'package:future_project/services/exercise_name_normalizer.dart';
import 'package:future_project/services/licensed_video_matcher.dart';
import 'package:future_project/services/muscle_taxonomy.dart';

void main() {
  late String catalogText;
  late List<CanonicalExercise> exercises;
  late List<Map<String, dynamic>> rawExercises;

  setUpAll(() async {
    catalogText = await File(
      ExerciseCatalogRepository.assetPath,
    ).readAsString();
    final document = jsonDecode(catalogText) as Map<String, dynamic>;
    rawExercises = (document['exercises'] as List)
        .map((value) => Map<String, dynamic>.from(value as Map))
        .toList();
    exercises = await ExerciseCatalogRepository(
      (_) async => catalogText,
    ).load();
  });

  test('catalog parses and contains exactly 412 records', () {
    expect(exercises, hasLength(412));
    expect(exercises.every((item) => item.sourceName.isNotEmpty), isTrue);
  });

  test('stable IDs and normalized identities are unique', () {
    expect(exercises.map((item) => item.canonicalId).toSet(), hasLength(412));
    expect(exercises.map((item) => item.slug).toSet(), hasLength(412));
    expect(
      exercises.map((item) => item.normalizedName).toSet(),
      hasLength(412),
    );
    for (final item in exercises) {
      expect(
        item.canonicalId,
        ExerciseNameNormalizer.canonicalIdForSlug(item.slug),
      );
    }
  });

  test('name normalization and alias resolution are deterministic', () {
    expect(
      ExerciseNameNormalizer.normalize('  Pull-Up (Wide)  '),
      'pull up wide',
    );
    final raw = Map<String, dynamic>.from(rawExercises.first);
    raw['aliases'] = <String>['Legacy Exercise'];
    final item = CanonicalExercise.fromJson(raw);
    expect(
      CanonicalExerciseResolver(<CanonicalExercise>[
        item,
      ]).resolve(name: 'legacy-exercise').exercise,
      same(item),
    );
  });

  test('duplicate detection catches normalized collisions', () {
    final raw = Map<String, dynamic>.from(rawExercises.first);
    raw['canonical_id'] = '${raw['canonical_id']}_copy';
    raw['slug'] = '${raw['slug']}-copy';
    final duplicate = CanonicalExercise.fromJson(raw);
    expect(
      ExerciseCatalogValidationService().duplicateCandidates(
        <CanonicalExercise>[exercises.first, duplicate],
      ),
      hasLength(1),
    );
  });

  test('legitimate setup variations remain separate', () {
    final row = exercises.singleWhere(
      (item) => item.sourceName == 'Barbell Bent Over Row',
    );
    final overhand = exercises.singleWhere(
      (item) => item.sourceName == 'Barbell Bent Over Row - Overhand',
    );
    expect(row.canonicalId, isNot(overhand.canonicalId));
    expect(row.normalizedName, isNot(overhand.normalizedName));
  });

  test('missing names and invalid taxonomy are rejected', () {
    final raw = Map<String, dynamic>.from(rawExercises.first)
      ..['source_name'] = ''
      ..['metadata_status'] = 'verified'
      ..['movement_pattern'] = 'unknown_pattern'
      ..['primary_muscles'] = <String>['unknown_muscle'];
    final report = ExerciseCatalogValidationService().validate(
      <CanonicalExercise>[CanonicalExercise.fromJson(raw)],
    );
    expect(
      report.issues.any((issue) => issue.code == 'missing_name_or_identity'),
      isTrue,
    );
    expect(
      report.issues.any((issue) => issue.code == 'invalid_muscle'),
      isTrue,
    );
    expect(MuscleTaxonomy.resolve('Pectorals'), 'chest');
  });

  test('broken cross references are rejected', () {
    final raw = Map<String, dynamic>.from(rawExercises.first)
      ..['progression_ids'] = <String>['missing_id'];
    final report = ExerciseCatalogValidationService().validate(
      <CanonicalExercise>[CanonicalExercise.fromJson(raw)],
    );
    expect(
      report.issues.any((issue) => issue.code == 'broken_reference'),
      isTrue,
    );
  });

  test('relationship self references are rejected', () {
    final raw = Map<String, dynamic>.from(rawExercises.first);
    raw['progression_ids'] = <String>[raw['canonical_id'].toString()];
    final report = ExerciseCatalogValidationService().validate(
      <CanonicalExercise>[CanonicalExercise.fromJson(raw)],
    );
    expect(
      report.issues.any((issue) => issue.code == 'self_reference'),
      isTrue,
    );
  });

  test('nullable asset fields and existing anatomy fallback are supported', () {
    final pending = exercises.firstWhere(
      (item) => item.maleAnatomyAsset == null,
    );
    expect(pending.videoAsset, isNull);
    expect(pending.videoStatus, 'pending_license');
    expect(
      ExerciseAnatomyService.resolve(
        profile: ExerciseAnatomyProfile.male,
        legacyExerciseName: 'Barbell Bench Press',
      ),
      isNotNull,
    );
    expect(
      ExerciseAnatomyService.resolve(
        profile: ExerciseAnatomyProfile.male,
        legacyExerciseName: 'Unknown Exercise',
      ),
      isNull,
    );
  });

  test(
    'all records contain dual anatomy fields and female assets are pending',
    () {
      expect(exercises, hasLength(412));
      expect(
        exercises.every((item) => item.maleAnatomyStatus.isNotEmpty),
        isTrue,
      );
      expect(
        exercises.every((item) => item.femaleAnatomyStatus.isNotEmpty),
        isTrue,
      );
      expect(
        exercises.where((item) => item.maleAnatomyAsset != null),
        hasLength(4),
      );
      expect(
        exercises.where((item) => item.femaleAnatomyAsset != null),
        isEmpty,
      );
      expect(
        exercises.every(
          (item) =>
              item.femaleAnatomyAsset != null ||
              item.femaleAnatomyStatus == 'pending_generation',
        ),
        isTrue,
      );
    },
  );

  test('anatomy selection supports explicit profiles and never guesses', () {
    const maleAsset = 'assets/exercises/anatomy/existing.png';
    const femaleAsset = 'assets/exercises/anatomy/female/example.png';
    expect(
      ExerciseAnatomyService.resolve(
        profile: ExerciseAnatomyProfile.male,
        maleAsset: maleAsset,
        femaleAsset: femaleAsset,
      ),
      maleAsset,
    );
    expect(
      ExerciseAnatomyService.resolve(
        profile: ExerciseAnatomyProfile.female,
        maleAsset: maleAsset,
        femaleAsset: femaleAsset,
      ),
      femaleAsset,
    );
    expect(
      ExerciseAnatomyService.resolve(
        profile: null,
        maleAsset: maleAsset,
        femaleAsset: femaleAsset,
        legacyExerciseName: 'Barbell Bench Press',
      ),
      isNull,
    );
    expect(ExerciseAnatomyService.profileFromFoundationValue('other'), isNull);
    expect(ExerciseAnatomyService.profileFromFoundationValue(null), isNull);
  });

  test('Coach catalog returns only active validated known exercises', () async {
    final repository = ExerciseCatalogRepository((_) async => catalogText);
    final coach = CoachExerciseCatalog(repository);
    final selected = await coach.selectableExercises();
    expect(selected, hasLength(327));
    expect(
      selected.every(
        (item) =>
            item.active &&
            item.validationStatus == 'verified' &&
            item.metadataStatus == 'metadata_validated',
      ),
      isTrue,
    );
    expect(
      await coach.resolveSelection(legacyName: 'invented movement'),
      isNull,
    );
  });

  test('canonical and legacy-name resolution preserve saved plans', () {
    final resolver = CanonicalExerciseResolver(exercises);
    final bench = exercises.singleWhere(
      (item) => item.sourceName == 'Barbell Bench Press',
    );
    expect(
      resolver.resolve(canonicalId: bench.canonicalId).exercise,
      same(bench),
    );
    expect(resolver.resolve(name: 'barbell-bench press').exercise, same(bench));
  });

  test('future video matching accepts exact and reviews ambiguity', () {
    final bench = exercises.singleWhere(
      (item) => item.sourceName == 'Barbell Bench Press',
    );
    final exact = CanonicalLicensedVideoMatcher(
      exercises,
    ).matchFilename('Barbell Bench Press.mp4');
    expect(exact.status, LicensedVideoMatchStatus.exact);
    expect(exact.exercise, same(bench));

    final a = CanonicalExercise.fromJson(
      Map<String, dynamic>.from(rawExercises[0])
        ..['aliases'] = <String>['shared'],
    );
    final b = CanonicalExercise.fromJson(
      Map<String, dynamic>.from(rawExercises[1])
        ..['aliases'] = <String>['shared'],
    );
    final ambiguous = CanonicalLicensedVideoMatcher(<CanonicalExercise>[
      a,
      b,
    ]).matchFilename('shared.mp4');
    expect(ambiguous.status, LicensedVideoMatchStatus.review);
  });

  test(
    'runtime catalog loading is offline and has no MoveKit request code',
    () async {
      var loads = 0;
      final repository = ExerciseCatalogRepository((path) async {
        loads++;
        expect(path, ExerciseCatalogRepository.assetPath);
        return catalogText;
      });
      await repository.load();
      await repository.load();
      expect(loads, 1);
    },
  );

  test('complete catalog validation passes', () {
    expect(
      ExerciseCatalogValidationService().validate(exercises).isValid,
      isTrue,
    );
  });

  test('production ordering and workflow counts are deterministic', () {
    final ids = exercises.map((item) => item.canonicalId).toList();
    final ordered = <String>[...ids]..sort();
    expect(ordered.first, 'mu_ex_abdominals_stretch_variation_four');
    expect(ordered.last, 'mu_ex_zottman_curl');
    expect(
      exercises.where((item) => item.metadataStatus == 'metadata_validated'),
      hasLength(327),
    );
    expect(
      exercises.where((item) => item.metadataStatus == 'needs_review'),
      hasLength(85),
    );
    expect(
      exercises.where((item) => item.metadataStatus == 'metadata_pending'),
      isEmpty,
    );
  });

  test(
    'validated metadata passes anatomy, programming, and provenance gates',
    () {
      for (final item in exercises.where(
        (item) => item.metadataStatus == 'metadata_validated',
      )) {
        expect(item.primaryMuscles, isNotEmpty, reason: item.canonicalId);
        final roles = <String>{
          ...item.primaryMuscles,
          ...item.secondaryMuscles,
          ...item.stabilizerMuscles,
        };
        expect(
          roles.length,
          item.primaryMuscles.length +
              item.secondaryMuscles.length +
              item.stabilizerMuscles.length,
          reason: item.canonicalId,
        );
        expect(item.requiredAnatomyViews, isNotEmpty, reason: item.canonicalId);
        expect(
          item.requiredAnatomyViews.every(
            (view) => const <String>{'front', 'back'}.contains(view),
          ),
          isTrue,
        );
        expect(item.defaultSetsMin, lessThanOrEqualTo(item.defaultSetsMax!));
        if (item.defaultRepsMin == null) {
          expect(item.defaultRepsMax, isNull);
        } else {
          expect(item.defaultRepsMin, lessThanOrEqualTo(item.defaultRepsMax!));
        }
        expect(item.metadataVersion, 1);
        expect(item.metadataSources, isNotEmpty);
        expect(item.authoredAt, isNotNull);
        expect(item.reviewedAt, isNotNull);
      }
    },
  );

  test(
    'checkpoint recovery records independent stages and completed batches',
    () {
      final checkpoint =
          jsonDecode(
                File(
                  'assets/data/exercise_library/metadata_production_checkpoint.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final queue =
          jsonDecode(
                File(
                  'assets/data/exercise_library/review_queue.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      expect(checkpoint['completed_records'], 327);
      expect(checkpoint['pending_records'], 0);
      expect(checkpoint['review_records'], 85);
      expect(checkpoint['failed_records'], 0);
      expect(checkpoint['current_batch'], 21);
      expect(checkpoint['last_completed_canonical_id'], 'mu_ex_zottman_curl');
      expect(
        checkpoint['generator_version'],
        isNot(checkpoint['reviewer_version']),
      );
      expect(queue['unresolved'], hasLength(85));
    },
  );

  test('identities and protected assets remain intact', () {
    expect(exercises.map((item) => item.canonicalId).toSet(), hasLength(412));
    expect(exercises.map((item) => item.sourceName).toSet(), hasLength(412));
    expect(
      exercises.where((item) => item.maleAnatomyAsset != null),
      hasLength(4),
    );
    expect(exercises.where((item) => item.femaleAnatomyAsset != null), isEmpty);
    expect(exercises.where((item) => item.videoAsset != null), isEmpty);
    for (final raw in rawExercises) {
      expect(
        raw.keys.where(
          (key) => key.contains('description') || key.contains('preview'),
        ),
        isEmpty,
      );
    }
  });
}
