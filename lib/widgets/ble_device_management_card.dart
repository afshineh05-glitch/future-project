import 'package:flutter/material.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_device_manager.dart';
import 'package:future_project/theme/app_theme.dart';

class BleDeviceManagementCard extends StatefulWidget {
  final BleDeviceManager? manager;
  final ValueChanged<BleDeviceManagerState>? onStateChanged;

  const BleDeviceManagementCard({super.key, this.manager, this.onStateChanged});

  @override
  State<BleDeviceManagementCard> createState() =>
      _BleDeviceManagementCardState();
}

class _BleDeviceManagementCardState extends State<BleDeviceManagementCard> {
  late final BleDeviceManager _manager;
  late final bool _ownsManager;

  @override
  void initState() {
    super.initState();
    _ownsManager = widget.manager == null;
    _manager = widget.manager ?? BleDeviceManager.production();
    _manager.addListener(_changed);
    _manager.initialize();
  }

  void _changed() {
    if (mounted) {
      setState(() {});
      widget.onStateChanged?.call(_manager.state);
    }
  }

  @override
  void dispose() {
    _manager.removeListener(_changed);
    if (_ownsManager) _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _manager.state;
    return Container(
      key: const ValueKey('ble_device_management'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.visionCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.bluetooth,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bluetooth wearables',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Supported non-Apple devices',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (state.connectedDevice != null)
                const _ConnectionBadge(label: 'Connected'),
            ],
          ),
          const SizedBox(height: 12),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                state.errorMessage!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          if (state.connectedDevice case final connected?)
            Row(
              children: [
                Expanded(
                  child: Text(
                    connected.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  onPressed: _manager.disconnect,
                  child: const Text('Disconnect'),
                ),
              ],
            )
          else ...[
            _AvailabilityText(state.availability),
            if (state.devices.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final device in state.devices)
                _DeviceRow(
                  device: device,
                  connecting: state.connectingDeviceId == device.id,
                  connectDisabled: state.connectingDeviceId != null,
                  onConnect: _manager.connect,
                ),
            ],
            if (!state.scanning && state.scanCompleted && state.devices.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'No nearby Bluetooth wearables were found.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const ValueKey('ble_scan_button'),
              onPressed: state.scanning
                  ? _manager.stopScan
                  : _manager.startScan,
              icon: state.scanning
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bluetooth_searching, size: 18),
              label: Text(state.scanning ? 'Stop scan' : 'Scan for devices'),
            ),
          ],
        ],
      ),
    );
  }
}

class _AvailabilityText extends StatelessWidget {
  final BleAvailability availability;
  const _AvailabilityText(this.availability);

  @override
  Widget build(BuildContext context) => Text(switch (availability) {
    BleAvailability.ready => 'Bluetooth is ready.',
    BleAvailability.bluetoothOff => 'Turn on Bluetooth to scan.',
    BleAvailability.permissionDenied =>
      'Allow Bluetooth access to scan for devices.',
    BleAvailability.unsupported =>
      'Bluetooth Low Energy is not supported on this device.',
    BleAvailability.unavailable => 'Checking Bluetooth availability…',
  }, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary));
}

class _DeviceRow extends StatelessWidget {
  final BleDiscoveredDevice device;
  final Future<void> Function(BleDiscoveredDevice) onConnect;
  final bool connecting;
  final bool connectDisabled;
  const _DeviceRow({
    required this.device,
    required this.onConnect,
    required this.connecting,
    required this.connectDisabled,
  });

  @override
  Widget build(BuildContext context) => Row(
    key: ValueKey('ble_device_${device.id}'),
    children: [
      const Icon(Icons.watch_outlined, size: 19),
      const SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name, overflow: TextOverflow.ellipsis),
            Text(
              '${device.id} · ${device.rssi} dBm · ${device.serviceIds.contains('0000180d-0000-1000-8000-00805f9b34fb') ? 'Heart Rate supported' : 'Compatibility unknown'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: connectDisabled ? null : () => onConnect(device),
        child: Text(connecting ? 'Connecting…' : 'Connect'),
      ),
    ],
  );
}

class _ConnectionBadge extends StatelessWidget {
  final String label;
  const _ConnectionBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: AppTheme.primaryGreen.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: AppTheme.primaryGreen,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}
