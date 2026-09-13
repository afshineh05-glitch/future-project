import 'dart:convert';
import 'dart:typed_data';

import 'package:future_project/models/ble_wearable.dart';

abstract final class StandardGattUuids {
  static const heartRateService = '0000180d-0000-1000-8000-00805f9b34fb';
  static const heartRateMeasurement = '00002a37-0000-1000-8000-00805f9b34fb';
  static const batteryService = '0000180f-0000-1000-8000-00805f9b34fb';
  static const batteryLevel = '00002a19-0000-1000-8000-00805f9b34fb';
  static const deviceInformationService =
      '0000180a-0000-1000-8000-00805f9b34fb';
  static const manufacturerName = '00002a29-0000-1000-8000-00805f9b34fb';
  static const modelNumber = '00002a24-0000-1000-8000-00805f9b34fb';
}

class StandardGattParsers {
  const StandardGattParsers._();

  static BleHeartRateMeasurement? heartRate(List<int> packet) {
    if (packet.length < 2) return null;
    final bytes = Uint8List.fromList(packet);
    final flags = bytes[0];
    var offset = 1;
    final isUint16 = flags & 0x01 != 0;
    if (bytes.length < offset + (isUint16 ? 2 : 1)) return null;
    final bpm = isUint16
        ? ByteData.sublistView(bytes).getUint16(offset, Endian.little)
        : bytes[offset];
    offset += isUint16 ? 2 : 1;
    if (bpm <= 0) return null;

    int? energy;
    if (flags & 0x08 != 0) {
      if (bytes.length < offset + 2) return null;
      energy = ByteData.sublistView(bytes).getUint16(offset, Endian.little);
      offset += 2;
    }
    final rr = <Duration>[];
    if (flags & 0x10 != 0) {
      if ((bytes.length - offset).isOdd) return null;
      final data = ByteData.sublistView(bytes);
      while (offset < bytes.length) {
        final units = data.getUint16(offset, Endian.little);
        rr.add(Duration(microseconds: (units * 1000000 / 1024).round()));
        offset += 2;
      }
    }
    return BleHeartRateMeasurement(
      beatsPerMinute: bpm,
      energyExpended: energy,
      rrIntervals: rr,
    );
  }

  static int? batteryLevel(List<int> packet) {
    if (packet.length != 1 || packet.first < 0 || packet.first > 100) {
      return null;
    }
    return packet.first;
  }

  static String? deviceInformation(List<int> packet) {
    if (packet.isEmpty) return null;
    try {
      final value = utf8.decode(packet, allowMalformed: false).trim();
      return value.isEmpty ? null : value;
    } on FormatException {
      return null;
    }
  }
}
