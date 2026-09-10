import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/models/wearable_history.dart';
import 'package:future_project/models/recovery_context.dart';
import 'package:future_project/services/health/apple_health_service.dart';
import 'package:future_project/services/health/recovery_context_service.dart';
import 'package:future_project/services/health/wearable_sync_service.dart';
import 'package:future_project/services/health/wearable_validation_service.dart';

class WearableDebugScreen extends StatefulWidget {
  const WearableDebugScreen({super.key});

  @override
  State<WearableDebugScreen> createState() => _WearableDebugScreenState();
}

class _WearableDebugScreenState extends State<WearableDebugScreen> {
  final _service = AppleHealthService();
  final _validator = const WearableValidationService();
  final _syncService = WearableSyncService();
  final _recoveryService = RecoveryContextService();
  WearablePermissionResult? _permission;
  WearableData? _data;
  ValidatedWearableData? _validated;
  WearableSyncResult? _syncResult;
  WearableDailyRecord? _latestRecord;
  RecoveryContext? _recoveryContext;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode, 'The wearable test screen is debug-only.');
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final result = await _service.permissionStatus();
    if (mounted) setState(() => _permission = result);
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _service.requestReadPermissions();
    if (!mounted) return;
    setState(() {
      _permission = result;
      _busy = false;
    });
  }

  Future<void> _readToday() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await _service.readToday();
      if (!mounted) return;
      setState(() {
        _data = data;
        _validated = _validator.validate(data);
        _permission = WearablePermissionResult(data.permissionStatus);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync() async {
    final validated = _validated;
    if (validated == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await _syncService.sync(validated);
    WearableDailyRecord? latest;
    if (result.isSuccess) {
      try {
        latest = await _syncService.loadLatest();
      } catch (_) {
        latest = result.record;
      }
    }
    if (!mounted) return;
    setState(() {
      _syncResult = result;
      _latestRecord = latest ?? _latestRecord;
      _busy = false;
    });
  }

  Future<void> _loadRecoveryContext() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final context = await _recoveryService.load();
      if (mounted) setState(() => _recoveryContext = context);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(title: const Text('Apple Health Test')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Status: ${_permission?.status.name ?? 'checking'}'),
          if (_permission?.message != null) ...[
            const SizedBox(height: 6),
            Text(_permission!.message!),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            children: [
              FilledButton(
                onPressed: _busy ? null : _requestPermissions,
                child: const Text('Request read permissions'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _readToday,
                child: const Text("Read today's metrics"),
              ),
              OutlinedButton(
                onPressed: _busy || _validated == null ? null : _sync,
                child: const Text('Sync validated data'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _loadRecoveryContext,
                child: const Text('Load recovery context'),
              ),
            ],
          ),
          if (_syncResult != null) ...[
            const SizedBox(height: 12),
            Text('Sync status: ${_syncResult!.status.name}'),
            if (_syncResult!.message != null) Text(_syncResult!.message!),
          ],
          if (_latestRecord != null) ...[
            const SizedBox(height: 6),
            Text(
              'Supabase daily record: ${_latestRecord!.localDateKey}\n'
              'Last successful sync: '
              '${_latestRecord!.syncedAt?.toLocal().toIso8601String() ?? 'unknown'}',
            ),
          ],
          if (_recoveryContext != null) ...[
            const SizedBox(height: 18),
            Text(
              'Recovery Context',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Overall: ${_recoveryContext!.overallState.name}'),
            _recoveryMetric('Sleep', _recoveryContext!.sleepContext),
            _recoveryMetric(
              'Resting HR',
              _recoveryContext!.restingHeartRateContext,
            ),
            _recoveryMetric(
              'Recent activity',
              _recoveryContext!.recentActivityContext,
            ),
            Text(
              'Workouts: ${_recoveryContext!.recentWorkoutContext.state.name} '
              '(${_recoveryContext!.recentWorkoutContext.completedSessionsLast7Days} completed / 7 days)',
            ),
            Text(
              'Coverage: ${_recoveryContext!.dataCoverage.wearableDays} wearable days, '
              '${_recoveryContext!.dataCoverage.comparableComponents} comparable components',
            ),
            Text(
              'Evidence: ${_recoveryContext!.evidence.map((item) => item.name).join(', ')}',
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 18),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 18),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
          if (_data != null) ...[
            const SizedBox(height: 22),
            _metric(
              'Steps',
              _number(_data!.steps?.toDouble(), 0),
              _validated!.steps,
              (value) => '$value',
            ),
            _metric(
              'Active energy',
              _number(_data!.activeEnergyKilocalories, 1, suffix: ' kcal'),
              _validated!.activeEnergyKilocalories,
              (value) => '${value.toStringAsFixed(1)} kcal',
            ),
            _metric(
              'Average heart rate',
              _number(_data!.averageHeartRateBpm, 1, suffix: ' bpm'),
              _validated!.averageHeartRateBpm,
              (value) => '${value.toStringAsFixed(1)} bpm',
            ),
            _metric(
              'Resting heart rate',
              _number(_data!.restingHeartRateBpm, 1, suffix: ' bpm'),
              _validated!.restingHeartRateBpm,
              (value) => '${value.toStringAsFixed(1)} bpm',
            ),
            _metric(
              'Distance',
              _number(_data!.distanceMeters, 0, suffix: ' m'),
              _validated!.distanceMeters,
              (value) => '${value.toStringAsFixed(0)} m',
            ),
            _metric(
              'Sleep',
              _duration(_data!.sleepDuration),
              _validated!.sleepDuration,
              _duration,
            ),
            _metric(
              'Body weight',
              _number(_data!.bodyWeightKilograms, 1, suffix: ' kg'),
              _validated!.bodyWeightKilograms,
              (value) => '${value.toStringAsFixed(1)} kg (context only)',
            ),
            _metric(
              'Workouts',
              '${_data!.workouts.length}',
              _validated!.workouts,
              (value) => '${value.length}',
            ),
            _metric(
              'Workout duration',
              _duration(
                _data!.workouts.isEmpty
                    ? null
                    : _data!.workouts.fold<Duration>(
                        Duration.zero,
                        (total, workout) => total + workout.duration,
                      ),
              ),
              _validated!.workoutDuration,
              _duration,
            ),
            for (final workout in _data!.workouts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(workout.activityType),
                subtitle: Text(
                  '${_duration(workout.duration)} · ${workout.sourceName}',
                ),
              ),
            if (_data!.unavailableMetrics.isNotEmpty)
              Text(
                'Unavailable: ${_data!.unavailableMetrics.join(', ')}',
                style: const TextStyle(color: Colors.orange),
              ),
          ],
        ],
      ),
    );
  }

  Widget _metric<T>(
    String label,
    String rawValue,
    ValidatedWearableMetric<T> metric,
    String Function(T value) format,
  ) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(
      '$rawValue\n${metric.status.name.toUpperCase()}\n'
      '${metric.isSentToProgressEngine ? 'Sent to Progress Engine: ${format(metric.value as T)}' : 'Not sent'}',
    ),
    isThreeLine: true,
  );

  Widget _recoveryMetric(String label, RecoveryMetricContext metric) {
    final latest = metric.latestValue?.toStringAsFixed(1) ?? 'missing';
    final baseline = metric.personalBaseline?.toStringAsFixed(1) ?? 'n/a';
    return Text(
      '$label: ${metric.state.name}; latest $latest ${metric.unit ?? ''}; '
      'baseline $baseline (${metric.baselineDays} days); '
      '${metric.evidence.map((item) => item.name).join(', ')}',
    );
  }

  String _number(double? value, int decimals, {String suffix = ''}) =>
      value == null ? 'No data' : '${value.toStringAsFixed(decimals)}$suffix';

  String _duration(Duration? value) {
    if (value == null) return 'No data';
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
