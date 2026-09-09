import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:future_project/models/wearable_data.dart';
import 'package:future_project/services/health/apple_health_service.dart';

class WearableDebugScreen extends StatefulWidget {
  const WearableDebugScreen({super.key});

  @override
  State<WearableDebugScreen> createState() => _WearableDebugScreenState();
}

class _WearableDebugScreenState extends State<WearableDebugScreen> {
  final _service = AppleHealthService();
  WearablePermissionResult? _permission;
  WearableData? _data;
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
        _permission = WearablePermissionResult(data.permissionStatus);
      });
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
            ],
          ),
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
            _metric('Steps', _number(_data!.steps?.toDouble(), 0)),
            _metric(
              'Active energy',
              _number(_data!.activeEnergyKilocalories, 1, suffix: ' kcal'),
            ),
            _metric(
              'Average heart rate',
              _number(_data!.averageHeartRateBpm, 1, suffix: ' bpm'),
            ),
            _metric(
              'Resting heart rate',
              _number(_data!.restingHeartRateBpm, 1, suffix: ' bpm'),
            ),
            _metric(
              'Distance',
              _number(_data!.distanceMeters, 0, suffix: ' m'),
            ),
            _metric('Sleep', _duration(_data!.sleepDuration)),
            _metric(
              'Body weight',
              _number(_data!.bodyWeightKilograms, 1, suffix: ' kg'),
            ),
            _metric('Workouts', '${_data!.workouts.length}'),
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

  Widget _metric(String label, String value) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: Text(value),
  );

  String _number(double? value, int decimals, {String suffix = ''}) =>
      value == null ? 'No data' : '${value.toStringAsFixed(decimals)}$suffix';

  String _duration(Duration? value) {
    if (value == null) return 'No data';
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }
}
