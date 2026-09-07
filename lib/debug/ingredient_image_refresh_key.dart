import 'ingredient_image_refresh_key_stub.dart'
    if (dart.library.io) 'ingredient_image_refresh_key_windows.dart';

// TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
abstract final class IngredientImageRefreshKey {
  static const _defined = String.fromEnvironment(
    'INGREDIENT_IMAGE_REFRESH_KEY',
  );

  static bool get hasRefreshKey => refreshKey.isNotEmpty;

  static String get refreshKey =>
      _defined.isNotEmpty ? _defined : readWindowsIngredientImageRefreshKey();
}
