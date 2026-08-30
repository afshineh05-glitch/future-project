class FutureBodyTemplate {
  final String id;
  final String profileCategory;
  final String heightBand;
  final String weightBand;
  final String buildCategory;
  final String? privateAssetReference;

  const FutureBodyTemplate({
    required this.id,
    required this.profileCategory,
    required this.heightBand,
    required this.weightBand,
    required this.buildCategory,
    this.privateAssetReference,
  });

  bool get hasVisualAsset => privateAssetReference?.isNotEmpty == true;
}

class FutureBodyTemplateUnavailableException implements Exception {
  const FutureBodyTemplateUnavailableException();

  @override
  String toString() =>
      'No predefined body-template visual is available for this profile yet.';
}
