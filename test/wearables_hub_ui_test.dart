import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/screens/wearables_hub_screen.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';
import 'package:future_project/services/wearables_hub_service.dart';

WearablesHubData _hubData({required bool populated}) {
  final now = DateTime(2026, 9, 11, 12);
  final today = populated
      ? const WearableValidationService().validate(
          WearableData(
            rangeStart: DateTime(2026, 9, 11),
            rangeEnd: now,
            permissionStatus: WearablePermissionStatus.authorized,
            steps: 8200,
            activeEnergyKilocalories: 410,
            restingHeartRateBpm: 62,
            sleepDuration: const Duration(hours: 7),
            workouts: const [],
            unavailableMetrics: const {},
            sourceDates: {
              WearableMetric.steps: now,
              WearableMetric.activeEnergy: now,
              WearableMetric.restingHeartRate: now,
              WearableMetric.sleepDuration: now,
            },
          ),
          now: now,
        )
      : null;
  return const WearablesHubEngine().build(
    source: ConnectedHealthSource(
      provider: WearableProvider.appleHealth,
      displayName: 'Apple Health',
      permissionStatus: WearablePermissionStatus.authorized,
      dataAvailable: true,
    ),
    now: now,
    today: today,
  );
}

void main() {
  final screen = File(
    'lib/screens/wearables_hub_screen.dart',
  ).readAsStringSync();
  final bleCard = File(
    'lib/widgets/ble_device_management_card.dart',
  ).readAsStringSync();

  test('approved hero and motivational direction are present', () {
    expect(screen, contains('Your health. Everywhere with you.'));
    expect(
      screen,
      contains('Connect your favorite devices to get automatic data'),
    );
    expect(screen, contains('Better data.\\nA stronger you.'));
    for (final benefit in [
      'More accurate tracking',
      'Personalized coaching',
      'Reach your goals faster',
      'Your data stays private',
    ]) {
      expect(screen, contains(benefit));
    }
  });

  test('provider grid is honest and Apple Health has one connect card', () {
    for (final provider in ['WHOOP', 'Garmin', 'Fitbit', 'Polar', 'Oura']) {
      expect(screen, contains("'$provider'"));
    }
    expect(RegExp("title: 'Apple Health'").allMatches(screen), hasLength(1));
    expect(screen, contains("'Connect Your Device'"));
    expect(screen, contains("'Not connected'"));
    expect(screen, contains('BleDeviceManagementCard('));
  });

  test('BLE available and unavailable states use friendly product copy', () {
    expect(bleCard, contains("BleAvailability.ready => 'Bluetooth is ready.'"));
    expect(bleCard, contains('Bluetooth Low Energy is not supported'));
    expect(bleCard, contains('Turn on Bluetooth to scan'));
    expect(bleCard, isNot(contains('UnimplementedError')));
  });

  test('raw technical errors are sanitized', () {
    expect(
      safeStatusMessage('UnimplementedError: platform method'),
      'This health source is unavailable right now.',
    );
    expect(
      safeStatusMessage('Health data is still syncing.'),
      'Health data is still syncing.',
    );
    expect(screen, isNot(contains('Text(data.source.statusMessage!')));
  });

  test('responsive layout uses breakpoints without fixed page width', () {
    expect(screen, contains('viewportWidth >= 700'));
    expect(screen, contains('viewportWidth >= 480'));
    expect(screen, contains("final compact = viewportWidth < 560"));
    expect(
      screen,
      contains('constraints: const BoxConstraints(maxWidth: 760)'),
    );
    expect(screen, contains('LayoutBuilder'));
    expect(screen, contains('Wrap('));
  });

  test('connected devices section is derived from real permission state', () {
    expect(screen, contains("'Connected Devices'"));
    expect(screen, contains('WearablePermissionStatus.authorized'));
    expect(screen, contains('WearablePermissionStatus.partiallyAuthorized'));
    expect(screen, contains('No confirmed health sources or devices'));
  });

  for (final size in [const Size(360, 800), const Size(1024, 900)]) {
    testWidgets('responsive Wearables layout does not overflow at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final data = _hubData(populated: true);

      await tester.pumpWidget(
        MaterialApp(
          home: WearablesHubScreen(
            loadData: () async => data,
            requestPermissions: () async => const WearablePermissionResult(
              WearablePermissionStatus.authorized,
            ),
            bleDeviceCard: const SizedBox(
              key: ValueKey('fake_ble_provider'),
              height: 120,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Your health. Everywhere with you.'), findsOneWidget);
      expect(find.byKey(const ValueKey('fake_ble_provider')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  test('unsupported platform uses one compact non-actionable empty state', () {
    expect(
      isConnectionUnavailable(WearablePermissionStatus.unsupportedPlatform),
      isTrue,
    );
    expect(
      canRequestPermissions(WearablePermissionStatus.unsupportedPlatform),
      isFalse,
    );
    expect(
      connectionEmptyMessage(WearablePermissionStatus.unsupportedPlatform),
      'Apple Health is available on supported iOS devices.',
    );
    expect(screen, contains('class _CompactEmptyState'));
  });

  test('denied and partial permission copy is accurate and compact', () {
    expect(isConnectionUnavailable(WearablePermissionStatus.denied), isTrue);
    expect(canRequestPermissions(WearablePermissionStatus.denied), isTrue);
    expect(
      connectionEmptyMessage(WearablePermissionStatus.denied),
      contains('Review Apple Health permissions'),
    );
    expect(
      permissionSupportingText(WearablePermissionStatus.partiallyAuthorized),
      'Some health data is unavailable.',
    );
  });

  test('connected no-data state is helpful and missing never becomes zero', () {
    expect(
      connectionEmptyMessage(WearablePermissionStatus.authorized),
      contains('no validated health data'),
    );
    expect(
      metricUnavailable(WearableValidationStatus.missing),
      'Not available',
    );
    expect(metricUnavailable(null), 'Not available');
    expect(metricUnavailable(null), isNot('0'));
  });

  test('main Today surface has exactly four primary metrics', () {
    final primaryMetrics = RegExp(
      "keyName: '(steps|sleep|active_energy|resting_hr)'",
    ).allMatches(screen);
    expect(primaryMetrics, hasLength(4));
    expect(
      screen,
      contains("key: ValueKey('primary_metric_\${data.keyName}')"),
    );
  });

  test(
    'secondary health metrics are confined to details and weight is contextual',
    () {
      final details = screen.indexOf('void _showAllHealthData');
      expect(details, greaterThan(0));
      for (final label in [
        'Average HR',
        'Distance',
        'Workout Duration',
        'Body Weight',
      ]) {
        expect(screen.indexOf("'$label'", details), greaterThan(details));
      }
      expect(screen, contains('Context only'));
    },
  );

  test('7-day overview is text-only and uses a compact insufficient state', () {
    final history = [
      WearableDailyRecord(
        userId: 'u',
        localDate: DateTime(2026, 9, 10),
        sourceUpdatedAt: DateTime(2026, 9, 10),
        steps: 7000,
      ),
    ];
    expect(
      overviewRow(
        'Steps',
        history,
        (row) => row.steps?.toDouble(),
        'steps',
      ).value,
      'Need more history',
    );
    expect(screen, isNot(contains('BarChart')));
    expect(screen, isNot(contains('LineChart')));
    expect(screen, isNot(contains('CustomPaint')));
  });

  test('personal baseline copy uses canonical personal values only', () {
    const metric = RecoveryMetricContext(
      state: RecoveryContextState.normal,
      latestValue: 405,
      personalBaseline: 420,
      baselineDays: 7,
      unit: 'minutes',
      evidence: [],
    );
    expect(baselineSupport(metric), 'Near your usual range');
    expect(baselineValue(metric), contains('7h 0m recent average'));
    expect(screen, isNot(contains('readiness')));
    expect(screen, isNot(contains('normal range')));
  });

  test('Coach Insight presents exactly one canonical insight and action', () {
    expect(RegExp(r'context\.primaryInsight').allMatches(screen), hasLength(1));
    expect(RegExp(r'context\.primaryAction').allMatches(screen), hasLength(1));
    expect(screen, contains('_coachInsight(data.unifiedCoachContext)'));
  });

  test('sync button is disabled while an existing sync is running', () {
    expect(
      screen,
      contains('if (_syncState == WearablesSyncUiState.syncing) return'),
    );
    expect(
      RegExp(
        r'onPressed:\s*_syncState == WearablesSyncUiState\.syncing\s*\? null\s*:\s*_syncNow',
      ).hasMatch(screen),
      isTrue,
    );
    expect(screen, contains('WearablesSyncUiState.success'));
    expect(screen, contains('WearablesSyncUiState.failure'));
  });

  test('release dashboard does not expose wearable debug tools', () {
    final dashboard = File(
      'lib/screens/dashboard_screen.dart',
    ).readAsStringSync();
    final debugScreen = File(
      'lib/screens/wearable_debug_screen.dart',
    ).readAsStringSync();
    expect(
      dashboard,
      contains(
        'if (kDebugMode && defaultTargetPlatform == TargetPlatform.iOS)',
      ),
    );
    expect(
      debugScreen,
      contains("assert(kDebugMode, 'The wearable test screen is debug-only.')"),
    );
    expect(
      debugScreen,
      contains('if (!kDebugMode) return const SizedBox.shrink()'),
    );
  });

  test('UI pass does not mutate protected product domains', () {
    expect(screen, isNot(contains('training_plans')));
    expect(screen, isNot(contains('nutrition')));
    expect(screen, isNot(contains('foundation')));
    expect(screen, isNot(contains('body_progress')));
    expect(screen, isNot(contains('progress_engine')));
    expect(screen, isNot(contains('.insert(')));
    expect(screen, isNot(contains('.upsert(')));
  });
}
