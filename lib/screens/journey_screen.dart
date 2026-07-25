import 'package:flutter/material.dart';
import 'package:future_project/theme/app_theme.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Our Journey'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _sectionTitle('Current Mission'),
          const SizedBox(height: 12),

          _infoCard(
            backgroundColor: AppTheme.journeyCard,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.flag_outlined,
                    color: AppTheme.aiBlue,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Build Future Project',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Complete the core app experience',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Timeline'),
          const SizedBox(height: 12),

          _infoCard(
            child: const Column(
              children: [
                _TimelineItem(
                  icon: Icons.check_circle,
                  iconColor: AppTheme.successGreen,
                  title: 'Learn Flutter',
                  subtitle: 'Completed',
                ),
                Divider(),
                _TimelineItem(
                  icon: Icons.autorenew,
                  iconColor: AppTheme.gold,
                  title: 'Build UI',
                  subtitle: 'In progress',
                ),
                Divider(),
                _TimelineItem(
                  icon: Icons.radio_button_unchecked,
                  iconColor: AppTheme.textSecondary,
                  title: 'Firebase',
                  subtitle: 'Upcoming',
                ),
                Divider(),
                _TimelineItem(
                  icon: Icons.radio_button_unchecked,
                  iconColor: AppTheme.textSecondary,
                  title: 'AI Integration',
                  subtitle: 'Upcoming',
                ),
                Divider(),
                _TimelineItem(
                  icon: Icons.radio_button_unchecked,
                  iconColor: AppTheme.textSecondary,
                  title: 'Publish App',
                  subtitle: 'Upcoming',
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Progress'),
          const SizedBox(height: 12),

          _infoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const LinearProgressIndicator(
                    value: 0.4,
                    minHeight: 10,
                    backgroundColor: AppTheme.journeyCard,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.aiBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '40% completed',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    Text(
                      '2 of 5 steps',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          _sectionTitle('Next Milestone'),
          const SizedBox(height: 12),

          _infoCard(
            backgroundColor: AppTheme.visionCard,
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: Colors.white,
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: AppTheme.primaryGreen,
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Complete Dashboard',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Finish the main navigation and core cards',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }

  Widget _infoCard({
    required Widget child,
    Color backgroundColor = AppTheme.card,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _TimelineItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: iconColor,
        size: 28,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}