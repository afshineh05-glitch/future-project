import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/main.dart';

void main() {
  testWidgets('shows the approved splash before the existing destination', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MuscleUpStartup(
        initialize: () async {},
        destination: const SizedBox(key: Key('existing-startup-destination')),
      ),
    );

    final Image splash = tester.widget<Image>(find.byType(Image));
    expect(splash.image, isA<AssetImage>());
    expect(
      (splash.image as AssetImage).assetName,
      'assets/images/muscleup_splash.png',
    );
    expect(splash.fit, BoxFit.cover);
    expect(find.byKey(const Key('existing-startup-destination')), findsNothing);

    await tester.pump(MuscleUpStartup.splashDuration);
    expect(find.byType(Image), findsNothing);
    expect(
      find.byKey(const Key('existing-startup-destination')),
      findsOneWidget,
    );
  });
}
