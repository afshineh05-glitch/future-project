import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/my_foundation_screen.dart';
import 'package:future_project/screens/nutrition_home_screen.dart';
import 'package:future_project/screens/todays_coach_screen.dart';
import 'package:future_project/screens/training_plan_screen.dart';
import 'package:future_project/theme/app_theme.dart';

class IntelligentCoachScreen extends StatefulWidget {
  const IntelligentCoachScreen({super.key});

  @override
  State<IntelligentCoachScreen> createState() => _IntelligentCoachScreenState();
}

class _IntelligentCoachScreenState extends State<IntelligentCoachScreen> {
  bool _isLoadingFoundation = true;
  int _foundationProgress = 0;
  bool _foundationCompleted = false;

  @override
  void initState() {
    super.initState();
    _loadFoundationStatus();
  }

  Future<void> _loadFoundationStatus() async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoadingFoundation = false;
        _foundationProgress = 0;
        _foundationCompleted = false;
      });
      return;
    }

    try {
      final Map<String, dynamic>? row = await supabase
          .from('user_foundations')
          .select('completion_percent, is_completed')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _foundationProgress =
            (row?['completion_percent'] as num?)?.toInt() ?? 0;
        _foundationCompleted = row?['is_completed'] == true;
        _isLoadingFoundation = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _foundationProgress = 0;
        _foundationCompleted = false;
        _isLoadingFoundation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load My Foundation status.')),
      );
    }
  }

  Future<void> _openFoundation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MyFoundationScreen()),
    );

    if (!mounted) return;
    await _loadFoundationStatus();
  }

  void _openTodaysCoach() {
    if (!_foundationCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete My Foundation to unlock Today’s Coach.'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TodaysCoachScreen()),
    );
  }

  void _openTrainingPlan() {
    if (!_foundationCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete My Foundation to unlock Training Plan.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TrainingPlanScreen()),
    );
  }

  void _openNutrition() {
    if (!_foundationCompleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete My Foundation to unlock Nutrition.'),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NutritionHomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Intelligent Coach',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFoundationStatus,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Build the coach that understands you.',
              style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),
            _FoundationCard(
              progress: _foundationProgress,
              completed: _foundationCompleted,
              loading: _isLoadingFoundation,
              onTap: _openFoundation,
            ),
            const SizedBox(height: 24),
            _CoachModuleCard(
              icon: Icons.auto_awesome_outlined,
              title: 'Today’s Coach',
              subtitle: 'Daily guidance based on your progress.',
              locked: !_foundationCompleted,
              onTap: _openTodaysCoach,
            ),
            const SizedBox(height: 14),
            _CoachModuleCard(
              icon: Icons.fitness_center_outlined,
              title: 'Training Plan',
              subtitle: 'Your personalized workout program.',
              locked: !_foundationCompleted,
              onTap: _openTrainingPlan,
            ),
            const SizedBox(height: 14),
            _CoachModuleCard(
              icon: Icons.restaurant_menu_outlined,
              title: 'Nutrition Plan',
              subtitle: 'Meals and nutrition for your goal.',
              locked: !_foundationCompleted,
              onTap: _openNutrition,
            ),
            const SizedBox(height: 14),
            _CoachModuleCard(
              icon: Icons.insights_outlined,
              title: 'Progress',
              subtitle: 'Track measurements and performance.',
              locked: !_foundationCompleted,
            ),
            const SizedBox(height: 14),
            _CoachModuleCard(
              icon: Icons.chat_bubble_outline,
              title: 'Chat with Coach',
              subtitle: 'Ask your AI Coach anything.',
              locked: !_foundationCompleted,
            ),
            const SizedBox(height: 14),
            const _CoachModuleCard(
              icon: Icons.settings_outlined,
              title: 'Coach Settings',
              subtitle: 'Adjust coaching style and preferences.',
              locked: false,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _FoundationCard extends StatelessWidget {
  final int progress;
  final bool completed;
  final bool loading;
  final VoidCallback onTap;

  const _FoundationCard({
    required this.progress,
    required this.completed,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final double progressValue = progress.clamp(0, 100) / 100;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.primaryGreen, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: AppTheme.calorieCard,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.account_tree_outlined,
                      color: AppTheme.primaryGreen,
                      size: 30,
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Foundation',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          loading
                              ? 'Checking your Foundation...'
                              : completed
                              ? 'Your foundation is complete.'
                              : 'Teach Future about yourself.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: Text(
                      loading
                          ? 'Loading...'
                          : completed
                          ? 'Completed'
                          : '$progress% complete',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: completed
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    loading
                        ? ''
                        : completed
                        ? 'Edit'
                        : 'Continue',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: loading
                      ? null
                      : completed
                      ? 1
                      : progressValue,
                  minHeight: 9,
                  backgroundColor: AppTheme.border,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CoachModuleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool locked;
  final VoidCallback? onTap;

  const _CoachModuleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.locked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppTheme.calorieCard,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: locked
                      ? AppTheme.textSecondary
                      : AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 15),
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
                      locked ? 'Complete My Foundation to unlock.' : subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                locked ? Icons.lock_outline : Icons.arrow_forward_ios,
                size: 19,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
