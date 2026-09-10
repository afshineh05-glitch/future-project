import 'package:flutter/material.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/services/wearables_hub_service.dart';
import 'package:future_project/theme/app_theme.dart';

class WearablesHubScreen extends StatefulWidget {
  const WearablesHubScreen({super.key});

  @override
  State<WearablesHubScreen> createState() => _WearablesHubScreenState();
}

class _WearablesHubScreenState extends State<WearablesHubScreen> {
  final _service = WearablesHubService();
  WearablesHubData? _data;
  bool _loading = true;
  bool _managing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final data = await _service.load();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Wearable data could not be loaded right now.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _requestPermissions() async {
    setState(() => _managing = true);
    final result = await _service.requestPermissions();
    if (!mounted) return;
    setState(() => _managing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message ?? _permissionLabel(result.status)),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wearables')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            const Text(
              'Your health data, interpreted in context.',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            if (_loading && _data == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              if (_error != null) ...[
                Text(
                  _error!,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
              if (_data != null) ...[
                _connectedHealth(_data!),
                const SizedBox(height: 16),
                _today(_data!),
                const SizedBox(height: 16),
                _baseline(_data!),
                const SizedBox(height: 16),
                _recovery(_data!),
                const SizedBox(height: 16),
                _trends(_data!),
                if (_data!.coachInsight != null) ...[
                  const SizedBox(height: 16),
                  _coachInsight(_data!.coachInsight!),
                ],
                const SizedBox(height: 16),
                _manageDevices(_data!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _connectedHealth(WearablesHubData data) => _HubCard(
    title: 'Connected Health',
    icon: Icons.watch_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data.source.displayName, style: _titleStyle),
        const SizedBox(height: 5),
        Text(_permissionLabel(data.source.permissionStatus), style: _bodyStyle),
        const SizedBox(height: 4),
        Text(
          data.source.dataAvailable
              ? 'Health data available through Apple Health'
              : 'No current health data is available.',
          style: _bodyStyle,
        ),
        if (data.source.lastSuccessfulSync != null) ...[
          const SizedBox(height: 4),
          Text(
            'Last sync: ${_dateTime(data.source.lastSuccessfulSync!)}',
            style: _bodyStyle,
          ),
        ],
      ],
    ),
  );

  Widget _today(WearablesHubData data) {
    final today = data.today;
    final metrics = <Widget>[
      _metric('Steps', today?.steps.value?.toString(), today?.steps.status),
      _metric(
        'Active energy',
        _number(today?.activeEnergyKilocalories.value, 'kcal'),
        today?.activeEnergyKilocalories.status,
      ),
      _metric(
        'Sleep',
        _duration(today?.sleepDuration.value),
        today?.sleepDuration.status,
      ),
      _metric(
        'Resting HR',
        _number(today?.restingHeartRateBpm.value, 'bpm'),
        today?.restingHeartRateBpm.status,
      ),
      _metric(
        'Average HR',
        _number(today?.averageHeartRateBpm.value, 'bpm'),
        today?.averageHeartRateBpm.status,
      ),
      _metric(
        'Distance',
        _distance(today?.distanceMeters.value),
        today?.distanceMeters.status,
      ),
      _metric(
        'Workout time',
        _duration(today?.workoutDuration.value),
        today?.workoutDuration.status,
      ),
      _metric(
        'Body weight',
        _weight(today?.bodyWeightKilograms.value),
        today?.bodyWeightKilograms.status,
        contextual: true,
      ),
    ];
    return _HubCard(
      title: 'Today',
      icon: Icons.today_outlined,
      child: GridView.count(
        crossAxisCount: 2,
        childAspectRatio: 1.55,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: metrics,
      ),
    );
  }

  Widget _baseline(WearablesHubData data) {
    final recovery = data.recoveryContext;
    return _HubCard(
      title: 'Your Baseline',
      icon: Icons.compare_arrows_outlined,
      child: recovery == null
          ? Text(
              'Not enough reliable history for personal comparisons.',
              style: _bodyStyle,
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _baselineLine('Sleep', recovery.sleepContext),
                const SizedBox(height: 8),
                _baselineLine(
                  'Resting heart rate',
                  recovery.restingHeartRateContext,
                ),
                const SizedBox(height: 8),
                _baselineLine('Activity', recovery.recentActivityContext),
              ],
            ),
    );
  }

  Widget _recovery(WearablesHubData data) {
    final state = data.recoveryContext?.overallState;
    final text = switch (state) {
      RecoveryContextState.caution =>
        'Your recent validated signals suggest recovery deserves more attention today.',
      RecoveryContextState.favorable =>
        'Your recent signals look favorable relative to your baseline. Continue your existing plan without adding intensity.',
      RecoveryContextState.normal =>
        'Your recent signals remain near your usual pattern.',
      RecoveryContextState.insufficientData || null =>
        'Not enough validated history for a reliable recovery interpretation.',
    };
    return _HubCard(
      title: 'Recovery & Training',
      icon: Icons.self_improvement_outlined,
      child: Text(text, style: _bodyStyle),
    );
  }

  Widget _trends(WearablesHubData data) => _HubCard(
    title: '7-Day Trend',
    icon: Icons.trending_up_outlined,
    child: Column(
      children: data.trends
          .map(
            (trend) => ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(
                trend.metric,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${trend.description} ${trend.coverageDays}/7 days available.',
              ),
              trailing: Icon(
                _trendIcon(trend.direction),
                color: AppTheme.primaryGreen,
              ),
            ),
          )
          .toList(),
    ),
  );

  Widget _coachInsight(WearablesCoachInsight insight) => _HubCard(
    title: 'Coach Insight',
    icon: Icons.psychology_outlined,
    tint: AppTheme.visionCard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(insight.insight, style: _bodyStyle),
        const SizedBox(height: 12),
        const Text(
          'Next action',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(insight.nextAction, style: _bodyStyle),
      ],
    ),
  );

  Widget _manageDevices(WearablesHubData data) => _HubCard(
    title: 'Manage Devices',
    icon: Icons.settings_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Apple Health permissions are controlled by iOS and the Health app. MuscleUp only reads the health categories you allow.',
          style: _bodyStyle,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: _managing ? null : _requestPermissions,
              icon: const Icon(Icons.health_and_safety_outlined),
              label: Text(
                data.source.permissionStatus == WearablePermissionStatus.denied
                    ? 'Request access'
                    : 'Review permissions',
              ),
            ),
            OutlinedButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _metric(
    String label,
    String? value,
    WearableValidationStatus? status, {
    bool contextual = false,
  }) {
    final display = value ?? _metricUnavailable(status);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            display,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (contextual)
            const Text(
              'Context only',
              style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }

  Widget _baselineLine(String label, RecoveryMetricContext metric) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Flexible(
        child: Text(
          _baselineText(metric),
          textAlign: TextAlign.end,
          style: _bodyStyle,
        ),
      ),
    ],
  );

  String _baselineText(RecoveryMetricContext metric) {
    if (metric.state == RecoveryContextState.insufficientData ||
        metric.personalBaseline == null ||
        metric.latestValue == null) {
      return 'Insufficient history';
    }
    final difference = metric.latestValue! - metric.personalBaseline!;
    if (difference.abs() < (metric.unit == 'minutes' ? 15 : 3)) {
      return 'Near your usual range';
    }
    final amount = difference.abs().round();
    return '$amount ${metric.unit ?? ''} ${difference > 0 ? 'above' : 'below'} your recent average';
  }

  String _permissionLabel(WearablePermissionStatus status) => switch (status) {
    WearablePermissionStatus.authorized => 'Authorized',
    WearablePermissionStatus.partiallyAuthorized => 'Partially authorized',
    WearablePermissionStatus.denied => 'Permission denied',
    WearablePermissionStatus.unavailable => 'Apple Health unavailable',
    WearablePermissionStatus.unsupportedPlatform =>
      'Unsupported on this platform',
  };
  String _metricUnavailable(WearableValidationStatus? status) =>
      switch (status) {
        WearableValidationStatus.stale => 'Stale data',
        WearableValidationStatus.implausible => 'Invalid data excluded',
        WearableValidationStatus.unavailable => 'Unavailable',
        WearableValidationStatus.missing ||
        WearableValidationStatus.valid ||
        null => 'Not available',
      };
  String? _number(double? value, String unit) =>
      value == null ? null : '${value.toStringAsFixed(0)} $unit';
  String? _duration(Duration? value) => value == null
      ? null
      : '${value.inHours}h ${value.inMinutes.remainder(60)}m';
  String? _distance(double? value) =>
      value == null ? null : '${(value / 1000).toStringAsFixed(1)} km';
  String? _weight(double? value) =>
      value == null ? null : '${value.toStringAsFixed(1)} kg';
  String _dateTime(DateTime value) =>
      '${value.toLocal().year}-${value.toLocal().month.toString().padLeft(2, '0')}-${value.toLocal().day.toString().padLeft(2, '0')} ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';
  IconData _trendIcon(WearableTrendDirection direction) => switch (direction) {
    WearableTrendDirection.increasing => Icons.trending_up,
    WearableTrendDirection.decreasing => Icons.trending_down,
    WearableTrendDirection.stable => Icons.trending_flat,
    WearableTrendDirection.insufficientData => Icons.remove,
  };
  TextStyle get _bodyStyle => const TextStyle(
    fontSize: 14,
    height: 1.45,
    color: AppTheme.textSecondary,
  );
  TextStyle get _titleStyle => const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  );
}

class _HubCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Color? tint;
  const _HubCard({
    required this.title,
    required this.icon,
    required this.child,
    this.tint,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: tint ?? AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primaryGreen),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}
