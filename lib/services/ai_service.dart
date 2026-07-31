import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:future_project/config/supabase_config.dart';
import 'package:future_project/models/meal_analysis_result.dart';

class AIService {
  const AIService();

  static const int _maxAttempts = 3;

  Future<MealAnalysisResult> analyzeMeal(File imageFile) async {
    final Uri uri = Uri.parse(
      '${SupabaseConfig.url}/functions/v1/analyze-meal',
    );

    final List<int> imageBytes = await imageFile.readAsBytes();
    final String imageBase64 = base64Encode(imageBytes);
    final String mimeType = _getMimeType(imageFile.path);

    AIServiceException? lastError;

    for (int attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final http.Response response = await http
            .post(
              uri,
              headers: {
                'Content-Type': 'application/json',
                'apikey': SupabaseConfig.anonKey,
                'Authorization':
                    'Bearer ${SupabaseConfig.anonKey}',
              },
              body: jsonEncode({
                'image_base64': imageBase64,
                'mime_type': mimeType,
              }),
            )
            .timeout(
              const Duration(seconds: 60),
            );

        final Map<String, dynamic> decodedBody =
            _decodeResponse(
          response,
        );

        if (_isRetryableStatus(response.statusCode)) {
          lastError = AIServiceException(
            message: _extractErrorMessage(decodedBody),
            statusCode: response.statusCode,
            responseBody: response.body,
          );

          if (attempt < _maxAttempts) {
            await Future<void>.delayed(
              Duration(seconds: attempt * 2),
            );
            continue;
          }
        }

        if (response.statusCode < 200 ||
            response.statusCode >= 300) {
          throw AIServiceException(
            message: _extractErrorMessage(decodedBody),
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }

        if (decodedBody['success'] != true) {
          throw AIServiceException(
            message: _extractErrorMessage(decodedBody),
            statusCode: response.statusCode,
            responseBody: response.body,
          );
        }

        final dynamic analysis = decodedBody['analysis'];

        if (analysis is! Map<String, dynamic>) {
          throw const AIServiceException(
            message:
                'The server did not return a valid meal analysis.',
          );
        }

        return MealAnalysisResult.fromMap(analysis);
      } on TimeoutException {
        lastError = const AIServiceException(
          message:
              'The meal analysis request timed out. Please try again.',
        );

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(
            Duration(seconds: attempt * 2),
          );
          continue;
        }
      } on SocketException {
        lastError = const AIServiceException(
          message:
              'No internet connection. Please check your network.',
        );

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(
            Duration(seconds: attempt * 2),
          );
          continue;
        }
      } on AIServiceException catch (error) {
        if (!_isRetryableStatus(error.statusCode)) {
          rethrow;
        }

        lastError = error;

        if (attempt < _maxAttempts) {
          await Future<void>.delayed(
            Duration(seconds: attempt * 2),
          );
          continue;
        }
      }
    }

    throw lastError ??
        const AIServiceException(
          message:
              'Meal analysis is temporarily unavailable. Please try again shortly.',
        );
  }

  Map<String, dynamic> _decodeResponse(
    http.Response response,
  ) {
    try {
      final dynamic decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const AIServiceException(
          message:
              'The server returned an unexpected response.',
        );
      }

      return decoded;
    } on FormatException {
      throw AIServiceException(
        message: 'The server returned invalid JSON.',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }
  }

  bool _isRetryableStatus(int? statusCode) {
    return statusCode == 429 ||
        statusCode == 500 ||
        statusCode == 502 ||
        statusCode == 503 ||
        statusCode == 504;
  }

  String _getMimeType(String filePath) {
    final String lowerPath = filePath.toLowerCase();

    if (lowerPath.endsWith('.png')) {
      return 'image/png';
    }

    if (lowerPath.endsWith('.webp')) {
      return 'image/webp';
    }

    if (lowerPath.endsWith('.heic')) {
      return 'image/heic';
    }

    return 'image/jpeg';
  }

  String _extractErrorMessage(
    Map<String, dynamic> body,
  ) {
    final dynamic error = body['error'];

    if (error is String && error.isNotEmpty) {
      return _friendlyErrorMessage(error);
    }

    if (error is Map<String, dynamic>) {
      final dynamic nestedError = error['error'];

      if (nestedError is Map<String, dynamic>) {
        final dynamic message = nestedError['message'];

        if (message is String && message.isNotEmpty) {
          return _friendlyErrorMessage(message);
        }
      }

      final dynamic message = error['message'];

      if (message is String && message.isNotEmpty) {
        return _friendlyErrorMessage(message);
      }
    }

    return 'Meal analysis failed.';
  }

  String _friendlyErrorMessage(String message) {
    final String lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('high demand') ||
        lowerMessage.contains('unavailable') ||
        lowerMessage.contains('overloaded')) {
      return 'Meal analysis is temporarily busy. Please try again shortly.';
    }

    if (lowerMessage.contains('rate limit') ||
        lowerMessage.contains('quota')) {
      return 'Too many requests were sent. Please wait a moment and try again.';
    }

    return message;
  }
}

class AIServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? responseBody;

  const AIServiceException({
    required this.message,
    this.statusCode,
    this.responseBody,
  });

  @override
  String toString() {
    if (statusCode == null) {
      return 'AIServiceException: $message';
    }

    return 'AIServiceException ($statusCode): $message';
  }
}