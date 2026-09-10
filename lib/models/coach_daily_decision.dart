enum CoachDecision { plannedSession, lighterSession }

class CoachDailyDecision {
  final String userId;
  final DateTime localDate;
  final CoachDecision decision;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CoachDailyDecision({
    required this.userId,
    required this.localDate,
    required this.decision,
    required this.createdAt,
    required this.updatedAt,
  });

  String get localDateKey => dateKey(localDate);

  static String dateKey(DateTime value) {
    final local = value.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  static String decisionKey(CoachDecision value) => switch (value) {
    CoachDecision.plannedSession => 'planned_session',
    CoachDecision.lighterSession => 'lighter_session',
  };

  factory CoachDailyDecision.fromMap(Map<String, dynamic> row) {
    return CoachDailyDecision(
      userId: row['user_id'].toString(),
      localDate: DateTime.parse(row['local_date'].toString()),
      decision: switch (row['decision']?.toString()) {
        'lighter_session' => CoachDecision.lighterSession,
        _ => CoachDecision.plannedSession,
      },
      createdAt: DateTime.parse(row['created_at'].toString()),
      updatedAt: DateTime.parse(row['updated_at'].toString()),
    );
  }
}
