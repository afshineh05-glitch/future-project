import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/journey.dart';
import 'package:future_project/services/journey_access_service.dart';
import 'package:future_project/services/journey_service.dart';
import 'package:future_project/screens/journey_screen.dart';

class _AccessReader implements JourneyAccessReader {
  _AccessReader(this.enabled);
  final bool enabled;
  @override
  String? get currentUserId => 'tester';
  @override
  Future<bool> readJourneyAccess(String userId) async => enabled;
}

class _JourneyReader implements JourneySourceReader {
  @override
  String? get currentUserId => 'tester';
  @override
  Future<JourneySourceSnapshot> read(String userId) async =>
      const JourneySourceSnapshot();
}

void main() {
  Widget harness({required bool enabled}) => MaterialApp(
    home: JourneyScreen(
      accessService: JourneyAccessService(reader: _AccessReader(enabled)),
      journeyService: JourneyService(reader: _JourneyReader()),
    ),
  );

  testWidgets('unauthorized users receive no Journey content', (tester) async {
    await tester.pumpWidget(harness(enabled: false));
    await tester.pumpAndSettle();
    expect(find.text('Your Journey'), findsNothing);
    expect(find.text('Your Journey will grow automatically'), findsNothing);
  });

  testWidgets('authorized testers receive the read-only Journey shell', (
    tester,
  ) async {
    await tester.pumpWidget(harness(enabled: true));
    await tester.pumpAndSettle();
    expect(find.text('Your Journey'), findsOneWidget);
    expect(find.text('Your Journey will grow automatically'), findsOneWidget);
    expect(find.byType(Checkbox), findsNothing);
  });
}
