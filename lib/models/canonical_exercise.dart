class CanonicalExercise {
  final String canonicalId;
  final String slug;
  final String displayName;
  final String normalizedName;
  final List<String> aliases;
  final String sourceName;
  final String sourceCatalog;
  final String sourcePublicUrl;
  final String? publicCategory;
  final bool active;
  final String metadataStatus;
  final String validationStatus;
  final String? reviewReason;
  final String? category;
  final String? bodyRegion;
  final String? movementPattern;
  final List<String> equipment;
  final String? exerciseType;
  final String? mechanics;
  final String? laterality;
  final String? difficulty;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> stabilizerMuscles;
  final List<String> trainingGoals;
  final List<String> suitableLocations;
  final List<String> setupRequirements;
  final List<String> contraindicationTags;
  final List<String> regressionIds;
  final List<String> progressionIds;
  final List<String> alternativeIds;
  final List<String> coachingCues;
  final List<String> commonMistakes;
  final List<String> safetyNotes;
  final int? defaultSetsMin;
  final int? defaultSetsMax;
  final int? defaultRepsMin;
  final int? defaultRepsMax;
  final int? defaultRestSecondsMin;
  final int? defaultRestSecondsMax;
  final String? tempoGuidance;
  final String? maleAnatomyAsset;
  final String maleAnatomyStatus;
  final String? femaleAnatomyAsset;
  final String femaleAnatomyStatus;
  final String? videoAsset;
  final String videoStatus;
  final String? futureVendorAssetKey;

  const CanonicalExercise({
    required this.canonicalId,
    required this.slug,
    required this.displayName,
    required this.normalizedName,
    required this.aliases,
    required this.sourceName,
    required this.sourceCatalog,
    required this.sourcePublicUrl,
    required this.publicCategory,
    required this.active,
    required this.metadataStatus,
    required this.validationStatus,
    required this.reviewReason,
    required this.category,
    required this.bodyRegion,
    required this.movementPattern,
    required this.equipment,
    required this.exerciseType,
    required this.mechanics,
    required this.laterality,
    required this.difficulty,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.stabilizerMuscles,
    required this.trainingGoals,
    required this.suitableLocations,
    required this.setupRequirements,
    required this.contraindicationTags,
    required this.regressionIds,
    required this.progressionIds,
    required this.alternativeIds,
    required this.coachingCues,
    required this.commonMistakes,
    required this.safetyNotes,
    required this.defaultSetsMin,
    required this.defaultSetsMax,
    required this.defaultRepsMin,
    required this.defaultRepsMax,
    required this.defaultRestSecondsMin,
    required this.defaultRestSecondsMax,
    required this.tempoGuidance,
    required this.maleAnatomyAsset,
    required this.maleAnatomyStatus,
    required this.femaleAnatomyAsset,
    required this.femaleAnatomyStatus,
    required this.videoAsset,
    required this.videoStatus,
    required this.futureVendorAssetKey,
  });

  bool get isCoachSelectable => active && validationStatus == 'verified';

  String get futureMaleAnatomyPath =>
      'assets/exercises/anatomy/male/$canonicalId.png';
  String get futureFemaleAnatomyPath =>
      'assets/exercises/anatomy/female/$canonicalId.png';

  factory CanonicalExercise.fromJson(Map<String, dynamic> json) {
    List<String> strings(String key) =>
        ((json[key] as List?) ?? const <dynamic>[])
            .map((value) => value.toString())
            .toList(growable: false);
    int? integer(String key) => (json[key] as num?)?.toInt();
    String? optional(String key) {
      final value = json[key]?.toString().trim();
      return value == null || value.isEmpty ? null : value;
    }

    return CanonicalExercise(
      canonicalId: json['canonical_id']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      normalizedName: json['normalized_name']?.toString() ?? '',
      aliases: strings('aliases'),
      sourceName: json['source_name']?.toString() ?? '',
      sourceCatalog: json['source_catalog']?.toString() ?? '',
      sourcePublicUrl: json['source_public_url']?.toString() ?? '',
      publicCategory: optional('public_category'),
      active: json['active'] == true,
      metadataStatus: json['metadata_status']?.toString() ?? '',
      validationStatus: json['validation_status']?.toString() ?? '',
      reviewReason: optional('review_reason'),
      category: optional('category'),
      bodyRegion: optional('body_region'),
      movementPattern: optional('movement_pattern'),
      equipment: strings('equipment'),
      exerciseType: optional('exercise_type'),
      mechanics: optional('mechanics'),
      laterality: optional('laterality'),
      difficulty: optional('difficulty'),
      primaryMuscles: strings('primary_muscles'),
      secondaryMuscles: strings('secondary_muscles'),
      stabilizerMuscles: strings('stabilizer_muscles'),
      trainingGoals: strings('training_goals'),
      suitableLocations: strings('suitable_locations'),
      setupRequirements: strings('setup_requirements'),
      contraindicationTags: strings('contraindication_tags'),
      regressionIds: strings('regression_ids'),
      progressionIds: strings('progression_ids'),
      alternativeIds: strings('alternative_ids'),
      coachingCues: strings('coaching_cues'),
      commonMistakes: strings('common_mistakes'),
      safetyNotes: strings('safety_notes'),
      defaultSetsMin: integer('default_sets_min'),
      defaultSetsMax: integer('default_sets_max'),
      defaultRepsMin: integer('default_reps_min'),
      defaultRepsMax: integer('default_reps_max'),
      defaultRestSecondsMin: integer('default_rest_seconds_min'),
      defaultRestSecondsMax: integer('default_rest_seconds_max'),
      tempoGuidance: optional('tempo_guidance'),
      maleAnatomyAsset:
          optional('male_anatomy_asset') ?? optional('anatomy_asset'),
      maleAnatomyStatus:
          json['male_anatomy_status']?.toString() ??
          json['anatomy_status']?.toString() ??
          'pending_generation',
      femaleAnatomyAsset: optional('female_anatomy_asset'),
      femaleAnatomyStatus:
          json['female_anatomy_status']?.toString() ?? 'pending_generation',
      videoAsset: optional('video_asset'),
      videoStatus: json['video_status']?.toString() ?? '',
      futureVendorAssetKey: optional('future_vendor_asset_key'),
    );
  }
}
