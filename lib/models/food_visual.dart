enum FoodVisualStatus { ready, unavailable }

class FoodVisual {
  final FoodVisualStatus status;
  final String? foodKey;
  final String displayName;
  final String? imageUrl;
  final String source;
  final bool cached;
  final String? errorCode;
  final String? message;

  const FoodVisual({
    required this.status,
    required this.foodKey,
    required this.displayName,
    required this.imageUrl,
    required this.source,
    required this.cached,
    this.errorCode,
    this.message,
  });

  bool get isReady =>
      status == FoodVisualStatus.ready && imageUrl?.trim().isNotEmpty == true;

  factory FoodVisual.fromMap(Map<String, dynamic> map) {
    final imageUrl = map['image_url']?.toString();
    final error = map['error'];
    final errorMap = error is Map
        ? Map<String, dynamic>.from(error)
        : const <String, dynamic>{};

    return FoodVisual(
      status: imageUrl?.trim().isNotEmpty == true
          ? FoodVisualStatus.ready
          : FoodVisualStatus.unavailable,
      foodKey: map['food_key']?.toString(),
      displayName: map['display_name']?.toString() ?? '',
      imageUrl: imageUrl,
      source: map['source']?.toString() ?? 'fallback',
      cached: map['cached'] == true,
      errorCode: errorMap['code']?.toString(),
      message: errorMap['message']?.toString(),
    );
  }

  factory FoodVisual.unavailable({
    required String displayName,
    required String message,
    String? errorCode,
  }) {
    return FoodVisual(
      status: FoodVisualStatus.unavailable,
      foodKey: null,
      displayName: displayName,
      imageUrl: null,
      source: 'fallback',
      cached: false,
      errorCode: errorCode,
      message: message,
    );
  }
}
