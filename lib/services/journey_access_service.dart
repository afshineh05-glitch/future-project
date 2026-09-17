import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract interface class JourneyAccessReader {
  String? get currentUserId;
  Future<bool> readJourneyAccess(String userId);
}

class SupabaseJourneyAccessReader implements JourneyAccessReader {
  final SupabaseClient _supabase;

  SupabaseJourneyAccessReader([SupabaseClient? supabase])
    : _supabase = supabase ?? Supabase.instance.client;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  @override
  Future<bool> readJourneyAccess(String userId) async {
    try {
      final row = await _supabase
          .from('internal_feature_access')
          .select('enabled')
          .eq('user_id', userId)
          .eq('feature_key', 'journey_v2')
          .maybeSingle();
      return row?['enabled'] == true;
    } catch (_) {
      // A missing table or denied request keeps the public release disabled.
      return false;
    }
  }
}

class JourneyAccessService {
  static const featureKey = 'journey_v2';
  static const bool localOverride = bool.fromEnvironment(
    'ENABLE_JOURNEY_V2',
    defaultValue: false,
  );

  final JourneyAccessReader _reader;
  Future<bool>? _inFlight;
  String? _cachedUserId;
  bool? _cachedValue;

  JourneyAccessService({JourneyAccessReader? reader})
      : _reader = reader ?? SupabaseJourneyAccessReader();

  String? get currentUserId => _reader.currentUserId;

  Future<bool> canAccess() {
    final userId = _reader.currentUserId;
    if (userId == null) return Future<bool>.value(false);
    if (_cachedUserId == userId && _cachedValue != null) {
      return Future<bool>.value(_cachedValue!);
    }
    final existing = _inFlight;
    if (existing != null) return existing;
    final request = _load(userId);
    _inFlight = request;
    return request.whenComplete(() {
      if (identical(_inFlight, request)) _inFlight = null;
    });
  }

  Future<bool> _load(String userId) async {
    // The override is deliberately debug-only. A normal release build remains
    // server-controlled even if a developer accidentally defines the flag.
    final enabled =
        (kDebugMode && localOverride) ||
        await _reader.readJourneyAccess(userId);
    if (_reader.currentUserId != userId) return false;
    _cachedUserId = userId;
    _cachedValue = enabled;
    return enabled;
  }

  void clear() {
    _inFlight = null;
    _cachedUserId = null;
    _cachedValue = null;
  }
}
