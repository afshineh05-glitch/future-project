import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/screens/wearables_hub_screen.dart';

void main() {
  final screen = File(
    'lib/screens/wearables_hub_screen.dart',
  ).readAsStringSync();

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
