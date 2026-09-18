import '../models/anatomy_generation_job.dart';

class AnatomyGenerationRequest {
  const AnatomyGenerationRequest({required this.job, required this.prompt});
  final AnatomyGenerationJob job;
  final String prompt;
}

class AnatomyGenerationResponse {
  const AnatomyGenerationResponse({required this.outputPath});
  final String outputPath;
}

abstract interface class AnatomyImageGenerationProvider {
  String get providerId;
  double? get estimatedCostUsdPerImage;
  Future<AnatomyGenerationResponse> generate(AnatomyGenerationRequest request);
}

class UnconfiguredAnatomyImageGenerationProvider
    implements AnatomyImageGenerationProvider {
  const UnconfiguredAnatomyImageGenerationProvider();
  @override
  String get providerId => 'unconfigured';
  @override
  double? get estimatedCostUsdPerImage => null;
  @override
  Future<AnatomyGenerationResponse> generate(
    AnatomyGenerationRequest request,
  ) => throw StateError('No anatomy image-generation provider is configured.');
}
