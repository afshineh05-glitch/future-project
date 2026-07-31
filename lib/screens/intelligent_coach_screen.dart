import 'package:flutter/material.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/coach/hero_card.dart';
import 'package:future_project/widgets/coach/playbook_card.dart';
import 'package:future_project/widgets/coach/progress_chart.dart';

class IntelligentCoachScreen extends StatelessWidget {
  const IntelligentCoachScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        title: const Text(
          'Intelligent Coach',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Powered by your progress.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            const CoachHeroCard(),

            const SizedBox(height: 28),

            const Text(
              'Playbook',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            CoachPlaybookCard(),

            const SizedBox(height: 28),

            const CoachProgressChart(),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}