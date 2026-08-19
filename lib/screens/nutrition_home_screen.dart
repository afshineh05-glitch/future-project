import 'package:flutter/material.dart';

import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/screens/nutrition_profile_screen.dart';
import 'package:future_project/services/nutrition_profile_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/nutrition_asset_image.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({super.key});

  // Demo-only presentation data. Replace this single object with Nutrition
  // Intelligence data when the engine and tracking layer are available.
  static const _NutritionDemoData _demo = _NutritionDemoData(
    goal: 'Build Muscle',
    metrics: [
      _NutritionMetric('Calories', 1460, 2400, 'kcal'),
      _NutritionMetric('Protein', 112, 180, 'g'),
      _NutritionMetric('Carbs', 158, 275, 'g'),
      _NutritionMetric('Fat', 48, 75, 'g'),
      _NutritionMetric('Fiber', 21, 32, 'g'),
      _NutritionMetric('Hydration', 1.8, 3.2, 'L'),
    ],
    workout: 'Chest Day',
    caloriesBurned: 350,
    recoveryProtein: '35–40 g',
    recoveryCarbs: '50–70 g',
    recoveryHydration: '~700 ml',
    mealBuilder: _MealBuilderDemo(
      calories: 500,
      protein: 40,
      carbs: 60,
      proteinSources: [
        'Chicken',
        'Turkey',
        'Eggs',
        'Greek yogurt',
        'Lentils',
        'Tofu',
      ],
      carbohydrateSources: [
        'Rice',
        'Potato',
        'Oats',
        'Beans',
        'Whole-grain bread',
      ],
      fatSources: ['Olive oil', 'Avocado', 'Nuts', 'Seeds'],
    ),
    recipes: [
      _RecipeDemo(
        'Chicken Rice Bowl',
        510,
        42,
        25,
        'assets/nutrition/recipes/chicken_rice_bowl.png',
      ),
      _RecipeDemo(
        'Greek Yogurt Protein Bowl',
        360,
        30,
        10,
        'assets/nutrition/recipes/greek_yogurt_protein_bowl.png',
      ),
      _RecipeDemo(
        'Salmon & Potato Plate',
        560,
        38,
        35,
        'assets/nutrition/recipes/salmon_potato_plate.png',
      ),
    ],
    supplements: [
      _SupplementDemo(
        name: 'Creatine',
        supports: 'Strength, power, and repeated training performance.',
        relevance: 'May complement your muscle-building training goal.',
        foodFirst: 'Small amounts occur naturally in meat and fish.',
        assetPath: 'assets/nutrition/supplements/creatine.png',
        icon: Icons.fitness_center_outlined,
      ),
      _SupplementDemo(
        name: 'Omega-3',
        supports: 'General cardiovascular health and recovery.',
        relevance: 'Worth considering when oily fish intake is limited.',
        foodFirst: 'Start with salmon, sardines, trout, chia, or walnuts.',
        assetPath: 'assets/nutrition/supplements/omega_3.png',
        icon: Icons.water_outlined,
      ),
    ],
    offers: [
      _MemberOfferDemo(
        'Nutrition essentials',
        'Member savings placeholder',
        'assets/nutrition/offers/nutrition_essentials.png',
      ),
      _MemberOfferDemo(
        'Prepared meals',
        'Partner offer placeholder',
        'assets/nutrition/offers/prepared_meals.png',
      ),
    ],
  );

  @override
  State<NutritionHomeScreen> createState() => _NutritionHomeScreenState();
}

class _NutritionHomeScreenState extends State<NutritionHomeScreen> {
  final _profileService = NutritionProfileService();
  NutritionProfile? _profile;
  bool _isLoadingProfile = true;
  String? _profileError;

  _NutritionDemoData get _demo => NutritionHomeScreen._demo;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
        _profileError = null;
      });
    }

    try {
      final profile = await _profileService.load();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoadingProfile = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.toString();
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _editProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final updated = await Navigator.push<NutritionProfile>(
      context,
      MaterialPageRoute(
        builder: (_) => NutritionProfileScreen(
          initialProfile: profile,
          isOnboarding: false,
        ),
      ),
    );
    if (!mounted || updated == null) return;
    setState(() => _profile = updated);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_profileError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(title: const Text('Nutrition')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Could not load Nutrition Profile.',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _profileError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _loadProfile,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_profile == null) {
      return NutritionProfileScreen(
        isOnboarding: true,
        onSaved: (profile) => setState(() => _profile = profile),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        toolbarHeight: 76,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
              ),
            ),
            SizedBox(height: 3),
            Text(
              'Personalized to your goal',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Nutrition Profile',
            onPressed: _editProfile,
            icon: const Icon(Icons.manage_accounts_outlined),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          _StrategyCard(data: _demo),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Meal Builder',
            subtitle: 'Choose food sources and portions for your targets',
          ),
          const SizedBox(height: 12),
          _MealBuilderCard(data: _demo.mealBuilder),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Consumed Today',
            subtitle: 'A quick view of today’s intake',
          ),
          const SizedBox(height: 12),
          _TodayProgressCard(metrics: _demo.metrics),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Recovery Nutrition Requirements',
            subtitle: 'Based on today’s workout and your goal',
          ),
          const SizedBox(height: 12),
          _RecoveryCard(data: _demo),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Cook for Your Goal',
            subtitle: 'Personalized meals in 45 minutes or less',
          ),
          const SizedBox(height: 12),
          _RecipeList(recipes: _demo.recipes),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Smart Supplement',
            subtitle: 'Contextual guidance, with food first',
          ),
          const SizedBox(height: 12),
          _SupplementList(items: _demo.supplements),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Member Offers',
            subtitle: 'Optional savings, separate from nutrition guidance',
          ),
          const SizedBox(height: 12),
          _MemberOffersList(items: _demo.offers),
        ],
      ),
    );
  }
}

class _NutritionDemoData {
  final String goal;
  final List<_NutritionMetric> metrics;
  final String workout;
  final int caloriesBurned;
  final String recoveryProtein;
  final String recoveryCarbs;
  final String recoveryHydration;
  final _MealBuilderDemo mealBuilder;
  final List<_RecipeDemo> recipes;
  final List<_SupplementDemo> supplements;
  final List<_MemberOfferDemo> offers;

  const _NutritionDemoData({
    required this.goal,
    required this.metrics,
    required this.workout,
    required this.caloriesBurned,
    required this.recoveryProtein,
    required this.recoveryCarbs,
    required this.recoveryHydration,
    required this.mealBuilder,
    required this.recipes,
    required this.supplements,
    required this.offers,
  });
}

class _NutritionMetric {
  final String label;
  final num consumed;
  final num target;
  final String unit;

  const _NutritionMetric(this.label, this.consumed, this.target, this.unit);

  num get remaining => target - consumed;
}

class _MealBuilderDemo {
  final int calories;
  final int protein;
  final int carbs;
  final List<String> proteinSources;
  final List<String> carbohydrateSources;
  final List<String> fatSources;

  const _MealBuilderDemo({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.proteinSources,
    required this.carbohydrateSources,
    required this.fatSources,
  });
}

class _RecipeDemo {
  final String name;
  final int calories;
  final int protein;
  final int cookingMinutes;
  final String assetPath;

  const _RecipeDemo(
    this.name,
    this.calories,
    this.protein,
    this.cookingMinutes,
    this.assetPath,
  );
}

class _SupplementDemo {
  final String name;
  final String supports;
  final String relevance;
  final String foodFirst;
  final String assetPath;
  final IconData icon;

  const _SupplementDemo({
    required this.name,
    required this.supports,
    required this.relevance,
    required this.foodFirst,
    required this.assetPath,
    required this.icon,
  });
}

class _MemberOfferDemo {
  final String title;
  final String detail;
  final String assetPath;

  const _MemberOfferDemo(this.title, this.detail, this.assetPath);
}

class _StrategyCard extends StatelessWidget {
  final _NutritionDemoData data;

  const _StrategyCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 10),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Performance Fuel',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Text(
                  data.goal,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 14,
            runSpacing: 7,
            children: [
              for (final metric in data.metrics)
                _StrategyInlineMetric(metric: metric),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: null,
              style: TextButton.styleFrom(
                disabledForegroundColor: Colors.white70,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Full Plan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StrategyInlineMetric extends StatelessWidget {
  final _NutritionMetric metric;

  const _StrategyInlineMetric({required this.metric});

  @override
  Widget build(BuildContext context) {
    final label = metric.label == 'Calories' ? '' : ' ${metric.label}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(_metricIcon(metric.label), size: 13, color: Colors.white60),
        const SizedBox(width: 4),
        Text(
          '${_number(metric.target)}${metric.unit == 'kcal' ? ' ' : ''}${metric.unit}$label',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _TodayProgressCard extends StatelessWidget {
  final List<_NutritionMetric> metrics;

  const _TodayProgressCard({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final calories = _metric('Calories');

    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CALORIES',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_number(calories.consumed)} / ${_number(calories.target)} kcal',
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${_number(calories.remaining)} kcal left',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.visionCard,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: AppTheme.primaryGreen.withValues(alpha: 0.12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Next Focus',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Prioritize protein in your next meal.\n68 g protein left today.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                TextButton(
                  onPressed: () {},
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, 30),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Get Meal Ideas'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _NutritionMetric _metric(String label) =>
      metrics.firstWhere((item) => item.label == label);
}

class _RecoveryCard extends StatelessWidget {
  final _NutritionDemoData data;

  const _RecoveryCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final workoutSummary = _RecoveryWorkoutSummary(data: data);
              final targets = _RecoveryTargets(data: data);

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: workoutSummary),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: targets),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [workoutSummary, const SizedBox(height: 15), targets],
              );
            },
          ),
          const SizedBox(height: 14),
          const Text(
            'WORKOUT SOURCE',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          const Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _WorkoutSourceChip(
                label: 'Followed my Training Plan',
                selected: true,
              ),
              _WorkoutSourceChip(label: 'Different Workout'),
              _WorkoutSourceChip(label: 'Rest Day'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: null,
              child: const Text('View Recovery'),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryWorkoutSummary extends StatelessWidget {
  final _NutritionDemoData data;

  const _RecoveryWorkoutSummary({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _IconBox(
          icon: Icons.fitness_center_outlined,
          color: AppTheme.journeyCard,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TODAY’S WORKOUT',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 0.7,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.workout,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Estimated burn  ~${data.caloriesBurned} kcal',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RecoveryTargets extends StatelessWidget {
  final _NutritionDemoData data;

  const _RecoveryTargets({required this.data});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'RECOVERY TARGETS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.7,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _RecoveryMetric(
                label: 'Protein',
                value: data.recoveryProtein,
              ),
            ),
            Expanded(
              child: _RecoveryMetric(label: 'Carbs', value: data.recoveryCarbs),
            ),
            Expanded(
              child: _RecoveryMetric(
                label: 'Hydration',
                value: data.recoveryHydration,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _WorkoutSourceChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _WorkoutSourceChip({required this.label, this.selected = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? AppTheme.visionCard : AppTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: selected ? AppTheme.primaryGreen : AppTheme.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            selected ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: selected ? AppTheme.primaryGreen : AppTheme.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? AppTheme.primaryGreen : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryMetric extends StatelessWidget {
  final String label;
  final String value;

  const _RecoveryMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _MealBuilderCard extends StatelessWidget {
  final _MealBuilderDemo data;

  const _MealBuilderCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _PrimaryMealCard(data: data)),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: _AlternativeMealCard(data: data)),
            ],
          );
        }

        return Column(
          children: [
            _PrimaryMealCard(data: data),
            const SizedBox(height: 10),
            _AlternativeMealCard(data: data),
          ],
        );
      },
    );
  }
}

class _PrimaryMealCard extends StatelessWidget {
  final _MealBuilderDemo data;

  const _PrimaryMealCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _MealImagePlaceholder(icon: Icons.tune_outlined),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'APPROXIMATE TARGET',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.7,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Build from food sources',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Portions will later adjust to remaining and recovery needs.',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _MealChip('~${data.calories} kcal'),
              _MealChip('~${data.protein} g Protein'),
              _MealChip('~${data.carbs} g Carbs'),
            ],
          ),
          const SizedBox(height: 13),
          _FoodSourceGroup(
            title: 'Protein Sources',
            sources: data.proteinSources,
          ),
          const SizedBox(height: 10),
          _FoodSourceGroup(
            title: 'Carbohydrate Sources',
            sources: data.carbohydrateSources,
          ),
          const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {},
              child: const Text('Build My Meal'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeMealCard extends StatelessWidget {
  final _MealBuilderDemo data;

  const _AlternativeMealCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _MealImagePlaceholder(icon: Icons.eco_outlined, compact: true),
              SizedBox(width: 11),
              Expanded(
                child: Text(
                  'Fat Sources When Needed',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          _FoodSourceGroup(title: 'Food Sources', sources: data.fatSources),
        ],
      ),
    );
  }
}

class _FoodSourceGroup extends StatelessWidget {
  final String title;
  final List<String> sources;

  const _FoodSourceGroup({required this.title, required this.sources});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final source in sources)
              _FoodSourceChip(label: source, assetPath: _foodAssetPath(source)),
          ],
        ),
      ],
    );
  }
}

class _FoodSourceChip extends StatelessWidget {
  final String label;
  final String assetPath;

  const _FoodSourceChip({required this.label, required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 9, 4),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NutritionAssetImage(
            assetPath: assetPath,
            width: 24,
            height: 24,
            borderRadius: BorderRadius.circular(999),
            fallbackIcon: Icons.restaurant_outlined,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MealImagePlaceholder extends StatelessWidget {
  final IconData icon;
  final bool compact;

  const _MealImagePlaceholder({required this.icon, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final size = compact ? 58.0 : 76.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.visionCard, AppTheme.calorieCard],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(compact ? 15 : 18),
      ),
      child: Icon(icon, size: compact ? 30 : 40, color: AppTheme.primaryGreen),
    );
  }
}

class _MealChip extends StatelessWidget {
  final String label;

  const _MealChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _RecipeList extends StatelessWidget {
  final List<_RecipeDemo> recipes;

  const _RecipeList({required this.recipes});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < recipes.length; index++) ...[
                Expanded(
                  child: _RecipeCard(recipe: recipes[index], index: index),
                ),
                if (index != recipes.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < recipes.length; index++) ...[
              _RecipeCard(recipe: recipes[index], index: index),
              if (index != recipes.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final _RecipeDemo recipe;
  final int index;

  const _RecipeCard({required this.recipe, required this.index});

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.breakfast_dining_outlined,
      Icons.lunch_dining_outlined,
      Icons.set_meal_outlined,
    ];

    return _SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NutritionAssetImage(
                assetPath: recipe.assetPath,
                width: 72,
                height: 72,
                borderRadius: BorderRadius.circular(16),
                fallbackIcon: icons[index],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.visionCard,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Profile matched',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _RecipeStat('~${recipe.calories} kcal'),
              _RecipeStat('${recipe.protein} g Protein'),
              _RecipeStat('${recipe.cookingMinutes} min'),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 34),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Recipe',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecipeStat extends StatelessWidget {
  final String label;

  const _RecipeStat(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _SupplementList extends StatelessWidget {
  final List<_SupplementDemo> items;

  const _SupplementList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _SupplementCard(item: items[index]),
          if (index != items.length - 1) const SizedBox(height: 9),
        ],
      ],
    );
  }
}

class _SupplementCard extends StatelessWidget {
  final _SupplementDemo item;

  const _SupplementCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NutritionAssetImage(
            assetPath: item.assetPath,
            width: 48,
            height: 48,
            borderRadius: BorderRadius.circular(12),
            fallbackIcon: item.icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuidanceLine(label: 'WHAT', text: item.name, strong: true),
                const SizedBox(height: 5),
                _GuidanceLine(label: 'WHY', text: item.supports),
                const SizedBox(height: 5),
                _GuidanceLine(label: 'WHY FOR YOU', text: item.relevance),
                const SizedBox(height: 5),
                _GuidanceLine(label: 'FOOD FIRST', text: item.foodFirst),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceLine extends StatelessWidget {
  final String label;
  final String text;
  final bool strong;

  const _GuidanceLine({
    required this.label,
    required this.text,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: '$label  ',
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w900,
          color: AppTheme.primaryGreen,
        ),
        children: [
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: strong ? 13 : 11,
              letterSpacing: 0,
              height: 1.35,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              color: strong ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberOffersList extends StatelessWidget {
  final List<_MemberOfferDemo> items;

  const _MemberOffersList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            Row(
              children: [
                NutritionAssetImage(
                  assetPath: items[index].assetPath,
                  width: 44,
                  height: 44,
                  borderRadius: BorderRadius.circular(12),
                  fallbackIcon: Icons.local_offer_outlined,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[index].title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        items[index].detail,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (index != items.length - 1)
              const Divider(height: 17, color: AppTheme.border),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppTheme.primaryGreen, size: 25),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SurfaceCard({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

String _number(num value) {
  if (value is int || value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toStringAsFixed(1);
}

String _foodAssetPath(String food) {
  final fileName = food
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
  return 'assets/nutrition/foods/$fileName.png';
}

IconData _metricIcon(String label) {
  switch (label) {
    case 'Calories':
      return Icons.local_fire_department_outlined;
    case 'Protein':
      return Icons.fitness_center_outlined;
    case 'Carbs':
      return Icons.grain_outlined;
    case 'Fat':
      return Icons.opacity_outlined;
    case 'Fiber':
      return Icons.eco_outlined;
    case 'Hydration':
      return Icons.water_drop_outlined;
    default:
      return Icons.circle_outlined;
  }
}
