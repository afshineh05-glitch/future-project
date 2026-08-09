import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/calorie_scanner_screen.dart';
import 'package:future_project/screens/intelligent_coach_screen.dart';
import 'package:future_project/screens/journey_screen.dart';
import 'package:future_project/screens/vision_screen.dart';
import 'package:future_project/screens/welcome_screen.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();

      if (!context.mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(),
        ),
        (route) => false,
      );
    } on AuthException catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not sign out. Please try again.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Future Project'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            onPressed: () {
              _signOut(context);
            },
            icon: const Icon(
              Icons.logout_outlined,
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Hello, Afshi 👋',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Let’s build your future.',
            style: TextStyle(
              fontSize: 18,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 28),

          const Text(
            'Progress',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.06,
                  ),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: const LinearProgressIndicator(
                    value: 0.4,
                    minHeight: 10,
                    backgroundColor: AppTheme.visionCard,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  '40% completed',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 14),

          DashboardCard(
            icon: Icons.psychology_outlined,
            title: 'Intelligent Coach',
            subtitle: 'Your daily health guidance',
            backgroundColor: AppTheme.visionCard,
            iconColor: AppTheme.primaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const IntelligentCoachScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          DashboardCard(
            icon: Icons.visibility_outlined,
            title: 'My Vision',
            subtitle: 'Visualize your future self',
            backgroundColor: AppTheme.visionCard,
            iconColor: AppTheme.primaryGreen,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const VisionScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          DashboardCard(
            icon: Icons.route_outlined,
            title: 'Our Journey',
            subtitle: 'Follow your daily plan',
            backgroundColor: AppTheme.journeyCard,
            iconColor: AppTheme.aiBlue,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const JourneyScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 18),

          DashboardCard(
            icon: Icons.restaurant_outlined,
            title: 'AI Calorie Magnifier',
            subtitle: 'Scan your meal with AI',
            backgroundColor: AppTheme.calorieCard,
            iconColor: AppTheme.gold,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const CalorieScannerScreen(),
                ),
              );
            },
          ),

          const SizedBox(height: 28),

          const Text(
            'Today’s Quote',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.visionCard,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Text(
              'Trust your belief, let your actions bring it to life.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}