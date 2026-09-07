import 'dart:io';

// TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
String readWindowsIngredientImageRefreshKey() => Platform.isWindows
    ? Platform.environment['INGREDIENT_IMAGE_REFRESH_KEY']?.trim() ?? ''
    : '';
