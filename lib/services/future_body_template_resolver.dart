import 'package:future_project/models/future_body_template.dart';

class FutureBodyTemplateResolver {
  const FutureBodyTemplateResolver();

  FutureBodyTemplate resolve({
    String? profileCategory,
    double? heightCm,
    double? weightKg,
    String? bodyType,
    required String primaryGoal,
  }) {
    final category = switch (profileCategory?.toLowerCase().trim()) {
      'female' || 'woman' => 'feminine',
      'male' || 'man' => 'masculine',
      _ => 'neutral',
    };
    final heightBand = switch (heightCm) {
      final value? when value < 160 => 'short',
      final value? when value >= 185 => 'tall',
      _ => 'average',
    };
    final bmi = heightCm != null && heightCm > 0 && weightKg != null
        ? weightKg / ((heightCm / 100) * (heightCm / 100))
        : null;
    final weightBand = switch (bmi) {
      final value? when value < 20 => 'lighter',
      final value? when value >= 28 => 'higher',
      _ => 'middle',
    };
    final build = _safeBuild(bodyType);
    return FutureBodyTemplate(
      id: 'neutral-$category-$heightBand-$weightBand-$build-v1',
      profileCategory: category,
      heightBand: heightBand,
      weightBand: weightBand,
      buildCategory: build,
      // V2 architecture is ready, but no approved private template assets
      // currently exist in this project.
      privateAssetReference: null,
    );
  }

  FutureBodyTemplate requireAvailable({
    String? profileCategory,
    double? heightCm,
    double? weightKg,
    String? bodyType,
    required String primaryGoal,
  }) {
    final template = resolve(
      profileCategory: profileCategory,
      heightCm: heightCm,
      weightKg: weightKg,
      bodyType: bodyType,
      primaryGoal: primaryGoal,
    );
    if (!template.hasVisualAsset) {
      throw const FutureBodyTemplateUnavailableException();
    }
    return template;
  }

  String _safeBuild(String? value) => switch (value?.toLowerCase().trim()) {
    'slim' || 'lean' => 'lean',
    'broad' || 'stocky' => 'broad',
    _ => 'average',
  };
}
