import 'package:flutter/foundation.dart';
import 'package:future_project/models/future_body_template.dart';
import 'package:future_project/models/future_self_generation.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/services/future_body_template_resolver.dart';
import 'package:future_project/services/future_self_photo_validator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FutureSelfImageService {
  static const String _bucket = 'future-self-images';
  final SupabaseClient _supabase;
  final FutureBodyTemplateResolver _templateResolver;
  final FutureSelfPhotoValidator photoValidator;

  FutureSelfImageService({
    SupabaseClient? supabase,
    FutureBodyTemplateResolver templateResolver =
        const FutureBodyTemplateResolver(),
    this.photoValidator = const FutureSelfPhotoValidator(),
  }) : _supabase = supabase ?? Supabase.instance.client,
       _templateResolver = templateResolver;

  bool get hasAuthenticatedUser => _supabase.auth.currentUser != null;

  bool hasValidCurrentPhoto(FutureVision vision) =>
      vision.currentPhotoPath?.trim().isNotEmpty == true;

  Future<String> uploadCurrentPhoto({
    required Uint8List bytes,
    required String fileExtension,
    required FutureSelfInputMode inputMode,
  }) async {
    try {
      debugPrint('VISION PHOTO: validating ${bytes.length} selected bytes');
      final extension = _validateImage(bytes, fileExtension);
      final user = _requireUser();
      debugPrint('VISION PHOTO: authenticated user exists: ${user.id}');
      final path =
          '${user.id}/current/${DateTime.now().microsecondsSinceEpoch}.$extension';
      debugPrint('VISION PHOTO: target bucket: $_bucket');
      debugPrint('VISION PHOTO: target storage path: $path');
      final existing = await _runStage(
        FutureSelfPhotoUploadStage.loadVisionReference,
        () => _photoPaths(user.id),
      );
      await _runStage(
        FutureSelfPhotoUploadStage.storageUpload,
        () => _supabase.storage
            .from(_bucket)
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(
                cacheControl: '3600',
                upsert: false,
                contentType: _contentType(extension),
              ),
            ),
      );
      debugPrint('VISION PHOTO: storage upload succeeded: $path');
      try {
        final updated = await _runStage(
          FutureSelfPhotoUploadStage.databasePersistence,
          () => _supabase
              .from('vision_profiles')
              .update({
                'current_photo_path': path,
                'current_photo_input_mode': inputMode.wireValue,
                'future_self_input_mode': inputMode.wireValue,
                'future_self_image_path': null,
                'future_self_generated_at': null,
                'future_self_generated_input_mode': null,
                'future_self_horizon_months': null,
                'future_self_source_reference': null,
                'future_self_goal_used': null,
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('user_id', user.id)
              .select('current_photo_path')
              .single(),
        );
        if (updated['current_photo_path']?.toString() != path) {
          throw StateError('Vision photo reference was not persisted.');
        }
        debugPrint('VISION PHOTO: database update succeeded');
        debugPrint('VISION PHOTO: final currentPhoto reference: $path');
      } catch (error, stackTrace) {
        try {
          await _supabase.storage.from(_bucket).remove([path]);
          debugPrint('VISION PHOTO: removed orphan after database failure');
        } catch (cleanupError, cleanupStackTrace) {
          debugPrint('Future Self orphan cleanup failed: $cleanupError');
          debugPrintStack(stackTrace: cleanupStackTrace);
        }
        Error.throwWithStackTrace(error, stackTrace);
      }
      final obsoletePaths = <String>[
        if (existing.current != null && existing.current != path)
          existing.current!,
        if (existing.future != null) existing.future!,
      ];
      if (obsoletePaths.isNotEmpty) {
        await _supabase.storage.from(_bucket).remove(obsoletePaths);
      }
      return path;
    } catch (error, stackTrace) {
      debugPrint('VISION PHOTO ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeCurrentPhoto() async {
    final user = _requireUser();
    final existing = await _photoPaths(user.id);
    await _supabase
        .from('vision_profiles')
        .update({
          'current_photo_path': null,
          'current_photo_input_mode': null,
          'future_self_image_path': null,
          'future_self_generated_at': null,
          'future_self_generated_input_mode': null,
          'future_self_horizon_months': null,
          'future_self_source_reference': null,
          'future_self_goal_used': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id);
    final paths = <String>[
      if (existing.current != null) existing.current!,
      if (existing.future != null) existing.future!,
    ];
    if (paths.isNotEmpty) {
      await _supabase.storage.from(_bucket).remove(paths);
    }
  }

  Future<String?> createPreviewUrl(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return null;
    return _supabase.storage
        .from(_bucket)
        .createSignedUrl(storagePath, 60 * 60);
  }

  Future<FutureSelfPhotoReferences> loadPhotoReferences() async {
    final user = _requireUser();
    final paths = await _photoPaths(user.id);
    return FutureSelfPhotoReferences(
      currentPhotoPath: paths.current,
      futurePhotoPath: paths.future,
      selectedMode: paths.selectedMode,
      currentPhotoMode: paths.currentMode,
      generatedImageMode: paths.generatedMode,
    );
  }

  Future<void> saveInputMode(FutureSelfInputMode mode) async {
    final user = _requireUser();
    await _supabase
        .from('vision_profiles')
        .update({
          'future_self_input_mode': mode.wireValue,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  Future<FutureSelfGenerationRequest> buildGenerationRequest(
    FutureVision vision, {
    String? currentPhotoPath,
    required FutureSelfInputMode inputMode,
  }) async {
    final user = _requireUser();
    final resolvedCurrentPhotoPath = currentPhotoPath?.trim().isNotEmpty == true
        ? currentPhotoPath!.trim()
        : vision.currentPhotoPath?.trim();
    if (resolvedCurrentPhotoPath == null || resolvedCurrentPhotoPath.isEmpty) {
      throw StateError('A current photo is required.');
    }
    final foundation = await _supabase
        .from('user_foundations')
        .select(
          'age, sex, primary_goal, body_type, height_cm, weight_kg, target_weight_kg, training_level, waist_cm, chest_cm, hips_cm, arm_cm, thigh_cm, neck_cm',
        )
        .eq('user_id', user.id)
        .maybeSingle();
    final foundationData = foundation ?? const <String, dynamic>{};
    final measurements = <String, double>{};
    for (final entry in const {
      'waist': 'waist_cm',
      'chest': 'chest_cm',
      'hips': 'hips_cm',
      'arm': 'arm_cm',
      'thigh': 'thigh_cm',
      'neck': 'neck_cm',
    }.entries) {
      final value = (foundationData[entry.value] as num?)?.toDouble();
      if (value != null) measurements[entry.key] = value;
    }
    String? bodyTemplateId;
    if (inputMode == FutureSelfInputMode.faceOnly) {
      bodyTemplateId = _templateResolver
          .resolve(
            profileCategory: foundationData['sex']?.toString(),
            heightCm: (foundationData['height_cm'] as num?)?.toDouble(),
            weightKg: (foundationData['weight_kg'] as num?)?.toDouble(),
            bodyType: foundationData['body_type']?.toString(),
            primaryGoal:
                foundationData['primary_goal']?.toString() ??
                vision.primaryGoal,
          )
          .id;
    }
    return FutureSelfGenerationRequest(
      userId: user.id,
      inputMode: inputMode,
      currentPhotoPath: resolvedCurrentPhotoPath,
      bodyTemplateId: bodyTemplateId,
      primaryGoal:
          foundationData['primary_goal']?.toString() ?? vision.primaryGoal,
      desiredFeelings: vision.desiredFeelings,
      futureIdentity: vision.futureIdentity,
      age: (foundationData['age'] as num?)?.round(),
      profileCategory: foundationData['sex']?.toString(),
      heightCm: (foundationData['height_cm'] as num?)?.toDouble(),
      weightKg: (foundationData['weight_kg'] as num?)?.toDouble(),
      targetWeightKg: (foundationData['target_weight_kg'] as num?)?.toDouble(),
      measurementsCm: measurements,
      trainingLevel: foundationData['training_level']?.toString(),
    );
  }

  Future<FutureSelfGenerationResult> generateFutureSelf(
    FutureVision vision, {
    required String currentPhotoPath,
    required FutureSelfInputMode inputMode,
  }) async {
    try {
      final request = await buildGenerationRequest(
        vision,
        currentPhotoPath: currentPhotoPath,
        inputMode: inputMode,
      );
      final response = await _supabase.functions.invoke(
        'generate-future-self',
        body: {'request': request.toMap()},
      );
      final data = response.data;
      if (data is! Map || data['futureSelfImagePath'] == null) {
        throw StateError('The generation service did not return an image.');
      }
      final path = data['futureSelfImagePath'].toString().trim();
      final generatedAt = DateTime.tryParse(
        data['generatedAt']?.toString() ?? '',
      );
      if (path.isEmpty || generatedAt == null) {
        throw StateError('The generation service returned an invalid result.');
      }
      debugPrint('Future Self generation succeeded: $path');
      return FutureSelfGenerationResult(
        storagePath: path,
        generatedAt: generatedAt,
        inputMode: FutureSelfInputModeWire.fromWire(
          data['inputMode']?.toString(),
        ),
        futureHorizonMonths:
            (data['futureHorizonMonths'] as num?)?.round() ?? 8,
      );
    } on FunctionException catch (error, stackTrace) {
      final details = error.details;
      if (details is Map &&
          details['code']?.toString() == 'future_self_photo_rejected') {
        debugPrint('Future Self generation rejected by safety checks.');
        throw const FutureSelfSafetyRejectedException();
      }
      if (details is Map &&
          details['code']?.toString() == 'future_self_validation_failed') {
        throw FutureSelfPhotoRejectedException(
          details['error']?.toString() ?? 'Please choose another clear photo.',
        );
      }
      if (details is Map &&
          details['code']?.toString() == 'body_template_unavailable') {
        throw const FutureBodyTemplateUnavailableException();
      }
      debugPrint('Future Self generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Future Self generation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> removeFutureSelfImage() async {
    final user = _requireUser();
    final existing = await _photoPaths(user.id);
    await _supabase
        .from('vision_profiles')
        .update({
          'future_self_image_path': null,
          'future_self_generated_at': null,
          'future_self_generated_input_mode': null,
          'future_self_horizon_months': null,
          'future_self_source_reference': null,
          'future_self_goal_used': null,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id);
    if (existing.future != null) {
      await _supabase.storage.from(_bucket).remove([existing.future!]);
    }
  }

  Future<void> saveGeneratedImageReference({
    required String storagePath,
    required DateTime generatedAt,
  }) async {
    final user = _requireUser();
    await _supabase
        .from('vision_profiles')
        .update({
          'future_self_image_path': storagePath,
          'future_self_generated_at': generatedAt.toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('user_id', user.id);
  }

  Future<
    ({
      String? current,
      String? future,
      FutureSelfInputMode? selectedMode,
      FutureSelfInputMode? currentMode,
      FutureSelfInputMode? generatedMode,
    })
  >
  _photoPaths(String userId) async {
    final row = await _supabase
        .from('vision_profiles')
        .select(
          'current_photo_path, future_self_image_path, future_self_input_mode, current_photo_input_mode, future_self_generated_input_mode',
        )
        .eq('user_id', userId)
        .maybeSingle();
    final currentPath = row?['current_photo_path']?.toString();
    final futurePath = row?['future_self_image_path']?.toString();
    final rawSelectedMode = row?['future_self_input_mode']?.toString();
    return (
      current: currentPath,
      future: futurePath,
      selectedMode: rawSelectedMode == null
          ? currentPath == null && futurePath == null
                ? null
                : FutureSelfInputMode.fullBody
          : FutureSelfInputModeWire.fromWire(rawSelectedMode),
      currentMode: row?['current_photo_path'] == null
          ? null
          : FutureSelfInputModeWire.fromWire(
              row?['current_photo_input_mode']?.toString(),
            ),
      generatedMode: row?['future_self_image_path'] == null
          ? null
          : FutureSelfInputModeWire.fromWire(
              row?['future_self_generated_input_mode']?.toString(),
            ),
    );
  }

  User _requireUser() {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      throw StateError('Sign in to manage a Future Self photo.');
    }
    return user;
  }

  String _safeExtension(String value) {
    final normalized = value.toLowerCase().replaceAll('.', '');
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(normalized)
        ? normalized
        : 'jpg';
  }

  String _validateImage(Uint8List bytes, String fileExtension) {
    if (bytes.isEmpty) {
      throw const FormatException('The selected image is empty.');
    }
    const maximumBytes = 10 * 1024 * 1024;
    if (bytes.length > maximumBytes) {
      throw const FormatException('The selected image exceeds 10 MB.');
    }
    final detected = _detectedExtension(bytes);
    if (detected == null) {
      throw const FormatException('Only JPG, PNG, and WebP are supported.');
    }
    final provided = _safeExtension(fileExtension);
    if (provided != detected && !(provided == 'jpeg' && detected == 'jpg')) {
      debugPrint(
        'Future Self photo extension normalized from $provided to $detected.',
      );
    }
    return detected;
  }

  String? _detectedExtension(Uint8List bytes) {
    if (bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'jpg';
    }
    if (bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47 &&
        bytes[4] == 0x0D &&
        bytes[5] == 0x0A &&
        bytes[6] == 0x1A &&
        bytes[7] == 0x0A) {
      return 'png';
    }
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return 'webp';
    }
    return null;
  }

  Future<T> _runStage<T>(
    FutureSelfPhotoUploadStage stage,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (error, stackTrace) {
      debugPrint('Future Self photo upload failed at ${stage.name}: $error');
      debugPrintStack(stackTrace: stackTrace);
      Error.throwWithStackTrace(
        FutureSelfPhotoUploadException(stage, error),
        stackTrace,
      );
    }
  }

  String _contentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    _ => 'image/jpeg',
  };
}

class FutureSelfGenerationResult {
  final String storagePath;
  final DateTime generatedAt;
  final FutureSelfInputMode inputMode;
  final int futureHorizonMonths;

  const FutureSelfGenerationResult({
    required this.storagePath,
    required this.generatedAt,
    required this.inputMode,
    required this.futureHorizonMonths,
  });
}

class FutureSelfSafetyRejectedException implements Exception {
  const FutureSelfSafetyRejectedException();

  @override
  String toString() => 'Future Self input photo rejected by safety checks.';
}

class FutureSelfPhotoReferences {
  final String? currentPhotoPath;
  final String? futurePhotoPath;
  final FutureSelfInputMode? selectedMode;
  final FutureSelfInputMode? currentPhotoMode;
  final FutureSelfInputMode? generatedImageMode;

  const FutureSelfPhotoReferences({
    required this.currentPhotoPath,
    required this.futurePhotoPath,
    required this.selectedMode,
    required this.currentPhotoMode,
    required this.generatedImageMode,
  });
}

class FutureSelfPhotoRejectedException implements Exception {
  final String userMessage;

  const FutureSelfPhotoRejectedException(this.userMessage);

  @override
  String toString() => userMessage;
}

enum FutureSelfPhotoUploadStage {
  loadVisionReference,
  storageUpload,
  databasePersistence,
}

class FutureSelfPhotoUploadException implements Exception {
  final FutureSelfPhotoUploadStage stage;
  final Object cause;

  const FutureSelfPhotoUploadException(this.stage, this.cause);

  @override
  String toString() =>
      'FutureSelfPhotoUploadException(stage: ${stage.name}, cause: $cause)';
}
