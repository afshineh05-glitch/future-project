import 'package:flutter/material.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/models/unified_coach_context.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/wearables_hub.dart';
import 'package:future_project/services/ble/ble_device_manager.dart';
import 'package:future_project/services/wearables_hub_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/ble_device_management_card.dart';

enum WearablesSyncUiState { idle, syncing, success, failure }

class WearablesHubScreen extends StatefulWidget {
  final Future<WearablesHubData> Function()? loadData;
  final Future<WearablePermissionResult> Function()? requestPermissions;
  final Widget? bleDeviceCard;

  const WearablesHubScreen({
    super.key,
    this.loadData,
    this.requestPermissions,
    this.bleDeviceCard,
  });

  @override
  State<WearablesHubScreen> createState() => _WearablesHubScreenState();
}

class _WearablesHubScreenState extends State<WearablesHubScreen> {
  WearablesHubService? _service;
  WearablesHubData? _data;
  bool _loading = true;
  bool _managingPermissions = false;
  WearablesSyncUiState _syncState = WearablesSyncUiState.idle;
  String? _error;
  BleDeviceManagerState? _bleState;
  BleDeviceManager? _bleManager;

  @override
  void initState() {
    super.initState();
    if (widget.loadData == null || widget.requestPermissions == null) {
      _service = WearablesHubService();
    }
    if (widget.bleDeviceCard == null) {
      _bleManager = BleDeviceManager.production();
    }
    _load();
  }

  @override
  void dispose() {
    _bleManager?.dispose();
    super.dispose();
  }

  Future<bool> _load({bool showLoading = true}) async {
    if (showLoading && mounted) setState(() => _loading = true);
    try {
      final data = await (widget.loadData?.call() ?? _service!.load());
      if (mounted) {
        setState(() {
          _data = data;
          _error = null;
        });
      }
      return true;
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Wearable data could not be loaded right now.');
      }
      return false;
    } finally {
      if (showLoading && mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncNow() async {
    if (_syncState == WearablesSyncUiState.syncing) return;
    setState(() => _syncState = WearablesSyncUiState.syncing);
    try {
      final succeeded = await _load(showLoading: false);
      if (mounted) {
        setState(
          () => _syncState = succeeded
              ? WearablesSyncUiState.success
              : WearablesSyncUiState.failure,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _syncState = WearablesSyncUiState.failure);
    }
  }

  Future<void> _requestPermissions() async {
    if (_managingPermissions) return;
    setState(() => _managingPermissions = true);
    try {
      final result =
          await (widget.requestPermissions?.call() ??
              _service!.requestPermissions());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? permissionLabel(result.status)),
        ),
      );
      await _load(showLoading: false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Apple Health permissions could not be opened.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _managingPermissions = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Wearables')),
      body: RefreshIndicator(
        onRefresh: _syncNow,
        child: LayoutBuilder(
          builder: (context, constraints) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: _buildContent(constraints.maxWidth),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(double viewportWidth) {
    if (_loading && _data == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final data = _data;
    if (data == null) {
      return _CompactEmptyState(
        message: _error ?? 'Wearables are unavailable right now.',
        actionLabel: 'Try again',
        onAction: () {
          _load();
        },
      );
    }
    final unavailable = isConnectionUnavailable(data.source.permissionStatus);
    final bleHeartRate = _bleState?.latestHeartRateBpm;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _hero(viewportWidth),
        const SizedBox(height: 28),
        _sectionHeading(
          'Connect Your Device',
          'Bring your health and activity data together in MuscleUp.',
        ),
        const SizedBox(height: 12),
        _providerGrid(data, viewportWidth),
        const SizedBox(height: 28),
        _sectionHeading(
          'Connected Devices',
          'Only devices and health sources MuscleUp can confirm appear here.',
        ),
        const SizedBox(height: 12),
        _connectedDevices(data),
        const SizedBox(height: 28),
        _sectionHeading(
          'Your Data at a Glance',
          'Validated health data from your connected sources.',
        ),
        const SizedBox(height: 12),
        if ((unavailable || !data.source.dataAvailable) &&
            bleHeartRate == null) ...[
          _CompactEmptyState(
            message: connectionEmptyMessage(data.source.permissionStatus),
            actionLabel: canRequestPermissions(data.source.permissionStatus)
                ? 'Review Apple Health'
                : null,
            onAction: canRequestPermissions(data.source.permissionStatus)
                ? _requestPermissions
                : null,
          ),
        ] else ...[
          _today(data, viewportWidth, bleHeartRateBpm: bleHeartRate),
          const SizedBox(height: 14),
          _coachInsight(data.unifiedCoachContext),
          const SizedBox(height: 14),
          _sevenDayOverview(data),
          const SizedBox(height: 14),
          _baseline(data),
        ],
        const SizedBox(height: 30),
        _motivation(),
      ],
    );
  }

  Widget _hero(double viewportWidth) {
    final compact = viewportWidth < 560;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Wearables',
          style: TextStyle(
            fontSize: 36,
            height: 1.05,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Your health. Everywhere with you.',
          style: TextStyle(
            fontSize: 20,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Connect your favorite devices to get automatic data, better insights, and a more personalized coaching experience.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
    final visual = Container(
      key: const ValueKey('wearables_hero_visual'),
      width: compact ? double.infinity : 190,
      height: compact ? 126 : 176,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF8F1), Color(0xFFD8F0E4)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .88),
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x190E6245),
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.watch_rounded,
            size: 58,
            color: AppTheme.primaryGreen,
          ),
          const Positioned(
            right: 18,
            top: 18,
            child: Icon(
              Icons.favorite_rounded,
              size: 24,
              color: Color(0xFFE26068),
            ),
          ),
          const Positioned(
            left: 18,
            bottom: 18,
            child: Icon(Icons.bolt_rounded, size: 25, color: Color(0xFFE79B3F)),
          ),
        ],
      ),
    );
    return Container(
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D172D26),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 20), visual],
            )
          : Row(
              children: [
                Expanded(child: copy),
                const SizedBox(width: 28),
                visual,
              ],
            ),
    );
  }

  Widget _sectionHeading(String title, String subtitle) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(subtitle, style: _smallStyle),
    ],
  );

  Widget _providerGrid(WearablesHubData data, double viewportWidth) {
    final columns = viewportWidth >= 700
        ? 3
        : viewportWidth >= 480
        ? 2
        : 1;
    final gap = 12.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: width, child: _manageDevices(data)),
            for (final provider in const [
              (
                'WHOOP',
                Icons.monitor_heart_outlined,
                'Recovery, strain, and sleep',
              ),
              (
                'Garmin',
                Icons.directions_run_rounded,
                'Activity, workouts, and heart rate',
              ),
              (
                'Fitbit',
                Icons.grid_view_rounded,
                'Daily activity, sleep, and heart rate',
              ),
              (
                'Polar',
                Icons.favorite_border_rounded,
                'Training and heart-rate data',
              ),
              ('Oura', Icons.circle_outlined, 'Sleep, activity, and recovery'),
            ])
              SizedBox(
                width: width,
                child: _UnavailableProviderCard(
                  name: provider.$1,
                  icon: provider.$2,
                  description: provider.$3,
                ),
              ),
            SizedBox(
              width: columns == 1 ? width : constraints.maxWidth,
              child:
                  widget.bleDeviceCard ??
                  BleDeviceManagementCard(
                    manager: _bleManager,
                    onStateChanged: _onBleStateChanged,
                  ),
            ),
          ],
        );
      },
    );
  }

  Widget _connectedDevices(WearablesHubData data) {
    final appleConnected =
        data.source.permissionStatus == WearablePermissionStatus.authorized ||
        data.source.permissionStatus ==
            WearablePermissionStatus.partiallyAuthorized;
    final bleConnected = _bleState?.connectedDevice;
    if (!appleConnected && bleConnected == null) {
      return const _CompactEmptyState(
        message: 'No confirmed health sources or devices are connected yet.',
      );
    }
    return Column(
      children: [
        if (appleConnected) _connectedHealth(data),
        if (appleConnected && bleConnected != null) const SizedBox(height: 10),
        if (bleConnected != null)
          _ConnectedBleDeviceCard(
            device: bleConnected,
            onDisconnect: _bleManager?.disconnect,
          ),
      ],
    );
  }

  void _onBleStateChanged(BleDeviceManagerState state) {
    if (!mounted || identical(_bleState, state)) return;
    setState(() => _bleState = state);
  }

  Widget _motivation() => Container(
    key: const ValueKey('wearables_motivation'),
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: const Color(0xFF123E31),
      borderRadius: BorderRadius.circular(28),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Better data.\nA stronger you.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 28,
            height: 1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Connect your wearable and let your data guide you towards your next milestone.',
          style: TextStyle(color: Color(0xFFD9E9E3), height: 1.45),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 14,
          runSpacing: 10,
          children: const [
            _BenefitItem('More accurate tracking'),
            _BenefitItem('Personalized coaching'),
            _BenefitItem('Reach your goals faster'),
            _BenefitItem('Your data stays private'),
          ],
        ),
      ],
    ),
  );

  Widget _connectedHealth(WearablesHubData data) => Material(
    color: AppTheme.card,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => _showHealthDetails(data),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            const _IconBadge(icon: Icons.favorite_outline),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          data.source.displayName,
                          style: _titleStyle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      _StatusDot(status: data.source.permissionStatus),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    permissionSupportingText(data.source.permissionStatus),
                    style: _smallStyle,
                  ),
                  if (data.source.lastSuccessfulSync != null)
                    Text(
                      'Synced ${compactDateTime(data.source.lastSuccessfulSync!)}',
                      style: _smallStyle,
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    ),
  );

  Widget _today(
    WearablesHubData data,
    double viewportWidth, {
    double? bleHeartRateBpm,
  }) {
    final today = data.today;
    final recovery = data.recoveryContext;
    final items = [
      _PrimaryMetricData(
        keyName: 'steps',
        label: 'Steps',
        icon: Icons.directions_walk,
        color: AppTheme.aiBlue,
        value: today?.steps.value?.toString(),
        status: today?.steps.status,
        support: baselineSupport(
          recovery?.recentActivityContext,
          expectedUnit: 'steps',
        ),
      ),
      _PrimaryMetricData(
        keyName: 'sleep',
        label: 'Sleep',
        icon: Icons.bedtime_outlined,
        color: const Color(0xFF7C6DD8),
        value: durationText(today?.sleepDuration.value),
        status: today?.sleepDuration.status,
        support: baselineSupport(recovery?.sleepContext),
      ),
      _PrimaryMetricData(
        keyName: 'active_energy',
        label: 'Active Energy',
        icon: Icons.local_fire_department_outlined,
        color: const Color(0xFFE58A3A),
        value: numberText(today?.activeEnergyKilocalories.value, 'kcal'),
        status: today?.activeEnergyKilocalories.status,
        support: baselineSupport(
          recovery?.recentActivityContext,
          expectedUnit: 'kcal',
        ),
      ),
      _PrimaryMetricData(
        keyName: 'resting_hr',
        label: today?.restingHeartRateBpm.value != null
            ? 'Resting HR'
            : 'Heart Rate',
        icon: Icons.monitor_heart_outlined,
        color: const Color(0xFFD85C68),
        value: numberText(
          today?.restingHeartRateBpm.value ??
              today?.averageHeartRateBpm.value ??
              bleHeartRateBpm,
          'bpm',
        ),
        status:
            today?.restingHeartRateBpm.status ??
            today?.averageHeartRateBpm.status ??
            (bleHeartRateBpm == null ? null : WearableValidationStatus.valid),
        support: today?.restingHeartRateBpm.value != null
            ? baselineSupport(recovery?.restingHeartRateContext)
            : bleHeartRateBpm != null
            ? 'Current validated BLE reading'
            : 'Not enough history yet',
      ),
    ];
    final columns = viewportWidth >= 680 ? 4 : 2;
    return _SectionCard(
      title: 'Today',
      trailing: TextButton(
        onPressed: () => _showAllHealthData(data),
        child: const Text('View all health data'),
      ),
      child: GridView.builder(
        itemCount: items.length,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          mainAxisExtent: 150,
        ),
        itemBuilder: (context, index) => _PrimaryMetricCard(data: items[index]),
      ),
    );
  }

  Widget _coachInsight(UnifiedCoachContext context) => _SectionCard(
    title: 'Coach Insight',
    tint: AppTheme.visionCard,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.primaryInsight, style: _bodyStyle),
        const SizedBox(height: 10),
        const Text(
          'Next action',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          context.primaryAction,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _sevenDayOverview(WearablesHubData data) {
    final rows = <WearablesOverviewRowData>[
      overviewRow(
        'Sleep',
        data.history,
        (row) => row.sleepMinutes?.toDouble(),
        'minutes',
      ),
      overviewRow(
        'Steps',
        data.history,
        (row) => row.steps?.toDouble(),
        'steps',
      ),
      overviewRow(
        'Active Energy',
        data.history,
        (row) => row.activeEnergyKilocalories,
        'kcal',
      ),
      overviewRow(
        'Resting HR',
        data.history,
        (row) => row.restingHeartRateBpm,
        'bpm',
      ),
    ];
    return _SectionCard(
      title: '7-Day Overview',
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _OverviewRow(data: rows[index]),
            if (index != rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _baseline(WearablesHubData data) {
    final recovery = data.recoveryContext;
    return _SectionCard(
      title: 'Your Baseline',
      child: recovery == null
          ? const Text('Not enough history yet', style: _bodyStyle)
          : Column(
              children: [
                _BaselineRow(
                  label: 'Sleep',
                  value: baselineValue(recovery.sleepContext),
                ),
                const SizedBox(height: 10),
                _BaselineRow(
                  label: 'Resting HR',
                  value: baselineValue(recovery.restingHeartRateContext),
                ),
                const SizedBox(height: 10),
                _BaselineRow(
                  label: 'Activity',
                  value: baselineValue(recovery.recentActivityContext),
                ),
              ],
            ),
    );
  }

  Widget _manageDevices(WearablesHubData data) {
    final unsupported =
        data.source.permissionStatus ==
        WearablePermissionStatus.unsupportedPlatform;
    final canSync =
        data.source.permissionStatus == WearablePermissionStatus.authorized ||
        data.source.permissionStatus ==
            WearablePermissionStatus.partiallyAuthorized;
    return _SectionCard(
      title: 'Apple Health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _IconBadge(icon: Icons.favorite_outline, size: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      permissionLabel(data.source.permissionStatus),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Text(
                      'Activity, sleep, heart rate, and workouts',
                      style: _smallStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            unsupported
                ? 'Apple Health permissions are available on supported iOS devices.'
                : 'Apple Health permissions are controlled by iOS and the Health app. MuscleUp reads only the categories you allow.',
            style: _smallStyle,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!unsupported)
                OutlinedButton(
                  onPressed: _managingPermissions ? null : _requestPermissions,
                  child: Text(_managingPermissions ? 'Opening…' : 'Manage'),
                ),
              if (canSync)
                OutlinedButton.icon(
                  key: const ValueKey('wearables_sync_button'),
                  onPressed: _syncState == WearablesSyncUiState.syncing
                      ? null
                      : _syncNow,
                  icon: _syncState == WearablesSyncUiState.syncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, size: 18),
                  label: Text(
                    _syncState == WearablesSyncUiState.syncing
                        ? 'Syncing…'
                        : 'Sync now',
                  ),
                ),
            ],
          ),
          if (_syncState == WearablesSyncUiState.success)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sync complete',
                style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen),
              ),
            )
          else if (_syncState == WearablesSyncUiState.failure)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Sync could not be completed',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
        ],
      ),
    );
  }

  void _showAllHealthData(WearablesHubData data) {
    final today = data.today;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'All health data',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                label: 'Average HR',
                value:
                    numberText(today?.averageHeartRateBpm.value, 'bpm') ??
                    metricUnavailable(today?.averageHeartRateBpm.status),
              ),
              _DetailRow(
                label: 'Distance',
                value:
                    distanceText(today?.distanceMeters.value) ??
                    metricUnavailable(today?.distanceMeters.status),
              ),
              _DetailRow(
                label: 'Workout Duration',
                value:
                    durationText(today?.workoutDuration.value) ??
                    metricUnavailable(today?.workoutDuration.status),
              ),
              _DetailRow(
                label: 'Body Weight',
                value:
                    '${weightText(today?.bodyWeightKilograms.value) ?? metricUnavailable(today?.bodyWeightKilograms.status)} · Context only',
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHealthDetails(WearablesHubData data) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.source.displayName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                permissionSupportingText(data.source.permissionStatus),
                style: _bodyStyle,
              ),
              if (safeStatusMessage(data.source.statusMessage)
                  case final message?) ...[
                const SizedBox(height: 8),
                Text(message, style: _smallStyle),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

bool isConnectionUnavailable(WearablePermissionStatus status) =>
    status == WearablePermissionStatus.denied ||
    status == WearablePermissionStatus.unavailable ||
    status == WearablePermissionStatus.unsupportedPlatform;

String? safeStatusMessage(String? message) {
  if (message == null || message.trim().isEmpty) return null;
  final technical = RegExp(
    r'(unimplementederror|exception|stack trace|flutter_reactive_ble)',
    caseSensitive: false,
  );
  return technical.hasMatch(message)
      ? 'This health source is unavailable right now.'
      : message.trim();
}

bool canRequestPermissions(WearablePermissionStatus status) =>
    status != WearablePermissionStatus.unsupportedPlatform &&
    status != WearablePermissionStatus.unavailable;

String connectionEmptyMessage(
  WearablePermissionStatus status,
) => switch (status) {
  WearablePermissionStatus.denied =>
    'Review Apple Health permissions to see your personal health picture.',
  WearablePermissionStatus.unsupportedPlatform =>
    'Apple Health is available on supported iOS devices.',
  WearablePermissionStatus.unavailable =>
    'Apple Health is unavailable right now. The rest of MuscleUp remains available.',
  WearablePermissionStatus.authorized ||
  WearablePermissionStatus.partiallyAuthorized =>
    'Apple Health is connected, but no validated health data is available yet.',
};

String permissionLabel(WearablePermissionStatus status) => switch (status) {
  WearablePermissionStatus.authorized => 'Connected',
  WearablePermissionStatus.partiallyAuthorized => 'Partially connected',
  WearablePermissionStatus.denied => 'Permission denied',
  WearablePermissionStatus.unavailable => 'Unavailable',
  WearablePermissionStatus.unsupportedPlatform =>
    'Unsupported on this platform',
};

String permissionSupportingText(WearablePermissionStatus status) =>
    switch (status) {
      WearablePermissionStatus.authorized =>
        'Health data available through Apple Health',
      WearablePermissionStatus.partiallyAuthorized =>
        'Some health data is unavailable.',
      WearablePermissionStatus.denied =>
        'Review access in Apple Health permissions.',
      WearablePermissionStatus.unavailable =>
        'Apple Health could not be reached.',
      WearablePermissionStatus.unsupportedPlatform =>
        'Apple Health requires a supported iOS device.',
    };

String baselineSupport(RecoveryMetricContext? metric, {String? expectedUnit}) {
  if (metric == null ||
      metric.state == RecoveryContextState.insufficientData ||
      metric.latestValue == null ||
      metric.personalBaseline == null ||
      (expectedUnit != null && metric.unit != expectedUnit)) {
    return 'Not enough history yet';
  }
  final difference = metric.latestValue! - metric.personalBaseline!;
  final threshold = metric.unit == 'minutes'
      ? 15
      : metric.unit == 'bpm'
      ? 3
      : metric.personalBaseline! * .08;
  if (difference.abs() <= threshold) return 'Near your usual range';
  return '${difference.abs().round()} ${metric.unit ?? ''} ${difference > 0 ? 'above' : 'below'} your recent average';
}

String baselineValue(RecoveryMetricContext metric) {
  final baseline = metric.personalBaseline;
  if (baseline == null || metric.baselineDays == 0) {
    return 'Not enough history yet';
  }
  if (metric.unit == 'minutes') {
    return '${durationText(Duration(minutes: baseline.round()))} recent average';
  }
  return '${baseline.toStringAsFixed(metric.unit == 'bpm' ? 0 : 0)} ${metric.unit ?? ''} recent average';
}

WearablesOverviewRowData overviewRow(
  String label,
  List<WearableDailyRecord> history,
  double? Function(WearableDailyRecord) select,
  String unit,
) {
  final values = history.map(select).nonNulls.toList();
  if (values.length < 3) {
    return WearablesOverviewRowData(
      label: label,
      value: 'Need more history',
      coverage: values.length,
    );
  }
  final average = values.reduce((a, b) => a + b) / values.length;
  final value = unit == 'minutes'
      ? '${durationText(Duration(minutes: average.round()))} avg'
      : '${average.toStringAsFixed(0)} $unit avg';
  return WearablesOverviewRowData(
    label: label,
    value: value,
    coverage: values.length,
  );
}

String metricUnavailable(WearableValidationStatus? status) => switch (status) {
  WearableValidationStatus.stale => 'Stale data',
  WearableValidationStatus.implausible => 'Invalid data excluded',
  WearableValidationStatus.unavailable => 'Unavailable',
  WearableValidationStatus.missing ||
  WearableValidationStatus.valid ||
  null => 'Not available',
};

String? numberText(double? value, String unit) =>
    value == null ? null : '${value.toStringAsFixed(0)} $unit';
String? durationText(Duration? value) => value == null
    ? null
    : '${value.inHours}h ${value.inMinutes.remainder(60)}m';
String? distanceText(double? value) =>
    value == null ? null : '${(value / 1000).toStringAsFixed(1)} km';
String? weightText(double? value) =>
    value == null ? null : '${value.toStringAsFixed(1)} kg';
String compactDateTime(DateTime value) =>
    '${value.toLocal().month}/${value.toLocal().day} at ${value.toLocal().hour.toString().padLeft(2, '0')}:${value.toLocal().minute.toString().padLeft(2, '0')}';

const _bodyStyle = TextStyle(
  fontSize: 14,
  height: 1.45,
  color: AppTheme.textSecondary,
);
const _smallStyle = TextStyle(
  fontSize: 12,
  height: 1.35,
  color: AppTheme.textSecondary,
);
const _titleStyle = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w800,
  color: AppTheme.textPrimary,
);

class _PrimaryMetricData {
  final String keyName;
  final String label;
  final IconData icon;
  final Color color;
  final String? value;
  final WearableValidationStatus? status;
  final String support;
  const _PrimaryMetricData({
    required this.keyName,
    required this.label,
    required this.icon,
    required this.color,
    this.value,
    this.status,
    required this.support,
  });
}

class _PrimaryMetricCard extends StatelessWidget {
  final _PrimaryMetricData data;
  const _PrimaryMetricCard({required this.data});
  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('primary_metric_${data.keyName}'),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: data.color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: data.color.withValues(alpha: .16)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(data.icon, size: 17, color: data.color),
        const SizedBox(height: 7),
        Text(data.label, style: _smallStyle),
        const SizedBox(height: 2),
        Text(
          data.value ?? metricUnavailable(data.status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          data.support,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}

class WearablesOverviewRowData {
  final String label;
  final String value;
  final int coverage;
  const WearablesOverviewRowData({
    required this.label,
    required this.value,
    required this.coverage,
  });
}

class _OverviewRow extends StatelessWidget {
  final WearablesOverviewRowData data;
  const _OverviewRow({required this.data});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          data.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            data.value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          if (data.coverage > 0)
            Text('${data.coverage}/7 days', style: _smallStyle),
        ],
      ),
    ],
  );
}

class _BaselineRow extends StatelessWidget {
  final String label;
  final String value;
  const _BaselineRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
      Flexible(
        child: Text(value, textAlign: TextAlign.end, style: _smallStyle),
      ),
    ],
  );
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      children: [
        Expanded(child: Text(label)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    ),
  );
}

class _StatusDot extends StatelessWidget {
  final WearablePermissionStatus status;
  const _StatusDot({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = status == WearablePermissionStatus.authorized
        ? AppTheme.successGreen
        : status == WearablePermissionStatus.partiallyAuthorized
        ? AppTheme.gold
        : AppTheme.textSecondary;
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconBadge({required this.icon, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppTheme.visionCard,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, size: size * .5, color: AppTheme.primaryGreen),
  );
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? tint;
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
    this.tint,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: tint ?? AppTheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Text(title, style: _titleStyle),
            ?trailing,
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _CompactEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  const _CompactEmptyState({
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('wearables_compact_empty_state'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.visionCard,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        const Icon(Icons.info_outline, color: AppTheme.primaryGreen),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: _bodyStyle)),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    ),
  );
}

class _UnavailableProviderCard extends StatelessWidget {
  final String name;
  final IconData icon;
  final String description;

  const _UnavailableProviderCard({
    required this.name,
    required this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('wearable_provider_${name.toLowerCase()}'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08172D26),
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _IconBadge(icon: icon, size: 38),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: _titleStyle)),
          ],
        ),
        const SizedBox(height: 10),
        Text(description, style: _smallStyle),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Not connected',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
            ),
            TextButton(onPressed: null, child: Text('Connect')),
          ],
        ),
      ],
    ),
  );
}

class _BenefitItem extends StatelessWidget {
  final String label;
  const _BenefitItem(this.label);

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 240,
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_rounded,
          size: 17,
          color: Color(0xFF7DD5AC),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ConnectedBleDeviceCard extends StatelessWidget {
  final BleDiscoveredDevice device;
  final VoidCallback? onDisconnect;

  const _ConnectedBleDeviceCard({
    required this.device,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('connected_ble_device'),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        const _IconBadge(icon: Icons.bluetooth_connected, size: 42),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                device.name,
                overflow: TextOverflow.ellipsis,
                style: _titleStyle,
              ),
              Text('Connected · ${device.id}', style: _smallStyle),
            ],
          ),
        ),
        TextButton(onPressed: onDisconnect, child: const Text('Disconnect')),
      ],
    ),
  );
}
