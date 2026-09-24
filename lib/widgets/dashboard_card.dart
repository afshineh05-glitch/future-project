import 'package:flutter/material.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/theme/muscle_up_motion.dart';

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;
  final bool isHighlighted;

  const DashboardCard({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return MuscleUpPressable(
      enabled: onTap != null,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: AppTheme.metallicGold.withValues(alpha: 0.82),
                width: 1.15,
              ),
              boxShadow: [
                BoxShadow(
                  color: isHighlighted
                      ? AppTheme.brightGold.withValues(alpha: 0.17)
                      : Colors.black.withValues(alpha: 0.28),
                  blurRadius: isHighlighted ? 18 : 12,
                  spreadRadius: isHighlighted ? 1 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.charcoal.withValues(alpha: 0.72),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.metallicGold,
                      width: 1.25,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 30),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textOnDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          subtitle!,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.dashboardMutedText,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 18,
                  color: AppTheme.metallicGold,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
