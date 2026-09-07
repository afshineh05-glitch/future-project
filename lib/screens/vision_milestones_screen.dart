import 'package:flutter/material.dart';
import 'package:future_project/models/vision_milestones.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/vision_milestone_progress.dart';

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
    VisionMilestoneCategory.bodyTransformation => 'BODY TRANSFORMATION',
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
  Widget build(BuildContext context) {
    final accent = _accent(milestone.category, milestone.status);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A4B3A), Color(0xFF06382E)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: .34)),
        boxShadow: milestone.status == VisionMilestoneStatus.locked
            ? null
            : [
                BoxShadow(
                  color: accent.withValues(alpha: .12),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 620;
          final ring = VisionMilestoneProgressRing(
            progress: milestone.normalizedProgress,
            status: milestone.status,
            icon: _categoryIcon(milestone.category),
            accent: accent,
            size: desktop ? 54 : 48,
          );
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                milestone.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                milestone.description,
                maxLines: desktop ? 2 : 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFFBED8CF),
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 9),
              VisionMilestoneProgressBar(
                progress: milestone.normalizedProgress,
                status: milestone.status,
                accent: accent,
              ),
            ],
          );
          final status = Column(
            crossAxisAlignment: desktop
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Text(
                '${_value(milestone.currentValue)} / ${_value(milestone.targetValue)}',
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: _statusColor(milestone.status).withValues(alpha: .14),
                  border: Border.all(
                    color: _statusColor(milestone.status).withValues(alpha: .7),
                  ),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _statusLabel(milestone.status),
                  style: TextStyle(
                    color: _statusColor(milestone.status),
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .55,
                  ),
                ),
              ),
            ],
          );
          if (desktop) {
            return Row(
              children: [
                ring,
                const SizedBox(width: 14),
                Expanded(child: details),
                const SizedBox(width: 22),
                status,
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ring,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 10), status],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _statusLabel(VisionMilestoneStatus status) => switch (status) {
    VisionMilestoneStatus.completed => 'COMPLETED',
    VisionMilestoneStatus.inProgress => 'IN PROGRESS',
    VisionMilestoneStatus.locked => 'LOCKED',
  };

  Color _statusColor(VisionMilestoneStatus status) => switch (status) {
    VisionMilestoneStatus.completed => const Color(0xFF68EDAA),
    VisionMilestoneStatus.inProgress => const Color(0xFF62C8FF),
    VisionMilestoneStatus.locked => const Color(0xFFA7B5B0),
  };

  Color _accent(
    VisionMilestoneCategory category,
    VisionMilestoneStatus status,
  ) {
    if (status == VisionMilestoneStatus.locked) {
      return const Color(0xFF71857E);
    }
    if (status == VisionMilestoneStatus.completed) {
      return const Color(0xFF68EDAA);
    }
    return switch (category) {
      VisionMilestoneCategory.training ||
      VisionMilestoneCategory.strength => const Color(0xFF62C8FF),
      VisionMilestoneCategory.consistency => const Color(0xFF68EDAA),
      VisionMilestoneCategory.bodyProgress ||
      VisionMilestoneCategory.bodyTransformation => const Color(0xFFFFD166),
      VisionMilestoneCategory.nutrition => const Color(0xFF8DDFC5),
    };
  }

  IconData _categoryIcon(
    VisionMilestoneCategory category,
  ) => switch (category) {
    VisionMilestoneCategory.bodyTransformation ||
    VisionMilestoneCategory.bodyProgress => Icons.assignment_turned_in_outlined,
    VisionMilestoneCategory.training ||
    VisionMilestoneCategory.strength => Icons.fitness_center_rounded,
    VisionMilestoneCategory.consistency => Icons.local_fire_department_outlined,
    VisionMilestoneCategory.nutrition => Icons.restaurant_outlined,
  };

  String _value(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);
}
