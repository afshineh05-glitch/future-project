enum FutureSelfPhotoValidationIssue {
  emptyImage,
  unsupportedImage,
  imageTooLarge,
  imageTooSmall,
  personCountUnclear,
  multiplePeople,
  faceNotVisible,
  fullBodyNotVisible,
  excessivelyCropped,
  unusablePose,
  poorLighting,
  unsuitableClothing,
  sexualContent,
  automatedReviewRequired,
}

class FutureSelfPhotoAnalysis {
  final int? personCount;
  final bool? faceVisible;
  final bool? fullBodyVisible;
  final bool? excessivelyCropped;
  final bool? usablePose;
  final bool? adequateLighting;
  final bool? ordinaryNonSexualClothing;
  final bool? sexualContent;

  const FutureSelfPhotoAnalysis({
    this.personCount,
    this.faceVisible,
    this.fullBodyVisible,
    this.excessivelyCropped,
    this.usablePose,
    this.adequateLighting,
    this.ordinaryNonSexualClothing,
    this.sexualContent,
  });
}

class FutureSelfPhotoValidationResult {
  final bool canGenerate;
  final bool needsAutomatedReview;
  final List<FutureSelfPhotoValidationIssue> issues;
  final String? userMessage;

  const FutureSelfPhotoValidationResult({
    required this.canGenerate,
    required this.needsAutomatedReview,
    required this.issues,
    this.userMessage,
  });
}
