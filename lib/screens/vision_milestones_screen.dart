import 'package:flutter/material.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/theme/app_theme.dart';

class VisionMilestonesScreen extends StatelessWidget {
  final VisionMilestonesState state;

  const VisionMilestonesScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final categories = VisionMilestoneCategory.values
        .where((category) => state.forCategory(category).isNotEmpty)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Milestones')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: 28),
        itemBuilder: (context, index) {
          final category = categories[index];
          final milestones = state.forCategory(category);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _categoryLabel(category),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              ...milestones.map(
                (milestone) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _MilestoneTile(milestone: milestone),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _categoryLabel(VisionMilestoneCategory category) => switch (category) {
    VisionMilestoneCategory.training => 'TRAINING',
    VisionMilestoneCategory.consistency => 'CONSISTENCY',
    VisionMilestoneCategory.bodyProgress => 'BODY PROGRESS',
    VisionMilestoneCategory.strength => 'STRENGTH',
    VisionMilestoneCategory.nutrition => 'NUTRITION',
  };
}

class _MilestoneTile extends StatelessWidget {
  final VisionMilestone milestone;

  const _MilestoneTile({required this.milestone});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                milestone.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _statusLabel(milestone.status),
              style: TextStyle(
                color: _statusColor(milestone.status),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: .7,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          milestone.description,
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        if (milestone.status != VisionMilestoneStatus.completed) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: milestone.normalizedProgress,
            minHeight: 5,
            borderRadius: BorderRadius.circular(99),
            backgroundColor: AppTheme.border,
          ),
          const SizedBox(height: 6),
          Text(
            '${_value(milestone.currentValue)} / ${_value(milestone.targetValue)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    ),
  );

  String _statusLabel(VisionMilestoneStatus status) => switch (status) {
    VisionMilestoneStatus.completed => 'COMPLETED',
    VisionMilestoneStatus.inProgress => 'IN PROGRESS',
    VisionMilestoneStatus.locked => 'LOCKED',
  };

  Color _statusColor(VisionMilestoneStatus status) => switch (status) {
    VisionMilestoneStatus.completed => AppTheme.primaryGreen,
    VisionMilestoneStatus.inProgress => AppTheme.aiBlue,
    VisionMilestoneStatus.locked => AppTheme.textSecondary,
  };

  String _value(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
