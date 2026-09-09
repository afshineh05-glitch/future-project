import 'package:future_project/models/wearable_data.dart';

abstract interface class WearableService {
  Future<WearablePermissionResult> permissionStatus();

  Future<WearablePermissionResult> requestReadPermissions();

  Future<WearableData> readToday();
}
