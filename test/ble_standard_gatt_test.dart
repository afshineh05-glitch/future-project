import 'package:flutter_test/flutter_test.dart';
import 'package:future_project/services/ble/standard_gatt_parsers.dart';
import 'package:future_project/services/ble/ble_wearable_adapter.dart';

void main() {
  group('standard GATT parsing', () {
    test('parses 8-bit Heart Rate Measurement', () {
      final value = StandardGattParsers.heartRate([0, 72]);
      expect(value?.beatsPerMinute, 72);
    });

    test('parses 16-bit heart rate and RR interval', () {
      final value = StandardGattParsers.heartRate([
        0x11,
        0x2c,
        0x01,
        0x00,
        0x04,
      ]);
      expect(value?.beatsPerMinute, 300);
      expect(value?.rrIntervals.single, const Duration(seconds: 1));
    });

    test('rejects malformed Heart Rate packets', () {
      expect(StandardGattParsers.heartRate([]), isNull);
      expect(StandardGattParsers.heartRate([1, 10]), isNull);
      expect(StandardGattParsers.heartRate([0x10, 70, 1]), isNull);
    });

    test('parses and bounds battery level', () {
      expect(StandardGattParsers.batteryLevel([87]), 87);
      expect(StandardGattParsers.batteryLevel([101]), isNull);
      expect(StandardGattParsers.batteryLevel([50, 51]), isNull);
    });

    test('device information rejects malformed UTF-8', () {
      expect(
        StandardGattParsers.deviceInformation('Model 1'.codeUnits),
        'Model 1',
      );
      expect(StandardGattParsers.deviceInformation([0xff]), isNull);
    });
  });

  test(
    'duplicate notifications are suppressed only inside the sample window',
    () {
      final deduplicator = BleNotificationDeduplicator();
      final first = DateTime(2026, 9, 12, 10);
      expect(deduplicator.isDuplicate([0, 72], first), isFalse);
      expect(
        deduplicator.isDuplicate([
          0,
          72,
        ], first.add(const Duration(milliseconds: 100))),
        isTrue,
      );
      expect(
        deduplicator.isDuplicate([
          0,
          72,
        ], first.add(const Duration(seconds: 1))),
        isFalse,
      );
    },
  );
}
