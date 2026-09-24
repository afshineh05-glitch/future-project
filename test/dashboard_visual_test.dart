import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/screens/dashboard_screen.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/dashboard_card.dart';

void _noop() {}

void main() {
  test('experimental dashboard theme retains the approved visual shell', () {
    expect(AppTheme.charcoal, const Color(0xFF090908));
    expect(AppTheme.metallicGold, const Color(0xFFFFD45A));
    expect(AppTheme.brightGold, const Color(0xFFFFE27A));
    expect(AppTheme.deepGold, const Color(0xFFDFAF32));
    expect(AppTheme.lightTheme.brightness, Brightness.dark);
  });

  test(
    'Home destination order and concrete routes match the stable commit',
    () async {
      expect(DashboardPresentation.stableHomeDestinationOrder, const [
        'Intelligent Coach',
        'Wearables',
        'My Vision',
        'AI Calorie Magnifier',
      ]);

      final source = await File(
        'lib/screens/dashboard_screen.dart',
      ).readAsString();
      expect(source, contains('const IntelligentCoachScreen()'));
      expect(source, contains('const WearablesHubScreen()'));
      expect(source, contains('const VisionScreen()'));
      expect(source, contains('const CalorieScannerScreen()'));
      expect(source, isNot(contains('const TrainingPlanScreen()')));
      expect(source, isNot(contains('const NutritionHomeScreen()')));
      expect(source, isNot(contains('const MyFoundationScreen()')));
      expect(source, isNot(contains('const BodyProgressScreen()')));
    },
  );

  test('Intelligent Coach retains the stable child hierarchy', () async {
    final source = await File(
      'lib/screens/intelligent_coach_screen.dart',
    ).readAsString();
    const labels = [
      'My Foundation',
      'Today’s Coach',
      'Weekly Coach',
      'Training Plan',
      'Nutrition Plan',
      'Body Progress',
      'Chat with Coach',
      'Coach Settings',
    ];

    var previous = -1;
    for (final label in labels) {
      final position = source.indexOf(label, previous + 1);
      expect(
        position,
        greaterThan(previous),
        reason: '$label hierarchy changed',
      );
      previous = position;
    }

    expect(source, contains('const MyFoundationScreen()'));
    expect(source, contains('const TodaysCoachScreen()'));
    expect(source, contains('const WeeklyCoachScreen()'));
    expect(source, contains('const TrainingPlanScreen()'));
    expect(source, contains('const NutritionHomeScreen()'));
    expect(source, contains('const BodyProgressScreen()'));
  });

  testWidgets(
    'dashboard card preserves approved icon geometry and tap target',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: DashboardCard(
              icon: Icons.psychology_outlined,
              title: 'Intelligent Coach',
              subtitle: 'Your daily health guidance',
              backgroundColor: AppTheme.dashboardCardStrong,
              iconColor: AppTheme.metallicGold,
              isHighlighted: true,
              onTap: _noop,
            ),
          ),
        ),
      );

      final icon = tester.widget<Icon>(find.byIcon(Icons.psychology_outlined));
      expect(icon.size, 30);
      expect(icon.color, AppTheme.metallicGold);

      final iconContainer = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.psychology_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(iconContainer.constraints?.maxWidth, 58);
      expect(iconContainer.constraints?.maxHeight, 58);

      final row = tester.widget<Row>(find.byType(Row));
      expect((row.children[1] as SizedBox).width, 18);
      expect(tester.widget<InkWell>(find.byType(InkWell)).onTap, isNotNull);
    },
  );

  testWidgets(
    'desktop Home has four stable destinations without child promotions',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final taps = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: DashboardPresentation(
            onCoach: () => taps.add('coach'),
            onWearables: () => taps.add('wearables'),
            onVision: () => taps.add('vision'),
            onCalorieMagnifier: () => taps.add('calorie'),
            onSignOut: () => taps.add('sign-out'),
          ),
        ),
      );

      expect(
        tester.getSize(find.byKey(const Key('dashboard-sidebar'))).width,
        DashboardPresentation.desktopSidebarWidth,
      );
      expect(
        tester.getSize(find.byKey(const Key('dashboard-card-column'))).width,
        DashboardPresentation.preferredCardWidth,
      );

      expect(find.byType(DashboardCard), findsNWidgets(4));
      expect(find.byKey(const Key('dashboard-card-vision')), findsOneWidget);
      expect(find.byKey(const Key('dashboard-vision-quote')), findsOneWidget);
      expect(find.text('Intelligent Coach'), findsNWidgets(2));
      expect(find.text('Wearables'), findsNWidgets(2));
      expect(find.text('My Vision'), findsNWidgets(2));
      expect(find.text('AI Calorie Magnifier'), findsOneWidget);

      for (final child in [
        'Training Plan',
        'Nutrition Plan',
        'Intelligent Fridge',
        'Body Progress',
        'My Foundation',
        'Today’s Coach',
      ]) {
        expect(find.text(child), findsNothing);
      }

      final image = tester.widget<Image>(
        find.byKey(const Key('dashboard-splash-background')),
      );
      expect(
        (image.image as AssetImage).assetName,
        'assets/images/muscleup_splash.png',
      );
      expect(image.fit, BoxFit.cover);
      expect(
        find.byKey(const Key('dashboard-asymmetric-overlay')),
        findsOneWidget,
      );

      final orderedKeys = [
        'dashboard-card-coach',
        'dashboard-card-wearables',
        'dashboard-card-vision',
        'dashboard-card-calorie',
      ];
      for (final key in orderedKeys) {
        final target = find.byKey(Key(key));
        final inkWell = find.descendant(
          of: target,
          matching: find.byType(InkWell),
        );
        expect(inkWell, findsOneWidget, reason: '$key must be wholly tappable');
        tester.widget<InkWell>(inkWell).onTap!();
      }
      expect(taps, ['coach', 'wearables', 'vision', 'calorie']);
    },
  );
}
