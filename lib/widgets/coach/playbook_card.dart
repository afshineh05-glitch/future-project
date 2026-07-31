import 'package:flutter/material.dart';
import 'package:future_project/theme/app_theme.dart';

class CoachPlaybookCard extends StatelessWidget {
  const CoachPlaybookCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        children: [
          _PlaybookItem(
            icon: Icons.directions_walk_outlined,
            title: '30-minute walk',
            subtitle: 'Light movement to support recovery.',
          ),
          Divider(height: 30),
          _PlaybookItem(
            icon: Icons.water_drop_outlined,
            title: 'Drink 2.8L water',
            subtitle: 'Maintain hydration throughout the day.',
          ),
          Divider(height: 30),
          _PlaybookItem(
            icon: Icons.bedtime_outlined,
            title: 'Sleep before 10:30 PM',
            subtitle: 'Prepare your body for tomorrow.',
          ),
        ],
      ),
    );
  }
}

class _PlaybookItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaybookItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppTheme.visionCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.chevron_right,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}