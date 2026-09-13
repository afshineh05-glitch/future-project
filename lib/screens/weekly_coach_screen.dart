import 'package:flutter/material.dart';
import 'package:future_project/models/weekly_coach_plan.dart';
import 'package:future_project/services/weekly_coach_service.dart';
import 'package:future_project/theme/app_theme.dart';

class WeeklyCoachScreen extends StatefulWidget {
  const WeeklyCoachScreen({super.key});

  @override
  State<WeeklyCoachScreen> createState() => _WeeklyCoachScreenState();
}

class _WeeklyCoachScreenState extends State<WeeklyCoachScreen> {
  final WeeklyCoachService _service = WeeklyCoachService();
  WeeklyCoachPlan? _plan;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool regenerate = false}) async {
    if (regenerate) {
      if (_refreshing) return;
      setState(() => _refreshing = true);
    }
    try {
      final plan = regenerate
          ? await _service.generateAndSave()
          : await _service.loadOrGenerateCurrentPlan();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Weekly Coach could not be loaded right now.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Weekly Coach')),
      body: RefreshIndicator(
        onRefresh: () => _load(regenerate: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _content(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading && _plan == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 96),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final plan = _plan;
    if (plan == null) {
      return _WeeklyCard(
        title: 'Weekly Coach',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _error ?? 'There is not enough context to prepare this week yet.',
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _loading
                  ? null
                  : () {
                      _load();
                    },
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'One clear direction, built from your recent progress.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 16),
        _WeeklyCard(
          title: 'Last Week',
          compact: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.shortRetrospective, style: _bodyStyle),
              if (plan.biggestWin.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  plan.biggestWin,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
              if (plan.previousMissionTitle != null) ...[
                const SizedBox(height: 8),
                _FollowUpStatus(direction: plan.followUpDirection),
                const SizedBox(height: 6),
                Text(plan.followUpMessage, style: _bodyStyle),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        _WeeklyCard(
          title: 'This Week',
          accent: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'YOUR ONE PRIORITY',
                style: TextStyle(
                  color: AppTheme.primaryGreen,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                plan.missionTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'WHY THIS MATTERS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 4),
              Text(plan.missionReason, style: _bodyStyle),
              const SizedBox(height: 18),
              const Text(
                "THIS WEEK'S ACTIONS",
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .6,
                ),
              ),
              const SizedBox(height: 10),
              ...plan.actionItems.indexed.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ActionNumber(entry.$1 + 1),
                      const SizedBox(width: 11),
                      Expanded(child: Text(entry.$2, style: _actionStyle)),
                    ],
                  ),
                ),
              ),
              const Divider(height: 24),
              Text(plan.motivationContext, style: _bodyStyle),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          plan.dataCoverage.summary,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _refreshing ? null : () => _load(regenerate: true),
          icon: _refreshing
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          label: Text(
            _refreshing ? 'Refreshing...' : 'Refresh weekly guidance',
          ),
        ),
      ],
    );
  }
}

const _bodyStyle = TextStyle(
  color: AppTheme.textSecondary,
  fontSize: 14,
  height: 1.45,
);
const _actionStyle = TextStyle(
  color: AppTheme.textPrimary,
  fontSize: 14,
  height: 1.4,
  fontWeight: FontWeight.w600,
);

class _WeeklyCard extends StatelessWidget {
  final String title;
  final Widget child;
  final bool accent;
  final bool compact;

  const _WeeklyCard({
    required this.title,
    required this.child,
    this.accent = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.all(compact ? 16 : 20),
    decoration: BoxDecoration(
      color: accent ? AppTheme.calorieCard : AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(
        color: accent
            ? AppTheme.primaryGreen.withValues(alpha: .35)
            : AppTheme.border,
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: accent ? AppTheme.primaryGreen : AppTheme.textPrimary,
            fontSize: compact ? 15 : 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

class _ActionNumber extends StatelessWidget {
  final int value;
  const _ActionNumber(this.value);

  @override
  Widget build(BuildContext context) => Container(
    width: 25,
    height: 25,
    alignment: Alignment.center,
    decoration: const BoxDecoration(
      color: AppTheme.primaryGreen,
      shape: BoxShape.circle,
    ),
    child: Text(
      '$value',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _FollowUpStatus extends StatelessWidget {
  final WeeklyFollowUpDirection direction;
  const _FollowUpStatus({required this.direction});

  @override
  Widget build(BuildContext context) {
    final label = switch (direction) {
      WeeklyFollowUpDirection.establishPriority => 'New priority',
      WeeklyFollowUpDirection.continuePriority => 'Continue',
      WeeklyFollowUpDirection.adjustPriority => 'Adjust',
      WeeklyFollowUpDirection.replacePriority => 'Priority changed',
      WeeklyFollowUpDirection.reinforceProgress => 'Progress confirmed',
      WeeklyFollowUpDirection.insufficientEvidence => 'Not enough evidence',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryGreen,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
