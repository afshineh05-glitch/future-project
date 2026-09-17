import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/services/journey_access_service.dart';

class _Reader implements JourneyAccessReader {
  String? userId = 'tester';
  bool enabled;
  int reads = 0;
  _Reader(this.enabled);
  @override
  String? get currentUserId => userId;
  @override
  Future<bool> readJourneyAccess(String userId) async {
    reads++;
    return enabled;
  }
}

void main() {
  test('public default remains disabled without server grant', () async {
    final reader = _Reader(false);
    final service = JourneyAccessService(reader: reader);
    expect(JourneyAccessService.localOverride, isFalse);
    expect(await service.canAccess(), isFalse);
  });

  test(
    'authorized access is cached per user and revoked access is reloaded',
    () async {
      final reader = _Reader(true);
      final service = JourneyAccessService(reader: reader);
      expect(await service.canAccess(), isTrue);
      expect(await service.canAccess(), isTrue);
      expect(reader.reads, 1);
      service.clear();
      reader.enabled = false;
      expect(await service.canAccess(), isFalse);
    },
  );

  test('account switching cannot reuse another user access result', () async {
    final reader = _Reader(true);
    final service = JourneyAccessService(reader: reader);
    expect(await service.canAccess(), isTrue);
    reader.userId = 'other';
    reader.enabled = false;
    expect(await service.canAccess(), isFalse);
  });

  test('forced refresh observes a revoked grant without logout', () async {
    final reader = _Reader(true);
    final service = JourneyAccessService(reader: reader);
    expect(await service.canAccess(), isTrue);
    reader.enabled = false;
    expect(await service.canAccess(forceRefresh: true), isFalse);
    expect(reader.reads, 2);
  });
}
