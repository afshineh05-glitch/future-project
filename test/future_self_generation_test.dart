import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/future_body_template.dart';
import 'package:future_project/models/future_self_generation.dart';
import 'package:future_project/models/future_self_photo_validation.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/services/future_body_template_resolver.dart';
import 'package:future_project/services/future_self_photo_validator.dart';

void main() {
  const validator = FutureSelfPhotoValidator();
  const resolver = FutureBodyTemplateResolver();
  final validJpeg = Uint8List.fromList([
    0xFF,
    0xD8,
    0xFF,
    ...List.filled(FutureSelfPhotoValidator.minimumUsefulBytes, 1),
  ]);

  FutureSelfGenerationRequest request(FutureSelfInputMode mode) =>
      FutureSelfGenerationRequest(
        userId: 'authenticated-user',
        inputMode: mode,
        currentPhotoPath: 'authenticated-user/current/photo.jpg',
        bodyTemplateId: mode == FutureSelfInputMode.faceOnly
            ? 'neutral-template-v1'
            : null,
        primaryGoal: 'Build muscle',
        desiredFeelings: const ['Strong', 'Confident'],
        futureIdentity: 'I train consistently and feel capable.',
        age: 32,
        profileCategory: 'female',
        heightCm: 170,
        weightKg: 70,
        targetWeightKg: 74,
        measurementsCm: const {'waist': 75, 'arm': 30},
        trainingLevel: 'beginner',
      );

  test('faceOnly request contains mode, template, and canonical context', () {
    final body = request(FutureSelfInputMode.faceOnly).toMap();

    expect(body['inputMode'], 'face_only');
    expect(body['bodyTemplateId'], 'neutral-template-v1');
    expect(body['age'], 32);
    expect(body['heightCm'], 170);
    expect(body, isNot(contains('userId')));
  });

  test('fullBody request uses actual photo without a body template', () {
    final body = request(FutureSelfInputMode.fullBody).toMap();

    expect(body['inputMode'], 'full_body');
    expect(body, isNot(contains('bodyTemplateId')));
    expect(body['currentPhotoPath'], contains('/current/'));
  });

  test('future horizon is fixed at eight months', () {
    expect(
      request(FutureSelfInputMode.fullBody).toMap()['futureHorizonMonths'],
      8,
    );
    expect(FutureSelfGenerationRequest.fixedFutureHorizonMonths, 8);
  });

  test('existing V1 photo and result default to fullBody', () {
    final vision = FutureVision.fromMap({
      'user_id': 'user',
      'primary_goal': 'fitness',
      'future_identity': 'Fitter',
      'desired_feelings': <String>[],
      'vision_statement': 'Future',
      'current_photo_path': 'user/current/photo.jpg',
      'future_self_image_path': 'user/future/photo.png',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(vision.futureSelfInputMode, FutureSelfInputMode.fullBody);
    expect(vision.currentPhotoInputMode, FutureSelfInputMode.fullBody);
    expect(vision.futureSelfGeneratedInputMode, FutureSelfInputMode.fullBody);
  });

  test('new Vision without V1 photos requires an explicit mode choice', () {
    final vision = FutureVision.fromMap({
      'user_id': 'user',
      'primary_goal': 'fitness',
      'future_identity': 'Fitter',
      'desired_feelings': <String>[],
      'vision_statement': 'Future',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

    expect(vision.futureSelfInputMode, isNull);
  });

  test('full-body invalid photo blocks generation', () {
    final result = validator.validate(
      bytes: validJpeg,
      mode: FutureSelfInputMode.fullBody,
      analysis: const FutureSelfPhotoAnalysis(
        personCount: 1,
        faceVisible: true,
        fullBodyVisible: false,
        excessivelyCropped: true,
        usablePose: true,
        adequateLighting: true,
        ordinaryNonSexualClothing: true,
        sexualContent: false,
      ),
    );

    expect(result.canGenerate, isFalse);
    expect(result.userMessage, 'Your full body isn\'t visible.');
  });

  test('face-only missing face blocks generation', () {
    final result = validator.validate(
      bytes: validJpeg,
      mode: FutureSelfInputMode.faceOnly,
      analysis: const FutureSelfPhotoAnalysis(
        personCount: 1,
        faceVisible: false,
        fullBodyVisible: false,
        ordinaryNonSexualClothing: true,
        sexualContent: false,
      ),
    );

    expect(result.canGenerate, isFalse);
    expect(result.userMessage, 'Your face needs to be visible.');
  });

  test('no body template asset produces a safe explicit failure', () {
    expect(
      () => resolver.requireAvailable(primaryGoal: 'build_muscle'),
      throwsA(isA<FutureBodyTemplateUnavailableException>()),
    );
  });

  test('regenerate request preserves mode and eight-month horizon', () {
    final original = request(FutureSelfInputMode.fullBody).toMap();
    final regenerated = request(FutureSelfInputMode.fullBody).toMap();

    expect(regenerated['inputMode'], original['inputMode']);
    expect(regenerated['currentPhotoPath'], original['currentPhotoPath']);
    expect(regenerated['futureHorizonMonths'], 8);
  });

  test('sexual-content rejection uses safe product language', () {
    final result = validator.validate(
      bytes: validJpeg,
      mode: FutureSelfInputMode.fullBody,
      analysis: const FutureSelfPhotoAnalysis(
        personCount: 1,
        faceVisible: true,
        fullBodyVisible: true,
        ordinaryNonSexualClothing: false,
        sexualContent: true,
      ),
    );

    expect(result.canGenerate, isFalse);
    expect(result.userMessage, 'Use a photo in regular workout clothing.');
  });
}
