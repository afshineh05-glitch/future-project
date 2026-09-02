import 'package:future_project/models/vision_progress.dart';

class BodyMeasurements {
  final double weightKg;
  final double waistCm;
  final double chestCm;
  final double hipsCm;
  final double armCm;
  final double thighCm;
  final double neckCm;

  const BodyMeasurements({
    required this.weightKg,
    required this.waistCm,
    required this.chestCm,
    required this.hipsCm,
    required this.armCm,
    required this.thighCm,
    required this.neckCm,
  });

  factory BodyMeasurements.fromFoundation(Map<String, dynamic> row) =>
      BodyMeasurements(
        weightKg: _number(row['weight_kg']),
        waistCm: _number(row['waist_cm']),
        chestCm: _number(row['chest_cm']),
        hipsCm: _number(row['hips_cm']),
        armCm: _number(row['arm_cm']),
        thighCm: _number(row['thigh_cm']),
        neckCm: _number(row['neck_cm']),
      );

  factory BodyMeasurements.fromCheck(Map<String, dynamic> row) =>
      BodyMeasurements(
        weightKg: _number(row['weight']),
        waistCm: _number(row['waist']),
        chestCm: _number(row['chest']),
        hipsCm: _number(row['hips']),
        armCm: _number(row['arm']),
        thighCm: _number(row['thigh']),
        neckCm: _number(row['neck']),
      );

  Map<String, dynamic> toDatabaseMap() => {
    'weight': weightKg,
    'waist': waistCm,
    'chest': chestCm,
    'hips': hipsCm,
    'arm': armCm,
    'thigh': thighCm,
    'neck': neckCm,
  };

  Map<String, double> get measurementsCm => {
    'waist': waistCm,
    'chest': chestCm,
    'hips': hipsCm,
    'arm': armCm,
    'thigh': thighCm,
    'neck': neckCm,
  };

  static double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BodyProgressBaseline {
  final BodyMeasurements measurements;
  final DateTime establishedAt;
  final String measurementSystem;

  const BodyProgressBaseline({
    required this.measurements,
    required this.establishedAt,
    this.measurementSystem = 'metric',
  });
}

class BodyProgressCheck {
  final String id;
  final String userId;
  final BodyMeasurements measurements;
  final String? note;
  final DateTime checkedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BodyProgressCheck({
    required this.id,
    required this.userId,
    required this.measurements,
    required this.checkedAt,
    required this.createdAt,
    required this.updatedAt,
    this.note,
  });

  factory BodyProgressCheck.fromMap(Map<String, dynamic> row) =>
      BodyProgressCheck(
        id: row['id'].toString(),
        userId: row['user_id'].toString(),
        measurements: BodyMeasurements.fromCheck(row),
        note: row['note']?.toString(),
        checkedAt: DateTime.parse(row['checked_at'].toString()),
        createdAt: DateTime.parse(row['created_at'].toString()),
        updatedAt: DateTime.parse(
          (row['updated_at'] ?? row['created_at']).toString(),
        ),
      );

  VisionBodyProgressCheck toVisionCheck() => VisionBodyProgressCheck(
    checkedAt: checkedAt,
    weightKg: measurements.weightKg,
    measurementsCm: measurements.measurementsCm,
  );
}

enum BodyProgressCycleStatus { upcoming, due, completed }

class BodyProgressCycle {
  static const cycleLength = Duration(days: 21);
  static const completionWindow = Duration(days: 5);

  final BodyProgressCycleStatus status;
  final DateTime dueAt;
  final DateTime windowEndsAt;
  final DateTime cycleStartedAt;

  const BodyProgressCycle({
    required this.status,
    required this.dueAt,
    required this.windowEndsAt,
    required this.cycleStartedAt,
  });

  factory BodyProgressCycle.calculate({
    required DateTime baselineAt,
    DateTime? latestCheckAt,
    required DateTime now,
  }) {
    final localBaseline = baselineAt.toLocal();
    final localLatest = latestCheckAt?.toLocal();
    final start = _day(localLatest ?? localBaseline);
    final today = _day(now.toLocal());
    final due = start.add(cycleLength);
    final windowEnd = due.add(completionWindow);
    final submittedThisCycle =
        localLatest != null && !_day(localLatest).isBefore(_day(localBaseline));
    final status = submittedThisCycle && today.isBefore(due)
        ? BodyProgressCycleStatus.completed
        : today.isBefore(due)
        ? BodyProgressCycleStatus.upcoming
        : BodyProgressCycleStatus.due;
    return BodyProgressCycle(
      status: status,
      dueAt: due,
      windowEndsAt: windowEnd,
      cycleStartedAt: start,
    );
  }

  static DateTime _day(DateTime value) =>
      DateTime(value.year, value.month, value.day);
}

class BodyProgressCycleState {
  final BodyProgressCycle cycle;
  final BodyProgressCheck? currentCheck;

  const BodyProgressCycleState({
    required this.cycle,
    required this.currentCheck,
  });

  bool get isEditing => currentCheck != null;
}
