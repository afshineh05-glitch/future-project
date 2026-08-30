enum FutureSelfInputMode { faceOnly, fullBody }

extension FutureSelfInputModeWire on FutureSelfInputMode {
  String get wireValue => switch (this) {
    FutureSelfInputMode.faceOnly => 'face_only',
    FutureSelfInputMode.fullBody => 'full_body',
  };

  static FutureSelfInputMode fromWire(String? value) => switch (value) {
    'face_only' => FutureSelfInputMode.faceOnly,
    _ => FutureSelfInputMode.fullBody,
  };
}

class FutureSelfGenerationRequest {
  static const int fixedFutureHorizonMonths = 8;

  final String userId;
  final FutureSelfInputMode inputMode;
  final String currentPhotoPath;
  final String? bodyTemplateId;
  final String primaryGoal;
  final List<String> desiredFeelings;
  final String futureIdentity;
  final int? age;
  final String? profileCategory;
  final double? heightCm;
  final double? weightKg;
  final double? targetWeightKg;
  final Map<String, double> measurementsCm;
  final String? trainingLevel;
  final int futureHorizonMonths;

  const FutureSelfGenerationRequest({
    required this.userId,
    required this.inputMode,
    required this.currentPhotoPath,
    this.bodyTemplateId,
    required this.primaryGoal,
    required this.desiredFeelings,
    required this.futureIdentity,
    this.age,
    this.profileCategory,
    this.heightCm,
    this.weightKg,
    this.targetWeightKg,
    this.measurementsCm = const {},
    this.trainingLevel,
    this.futureHorizonMonths = fixedFutureHorizonMonths,
  }) : assert(futureHorizonMonths == fixedFutureHorizonMonths);

  Map<String, dynamic> toMap() => {
    'inputMode': inputMode.wireValue,
    'currentPhotoPath': currentPhotoPath,
    if (bodyTemplateId != null) 'bodyTemplateId': bodyTemplateId,
    'primaryGoal': primaryGoal,
    'desiredFeelings': desiredFeelings,
    'futureIdentity': futureIdentity,
    'age': age,
    'profileCategory': profileCategory,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'targetWeightKg': targetWeightKg,
    'measurementsCm': measurementsCm,
    'trainingLevel': trainingLevel,
    'futureHorizonMonths': fixedFutureHorizonMonths,
    'transformationGuidance': _transformationGuidance(primaryGoal),
  };

  static String _transformationGuidance(String goal) => switch (goal
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[\s-]+'), '_')) {
    'build_muscle' || 'muscle_gain' =>
      'Noticeably more developed shoulders, chest, arms, back and legs with natural athletic proportions appropriate to eight months.',
    'fat_loss' || 'lose_fat' =>
      'A visibly leaner silhouette and realistic waist reduction while preserving the natural frame.',
    'become_stronger' || 'athletic_performance' =>
      'A stronger athletic appearance with moderate, believable muscular development.',
    'improve_fitness' || 'fitness' =>
      'A fitter body composition with moderate definition and an athletic appearance.',
    'feel_healthier' || 'health' =>
      'A subtle but visible healthier and fitter presentation without dramatic reshaping.',
    _ => 'A visible, plausible and anatomically stable fitness change.',
  };
}
