import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:future_project/models/ble_wearable.dart';
import 'package:future_project/services/ble/ble_core_service.dart';
import 'package:future_project/services/ble/ble_device_repository.dart';
import 'package:future_project/services/ble/ble_transport_factory.dart';
import 'package:future_project/services/ble/ble_wearable_adapter.dart';
import 'package:future_project/services/ble/ble_wearable_pipeline.dart';
import 'package:future_project/services/ble/reactive_ble_transport.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BleDeviceManagerState {
  final BleAvailability availability;
  final bool scanning;
  final List<BleDiscoveredDevice> devices;
  final BleDiscoveredDevice? connectedDevice;
  final String? connectingDeviceId;
  final String? errorMessage;
  final bool scanCompleted;
  final double? latestHeartRateBpm;

  const BleDeviceManagerState({
    this.availability = BleAvailability.unavailable,
    this.scanning = false,
    this.devices = const [],
    this.connectedDevice,
    this.connectingDeviceId,
    this.errorMessage,
    this.scanCompleted = false,
    this.latestHeartRateBpm,
  });

  BleDeviceManagerState copyWith({
    BleAvailability? availability,
    bool? scanning,
    List<BleDiscoveredDevice>? devices,
    BleDiscoveredDevice? connectedDevice,
    String? connectingDeviceId,
    bool clearConnecting = false,
    bool clearConnected = false,
    String? errorMessage,
    bool clearError = false,
    bool? scanCompleted,
    double? latestHeartRateBpm,
  }) => BleDeviceManagerState(
    availability: availability ?? this.availability,
    scanning: scanning ?? this.scanning,
    devices: devices ?? this.devices,
    connectedDevice: clearConnected
        ? null
        : connectedDevice ?? this.connectedDevice,
    connectingDeviceId: clearConnecting
        ? null
        : connectingDeviceId ?? this.connectingDeviceId,
    errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    scanCompleted: scanCompleted ?? this.scanCompleted,
    latestHeartRateBpm: latestHeartRateBpm ?? this.latestHeartRateBpm,
  );
}

class BleDeviceManager extends ChangeNotifier {
  final BleCoreService _ble;
  final BleDeviceRepository _repository;
  final List<BleWearableAdapter> _adapters;
  final BleWearablePipeline _pipeline;
  StreamSubscription<BleAvailability>? _availabilitySubscription;
  StreamSubscription<BleDiscoveredDevice>? _scanSubscription;
  StreamSubscription? _measurementSubscription;
  Timer? _scanTimer;
  BleWearableAdapter? _activeAdapter;
  BleDeviceManagerState _state = const BleDeviceManagerState();

  BleDeviceManager({
    required BleCoreService ble,
    required BleDeviceRepository repository,
    required List<BleWearableAdapter> adapters,
    BleWearablePipeline? pipeline,
  }) : _ble = ble,
       _repository = repository,
       _adapters = adapters,
       _pipeline = pipeline ?? BleWearablePipeline();

  factory BleDeviceManager.production() {
    String? userId;
    try {
      userId = Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      userId = null;
    }
    return BleDeviceManager(
      ble: BleCoreService(
        transport: BleTransportFactory.create(),
        permissions: PlatformBlePermissionGateway(),
      ),
      repository: userId == null
          ? VolatileBleDeviceRepository()
          : SecureBleDeviceRepository(userId: userId),
      adapters: [StandardHeartRateBleAdapter()],
    );
  }

  BleDeviceManagerState get state => _state;

  Future<void> initialize() async {
    _availabilitySubscription = _ble.availability.listen(
      (value) => _emit(_state.copyWith(availability: value)),
      onError: (_) => _emit(
        _state.copyWith(
          availability: BleAvailability.unavailable,
          errorMessage: 'Bluetooth is not available right now.',
        ),
      ),
    );
    final known = await _repository.load();
    if (known == null || !known.reconnectEnabled) return;
    try {
      final connected = await _ble.reconnectKnown(known);
      if (!connected) return;
      final device = BleDiscoveredDevice(
        id: known.id,
        name: known.displayName,
        rssi: 0,
      );
      await _finishConnection(device, reconnecting: true);
    } catch (error) {
      _emit(_state.copyWith(errorMessage: _message(error)));
    }
  }

  Future<void> startScan() async {
    await stopScan();
    _emit(
      _state.copyWith(
        scanning: true,
        devices: const [],
        clearError: true,
        scanCompleted: false,
      ),
    );
    _scanTimer?.cancel();
    _scanTimer = Timer(const Duration(seconds: 12), stopScan);
    final found = <String, BleDiscoveredDevice>{};
    _scanSubscription = _ble.scan().listen(
      (device) {
        found[device.id] = device;
        _emit(_state.copyWith(devices: found.values.toList(growable: false)));
      },
      onError: (Object error) {
        _emit(_state.copyWith(scanning: false, errorMessage: _message(error)));
      },
      onDone: () =>
          _emit(_state.copyWith(scanning: false, scanCompleted: true)),
    );
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    await _ble.stopScan();
    if (_state.scanning) {
      _emit(_state.copyWith(scanning: false, scanCompleted: true));
    }
  }

  Future<void> connect(BleDiscoveredDevice device) async {
    if (_state.connectingDeviceId != null) return;
    await stopScan();
    _emit(_state.copyWith(connectingDeviceId: device.id, clearError: true));
    try {
      await _ble.connect(device.id);
      await _finishConnection(device);
    } catch (error) {
      await _ble.disconnect(device.id, manual: false);
      _emit(
        _state.copyWith(clearConnecting: true, errorMessage: _message(error)),
      );
    }
  }

  Future<void> _finishConnection(
    BleDiscoveredDevice device, {
    bool reconnecting = false,
  }) async {
    try {
      final services = await _ble.discoverServices(device.id);
      BleWearableAdapter? adapter;
      for (final candidate in _adapters) {
        if (candidate.supportsDevice(device, services)) {
          adapter = candidate;
          break;
        }
      }
      if (adapter == null) {
        throw UnsupportedError(
          'This device does not expose a supported standard health profile.',
        );
      }
      await adapter.setup(_ble, device, services);
      _activeAdapter = adapter;
      await _measurementSubscription?.cancel();
      _measurementSubscription = adapter.subscribeAndNormalize().listen((
        raw,
      ) async {
        final validated = await _pipeline.processNormalized(raw);
        final heartRate = validated?.averageHeartRateBpm.value;
        if (heartRate != null) {
          _emit(_state.copyWith(latestHeartRateBpm: heartRate));
        }
      }, onError: (_) {});
      await _repository.save(
        KnownBleWearable(
          id: device.id,
          displayName: device.name,
          adapterType: adapter.adapterType,
          lastConnectedAt: DateTime.now(),
          reconnectEnabled: true,
        ),
      );
      _emit(
        _state.copyWith(
          connectedDevice: device,
          clearConnecting: true,
          clearError: true,
        ),
      );
    } catch (error) {
      if (reconnecting) await _ble.disconnect(device.id, manual: false);
      rethrow;
    }
  }

  Future<void> disconnect() async {
    final device = _state.connectedDevice;
    await _measurementSubscription?.cancel();
    _measurementSubscription = null;
    if (_activeAdapter != null) {
      await _activeAdapter!.disconnect();
    } else if (device != null) {
      await _ble.disconnect(device.id);
    }
    _activeAdapter = null;
    final known = await _repository.load();
    if (known != null) {
      await _repository.save(
        KnownBleWearable(
          id: known.id,
          displayName: known.displayName,
          adapterType: known.adapterType,
          lastConnectedAt: known.lastConnectedAt,
          reconnectEnabled: false,
        ),
      );
    }
    _emit(_state.copyWith(clearConnected: true, clearError: true));
  }

  void _emit(BleDeviceManagerState value) {
    _state = value;
    notifyListeners();
  }

  String _message(Object error) => switch (error) {
    BleUnavailableException(:final availability) => switch (availability) {
      BleAvailability.permissionDenied =>
        'Bluetooth permission is needed to scan for wearables.',
      BleAvailability.bluetoothOff =>
        'Turn on Bluetooth to scan for wearables.',
      BleAvailability.unsupported =>
        'Bluetooth Low Energy is not supported on this device.',
      _ => 'Bluetooth is not available right now.',
    },
    TimeoutException() => 'The device connection timed out.',
    UnsupportedError() => error.toString().replaceFirst(
      'Unsupported operation: ',
      '',
    ),
    _ => 'The wearable could not be connected.',
  };

  @override
  void dispose() {
    _availabilitySubscription?.cancel();
    _scanSubscription?.cancel();
    _measurementSubscription?.cancel();
    _scanTimer?.cancel();
    unawaited(_ble.dispose());
    super.dispose();
  }
}
