class ExerciseNameNormalizer {
  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String canonicalIdForSlug(String slug) =>
      'mu_ex_${slug.trim().toLowerCase().replaceAll('-', '_')}';
}
