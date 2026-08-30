import 'package:flutter/foundation.dart';
import 'package:future_project/models/future_self_generation.dart';
import 'package:future_project/models/future_self_photo_validation.dart';

class FutureSelfPhotoValidator {
  static const int maximumBytes = 10 * 1024 * 1024;
  static const int minimumUsefulBytes = 24 * 1024;

  const FutureSelfPhotoValidator();

  FutureSelfPhotoValidationResult validate({
    required Uint8List bytes,
    required FutureSelfInputMode mode,
    FutureSelfPhotoAnalysis? analysis,
  }) {
    final issues = <FutureSelfPhotoValidationIssue>[];
    if (bytes.isEmpty) issues.add(FutureSelfPhotoValidationIssue.emptyImage);
    if (bytes.length > maximumBytes) {
      issues.add(FutureSelfPhotoValidationIssue.imageTooLarge);
    }
    if (bytes.isNotEmpty && bytes.length < minimumUsefulBytes) {
      issues.add(FutureSelfPhotoValidationIssue.imageTooSmall);
    }
    if (bytes.isNotEmpty && !_isSupported(bytes)) {
      issues.add(FutureSelfPhotoValidationIssue.unsupportedImage);
    }
    if (analysis == null) {
      final technicalFailure = issues.isNotEmpty;
      return FutureSelfPhotoValidationResult(
        canGenerate: !technicalFailure,
        needsAutomatedReview: !technicalFailure,
        issues: [
          ...issues,
          if (!technicalFailure)
            FutureSelfPhotoValidationIssue.automatedReviewRequired,
        ],
        userMessage: technicalFailure ? _message(issues.first) : null,
      );
    }
    if (analysis.sexualContent == true) {
      issues.add(FutureSelfPhotoValidationIssue.sexualContent);
    }
    if (analysis.personCount == null) {
      issues.add(FutureSelfPhotoValidationIssue.personCountUnclear);
    } else if (analysis.personCount! > 1) {
      issues.add(FutureSelfPhotoValidationIssue.multiplePeople);
    } else if (analysis.personCount == 0) {
      issues.add(FutureSelfPhotoValidationIssue.faceNotVisible);
    }
    if (analysis.faceVisible != true) {
      issues.add(FutureSelfPhotoValidationIssue.faceNotVisible);
    }
    if (mode == FutureSelfInputMode.fullBody &&
        analysis.fullBodyVisible != true) {
      issues.add(FutureSelfPhotoValidationIssue.fullBodyNotVisible);
    }
    if (analysis.excessivelyCropped == true) {
      issues.add(FutureSelfPhotoValidationIssue.excessivelyCropped);
    }
    if (analysis.usablePose == false) {
      issues.add(FutureSelfPhotoValidationIssue.unusablePose);
    }
    if (analysis.adequateLighting == false) {
      issues.add(FutureSelfPhotoValidationIssue.poorLighting);
    }
    if (analysis.ordinaryNonSexualClothing == false) {
      issues.add(FutureSelfPhotoValidationIssue.unsuitableClothing);
    }
    return FutureSelfPhotoValidationResult(
      canGenerate: issues.isEmpty,
      needsAutomatedReview: false,
      issues: List.unmodifiable(issues),
      userMessage: issues.isEmpty ? null : _message(issues.first),
    );
  }

  bool _isSupported(Uint8List bytes) =>
      (bytes.length >= 3 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xD8 &&
          bytes[2] == 0xFF) ||
      (bytes.length >= 8 &&
          bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) ||
      (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50);

  String _message(FutureSelfPhotoValidationIssue issue) => switch (issue) {
    FutureSelfPhotoValidationIssue.multiplePeople =>
      'Only one person should be in the photo.',
    FutureSelfPhotoValidationIssue.faceNotVisible =>
      'Your face needs to be visible.',
    FutureSelfPhotoValidationIssue.fullBodyNotVisible ||
    FutureSelfPhotoValidationIssue.excessivelyCropped =>
      'Your full body isn\'t visible.',
    FutureSelfPhotoValidationIssue.unsuitableClothing ||
    FutureSelfPhotoValidationIssue.sexualContent =>
      'Use a photo in regular workout clothing.',
    FutureSelfPhotoValidationIssue.poorLighting ||
    FutureSelfPhotoValidationIssue.imageTooSmall =>
      'Please use a clearer photo.',
    FutureSelfPhotoValidationIssue.unusablePose =>
      'Use a natural pose facing the camera.',
    FutureSelfPhotoValidationIssue.imageTooLarge =>
      'Please choose a photo smaller than 10 MB.',
    FutureSelfPhotoValidationIssue.emptyImage ||
    FutureSelfPhotoValidationIssue.unsupportedImage =>
      'Please choose a JPG, PNG, or WebP photo.',
    _ => 'Please choose another clear photo.',
  };
}
