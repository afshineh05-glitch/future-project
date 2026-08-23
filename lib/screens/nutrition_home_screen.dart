import 'package:flutter/material.dart';

import 'package:future_project/models/food_visual.dart';
import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/models/meal_builder_result.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/nutrition_food_log.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/models/recovery_nutrition.dart';
import 'package:future_project/models/smart_supplement.dart';
import 'package:future_project/screens/calorie_scanner_screen.dart';
import 'package:future_project/screens/cook_for_goal_recipe_screen.dart';
import 'package:future_project/screens/nutrition_profile_screen.dart';
import 'package:future_project/services/food_visual_service.dart';
import 'package:future_project/services/cook_for_goal_recipe_service.dart';
import 'package:future_project/services/meal_builder_substitution_service.dart';
import 'package:future_project/services/nutrition_engine_service.dart';
import 'package:future_project/services/nutrition_food_log_service.dart';
import 'package:future_project/services/nutrition_profile_service.dart';
import 'package:future_project/services/recovery_nutrition_service.dart';
import 'package:future_project/services/smart_supplement_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/nutrition_asset_image.dart';
import 'package:future_project/widgets/smart_supplement_section.dart';

class NutritionHomeScreen extends StatefulWidget {
  const NutritionHomeScreen({super.key});

  // Demo-only presentation data for Nutrition sections not connected yet.
  static const _NutritionDemoData _demo = _NutritionDemoData(
    mealBuilder: _MealBuilderDemo(
      calories: 500,
      protein: 40,
      carbs: 60,
      proteinSources: [
        'Chicken Breast',
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
  final _nutritionEngineService = NutritionEngineService();
  final _foodLogService = NutritionFoodLogService();
  final _mealSubstitutionService = const MealBuilderSubstitutionService();
  final _recoveryNutritionService = RecoveryNutritionService();
  final _cookForGoalService = const CookForGoalRecipeService(
    provider: LocalCookForGoalRecipeProvider(),
  );
  final _smartSupplementService = const SmartSupplementService();
  NutritionProfile? _profile;
  PerformanceFuel? _performanceFuel;
  NutritionFoodDay? _todayFood;
  MealBuilderResult? _mealBuilderResult;
  RecoveryNutritionContext? _recoveryContext;
  List<RankedCookForGoalRecipe> _cookForGoalRecipes = const [];
  List<SmartSupplementRecommendation> _smartSupplements = const [];
  final Set<int> _refreshingRecipeIndexes = {};
  RecoveryWorkoutSource _recoverySource = RecoveryWorkoutSource.trainingPlan;
  String _differentWorkoutType = 'Strength Training';
  int _differentWorkoutDuration = 45;
  RecoveryWorkoutIntensity _differentWorkoutIntensity =
      RecoveryWorkoutIntensity.moderate;
  bool _recoverySelectionInitialized = false;
  bool _recoverySelectionUserModified = false;
  bool _isLoadingProfile = true;
  bool _isLoadingPerformanceFuel = true;
  bool _isLoadingTodayFood = true;
  bool _isBuildingMeal = false;
  bool _isLoadingRecovery = true;
  bool _isLoadingRecipes = true;
  bool _isLoadingSupplements = true;
  final Map<int, int> _mealAlternativeIndexes = {};
  String? _profileError;
  String? _performanceFuelError;
  String? _todayFoodError;
  String? _mealBuilderError;
  String? _recoveryError;
  String? _recipeError;
  String? _supplementError;
  int _recipeRequestId = 0;

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
      if (profile != null) {
        _loadPerformanceFuel();
        _loadTodayFood();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _profileError = error.toString();
        _isLoadingProfile = false;
      });
    }
  }

  Future<void> _loadPerformanceFuel() async {
    if (mounted) {
      setState(() {
        _isLoadingPerformanceFuel = true;
        _performanceFuelError = null;
      });
    }
    try {
      final performanceFuel = await _nutritionEngineService
          .loadPerformanceFuel();
      if (!mounted) return;
      setState(() {
        _performanceFuel = performanceFuel;
        _isLoadingPerformanceFuel = false;
      });
      _loadRecoveryNutrition();
      _refreshCookForGoal();
      _refreshSmartSupplements();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _performanceFuelError = error.toString();
        _isLoadingPerformanceFuel = false;
      });
      _loadRecoveryNutrition();
      _refreshCookForGoal();
      _refreshSmartSupplements();
    }
  }

  Future<void> _loadRecoveryNutrition() async {
    if (mounted) {
      setState(() {
        _isLoadingRecovery = true;
        _recoveryError = null;
      });
    }
    try {
      final recoveryContext = await _recoveryNutritionService.loadContext(
        fuel: _performanceFuel,
      );
      if (!mounted) return;
      setState(() {
        _recoveryContext = recoveryContext;
        if (!_recoverySelectionInitialized && !_recoverySelectionUserModified) {
          _recoverySource = recoveryContext.savedSource;
          final savedWorkout = recoveryContext.savedDifferentWorkout;
          if (savedWorkout != null) {
            _differentWorkoutType = savedWorkout.type;
            _differentWorkoutDuration = savedWorkout.durationMinutes;
            _differentWorkoutIntensity = savedWorkout.intensity;
          }
          _recoverySelectionInitialized = true;
        }
        _isLoadingRecovery = false;
      });
      _refreshCookForGoal();
      _refreshSmartSupplements();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _recoveryError = error.toString();
        _isLoadingRecovery = false;
      });
      _refreshSmartSupplements();
    }
  }

  RecoveryWorkout get _differentRecoveryWorkout => RecoveryWorkout(
    name: _differentWorkoutType,
    type: _differentWorkoutType,
    durationMinutes: _differentWorkoutDuration,
    intensity: _differentWorkoutIntensity,
    exerciseCount: null,
    isScheduledWorkout: true,
  );

  Future<void> _setRecoverySource(RecoveryWorkoutSource source) async {
    setState(() {
      _recoverySource = source;
      _recoverySelectionInitialized = true;
      _recoverySelectionUserModified = true;
    });
    _refreshCookForGoal();
    _refreshSmartSupplements();
    await _persistRecoverySelection();
  }

  Future<void> _setDifferentWorkoutType(String value) async {
    setState(() {
      _differentWorkoutType = value;
      _recoverySelectionInitialized = true;
      _recoverySelectionUserModified = true;
    });
    _refreshCookForGoal();
    _refreshSmartSupplements();
    await _persistRecoverySelection();
  }

  Future<void> _setDifferentWorkoutDuration(int value) async {
    setState(() {
      _differentWorkoutDuration = value;
      _recoverySelectionInitialized = true;
      _recoverySelectionUserModified = true;
    });
    _refreshCookForGoal();
    _refreshSmartSupplements();
    await _persistRecoverySelection();
  }

  Future<void> _setDifferentWorkoutIntensity(
    RecoveryWorkoutIntensity value,
  ) async {
    setState(() {
      _differentWorkoutIntensity = value;
      _recoverySelectionInitialized = true;
      _recoverySelectionUserModified = true;
    });
    _refreshCookForGoal();
    _refreshSmartSupplements();
    await _persistRecoverySelection();
  }

  Future<void> _persistRecoverySelection() {
    return _recoveryNutritionService.saveDailySelection(
      source: _recoverySource,
      differentWorkout:
          _recoverySource == RecoveryWorkoutSource.differentWorkout
          ? _differentRecoveryWorkout
          : null,
    );
  }

  Future<void> _loadTodayFood() async {
    if (mounted) {
      setState(() {
        _isLoadingTodayFood = true;
        _todayFoodError = null;
      });
    }
    try {
      final todayFood = await _foodLogService.loadToday();
      if (!mounted) return;
      setState(() {
        _todayFood = todayFood;
        _isLoadingTodayFood = false;
      });
      _refreshCookForGoal();
      _refreshSmartSupplements();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _todayFoodError = error.toString();
        _isLoadingTodayFood = false;
      });
      _refreshCookForGoal();
      _refreshSmartSupplements();
    }
  }

  bool get _hasDemandingRecoveryContext {
    if (_recoverySource == RecoveryWorkoutSource.restDay) return false;
    final workout = _recoverySource == RecoveryWorkoutSource.differentWorkout
        ? _differentRecoveryWorkout
        : _recoveryContext?.trainingPlanWorkout;
    return workout?.intensity == RecoveryWorkoutIntensity.hard ||
        workout?.intensity == RecoveryWorkoutIntensity.veryHard;
  }

  Future<void> _refreshCookForGoal() async {
    if (_isLoadingPerformanceFuel || _isLoadingTodayFood || _profile == null) {
      return;
    }
    final fuel = _performanceFuel;
    final todayFood = _todayFood;
    if (fuel == null || todayFood == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingRecipes = false;
        _recipeError = fuel == null
            ? 'Performance Fuel is needed for personalized recipes.'
            : 'Consumed Today is needed for personalized recipes.';
      });
      return;
    }

    final requestId = ++_recipeRequestId;
    setState(() {
      _isLoadingRecipes = true;
      _recipeError = null;
    });
    try {
      final recipes = await _cookForGoalService.recommend(
        fuel: fuel,
        consumedToday: todayFood,
        profile: _profile!,
        demandingRecovery: _hasDemandingRecoveryContext,
      );
      if (!mounted || requestId != _recipeRequestId) return;
      setState(() {
        _cookForGoalRecipes = recipes;
        _refreshingRecipeIndexes.clear();
        _isLoadingRecipes = false;
      });
    } catch (error) {
      if (!mounted || requestId != _recipeRequestId) return;
      setState(() {
        _recipeError = 'Could not load suitable recipes: $error';
        _isLoadingRecipes = false;
      });
    }
  }

  void _refreshSmartSupplements() {
    if (_isLoadingPerformanceFuel ||
        _isLoadingTodayFood ||
        _isLoadingRecovery ||
        _profile == null) {
      return;
    }
    final fuel = _performanceFuel;
    final todayFood = _todayFood;
    final recoveryContext = _recoveryContext;
    if (fuel == null || todayFood == null || recoveryContext == null) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupplements = false;
        _supplementError =
            'Personalized supplement guidance is temporarily unavailable.';
      });
      return;
    }

    try {
      final selectedWorkout = switch (_recoverySource) {
        RecoveryWorkoutSource.trainingPlan =>
          recoveryContext.trainingPlanWorkout,
        RecoveryWorkoutSource.differentWorkout => _differentRecoveryWorkout,
        RecoveryWorkoutSource.restDay => null,
      };
      final recommendations = _smartSupplementService.recommend(
        profile: _profile!,
        fuel: fuel,
        consumedToday: todayFood,
        recoveryContext: recoveryContext,
        recoverySource: _recoverySource,
        selectedWorkout: selectedWorkout,
      );
      if (!mounted) return;
      setState(() {
        _smartSupplements = recommendations;
        _isLoadingSupplements = false;
        _supplementError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingSupplements = false;
        _supplementError = 'Could not update supplement guidance: $error';
      });
    }
  }

  Future<void> _tryAnotherRecipe(int index) async {
    if (_refreshingRecipeIndexes.contains(index) ||
        index < 0 ||
        index >= _cookForGoalRecipes.length) {
      return;
    }
    final fuel = _performanceFuel;
    final todayFood = _todayFood;
    final profile = _profile;
    if (fuel == null || todayFood == null || profile == null) return;

    final contextRequestId = _recipeRequestId;
    final currentRecipeId = _cookForGoalRecipes[index].recipe.id;
    setState(() => _refreshingRecipeIndexes.add(index));
    try {
      final candidates = await _cookForGoalService.recommend(
        fuel: fuel,
        consumedToday: todayFood,
        profile: profile,
        demandingRecovery: _hasDemandingRecoveryContext,
        limit: 100,
      );
      if (!mounted || contextRequestId != _recipeRequestId) return;
      final displayedIds = _cookForGoalRecipes
          .map((item) => item.recipe.id)
          .toSet();
      RankedCookForGoalRecipe? replacement;
      for (final candidate in candidates) {
        if (candidate.recipe.id != currentRecipeId &&
            !displayedIds.contains(candidate.recipe.id)) {
          replacement = candidate;
          break;
        }
      }
      if (replacement == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No other suitable recipe is available right now.'),
          ),
        );
        return;
      }
      if (index >= _cookForGoalRecipes.length ||
          _cookForGoalRecipes[index].recipe.id != currentRecipeId) {
        return;
      }
      setState(() {
        final updated = List<RankedCookForGoalRecipe>.from(_cookForGoalRecipes);
        updated[index] = replacement!;
        _cookForGoalRecipes = List.unmodifiable(updated);
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not try another recipe: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _refreshingRecipeIndexes.remove(index));
      }
    }
  }

  Future<void> _scanOrLogFood() async {
    final logged = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const CalorieScannerScreen(returnAfterConfirmation: true),
      ),
    );
    if (!mounted || logged != true) return;
    setState(() {
      _mealBuilderResult = null;
      _mealAlternativeIndexes.clear();
    });
    await _loadTodayFood();
  }

  Future<void> _buildMeal() async {
    if (_isBuildingMeal) return;
    setState(() {
      _isBuildingMeal = true;
      _mealBuilderError = null;
    });
    try {
      final result = await _nutritionEngineService.buildMeal();
      if (!mounted) return;
      setState(() {
        _mealBuilderResult = result;
        _mealAlternativeIndexes.clear();
        _isBuildingMeal = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _mealBuilderError = error.toString();
        _isBuildingMeal = false;
      });
    }
  }

  void _swapMealFood(int index) {
    final current = _mealBuilderResult;
    final profile = _profile;
    if (current == null || profile == null) return;
    final substitution = _mealSubstitutionService.nextAlternative(
      currentResult: current,
      foodIndex: index,
      profile: profile,
      currentAlternativeIndex: _mealAlternativeIndexes[index],
    );
    if (substitution == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other suitable option available.')),
      );
      return;
    }
    setState(() {
      _mealBuilderResult = substitution.result;
      _mealAlternativeIndexes[index] = substitution.alternativeIndex;
    });
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
    setState(() {
      _profile = updated;
      _mealBuilderResult = null;
      _mealAlternativeIndexes.clear();
    });
    await _loadPerformanceFuel();
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
        onSaved: (profile) {
          setState(() => _profile = profile);
          _loadPerformanceFuel();
          _loadTodayFood();
        },
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
          _StrategyCard(
            fuel: _performanceFuel,
            isLoading: _isLoadingPerformanceFuel,
            error: _performanceFuelError,
            onRetry: _loadPerformanceFuel,
          ),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Meal Builder',
            subtitle: 'Choose food sources and portions for your targets',
          ),
          const SizedBox(height: 12),
          _MealBuilderCard(
            data: _demo.mealBuilder,
            result: _mealBuilderResult,
            isLoading: _isBuildingMeal,
            error: _mealBuilderError,
            onBuild: _buildMeal,
            onSwapFood: _swapMealFood,
            onOpenCalorieMagnifier: _scanOrLogFood,
          ),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Consumed Today',
            subtitle: 'A quick view of today’s intake',
          ),
          const SizedBox(height: 12),
          _TodayProgressCard(
            day: _todayFood,
            fuel: _performanceFuel,
            isLoading: _isLoadingTodayFood || _isLoadingPerformanceFuel,
            error: _todayFoodError,
            onRetry: _loadTodayFood,
          ),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Recovery Nutrition Requirements',
            subtitle: 'Based on today’s workout and your goal',
          ),
          const SizedBox(height: 12),
          _RecoveryCard(
            recoveryContext: _recoveryContext,
            source: _recoverySource,
            differentWorkout: _differentRecoveryWorkout,
            isLoading: _isLoadingRecovery,
            error: _recoveryError,
            onRetry: _loadRecoveryNutrition,
            onSourceChanged: _setRecoverySource,
            onWorkoutTypeChanged: _setDifferentWorkoutType,
            onDurationChanged: _setDifferentWorkoutDuration,
            onIntensityChanged: _setDifferentWorkoutIntensity,
          ),
          const SizedBox(height: 26),
          const _SectionTitle(
            title: 'Cook for Your Goal',
            subtitle: 'Personalized meals in 45 minutes or less',
          ),
          const SizedBox(height: 12),
          _RecipeList(
            recipes: _cookForGoalRecipes,
            refreshingIndexes: _refreshingRecipeIndexes,
            isLoading: _isLoadingRecipes,
            error: _recipeError,
            onRetry: _refreshCookForGoal,
            onTryAnother: _tryAnotherRecipe,
          ),
          const SizedBox(height: 28),
          SmartSupplementSection(
            items: _smartSupplements,
            isLoading: _isLoadingSupplements,
            error: _supplementError,
            onRetry: _refreshSmartSupplements,
          ),
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
  final _MealBuilderDemo mealBuilder;
  final List<_MemberOfferDemo> offers;

  const _NutritionDemoData({required this.mealBuilder, required this.offers});
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

class _MemberOfferDemo {
  final String title;
  final String detail;
  final String assetPath;

  const _MemberOfferDemo(this.title, this.detail, this.assetPath);
}

class _StrategyCard extends StatelessWidget {
  final PerformanceFuel? fuel;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _StrategyCard({
    required this.fuel,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

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
              if (fuel != null)
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
                    fuel!.goalLabel,
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
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Calculating your personalized targets…',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Performance Fuel is unavailable right now.',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: onRetry,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            )
          else if (fuel != null) ...[
            Wrap(
              spacing: 14,
              runSpacing: 7,
              children: [
                for (final metric in _metricsFor(fuel!))
                  _StrategyInlineMetric(metric: metric),
              ],
            ),
            const SizedBox(height: 11),
            const Text(
              'Why this plan?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              fuel!.why,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                height: 1.35,
              ),
            ),
            if (fuel!.micronutrientFocus.isNotEmpty) ...[
              const SizedBox(height: 7),
              Text(
                'General focus: ${fuel!.micronutrientFocus.join(', ')}',
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
            const SizedBox(height: 5),
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
        ],
      ),
    );
  }

  List<_NutritionMetric> _metricsFor(PerformanceFuel value) {
    return [
      _NutritionMetric('Calories', 0, value.calories.target, 'kcal'),
      _NutritionMetric('Protein', 0, value.proteinG, 'g'),
      _NutritionMetric('Carbs', 0, value.carbsG, 'g'),
      _NutritionMetric('Fat', 0, value.fatG, 'g'),
      _NutritionMetric('Fiber', 0, value.fiberG, 'g'),
      _NutritionMetric('Hydration', 0, value.hydrationL, 'L'),
    ];
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
  final NutritionFoodDay? day;
  final PerformanceFuel? fuel;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const _TodayProgressCard({
    required this.day,
    required this.fuel,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today\'s food log is unavailable right now.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 5),
                Text(
                  error!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('Try Again')),
              ],
            )
          else if (day != null && fuel != null) ...[
            _TodayNutritionContent(day: day!, fuel: fuel!),
          ] else
            const Text(
              'Nutrition targets are unavailable right now.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
        ],
      ),
    );
  }
}

class _TodayNutritionContent extends StatelessWidget {
  final NutritionFoodDay day;
  final PerformanceFuel fuel;

  const _TodayNutritionContent({required this.day, required this.fuel});

  @override
  Widget build(BuildContext context) {
    final totals = day.totals;
    final remaining = day.remainingFor(fuel);
    final focus = _nextFocus(totals, remaining);
    return Column(
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
                    '${_number(totals.calories)} / ${fuel.calories.target} kcal',
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
              '${_number(remaining.calories)} kcal left',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 18,
          runSpacing: 7,
          children: [
            _TodayMacroText(
              label: 'Protein',
              consumed: totals.proteinG,
              target: fuel.proteinG,
            ),
            _TodayMacroText(
              label: 'Carbs',
              consumed: totals.carbsG,
              target: fuel.carbsG,
            ),
            _TodayMacroText(
              label: 'Fat',
              consumed: totals.fatG,
              target: fuel.fatG,
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
              Text(
                '${focus.$1}\n${focus.$2}',
                style: const TextStyle(
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
    );
  }

  (String, String) _nextFocus(
    NutritionFoodTotals totals,
    NutritionFoodRemaining remaining,
  ) {
    final gaps = <(String, double)>[
      ('protein', remaining.proteinG / fuel.proteinG),
      ('carbs', remaining.carbsG / fuel.carbsG),
      ('fat', remaining.fatG / fuel.fatG),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    switch (gaps.first.$1) {
      case 'carbs':
        return (
          'Prioritize quality carbohydrates in your next meal.',
          '${_number(remaining.carbsG)} g carbs left today.',
        );
      case 'fat':
        return (
          'Include healthy fats in your next meal.',
          '${_number(remaining.fatG)} g fat left today.',
        );
      default:
        return (
          'Prioritize protein in your next meal.',
          '${_number(remaining.proteinG)} g protein left today.',
        );
    }
  }
}

class _TodayMacroText extends StatelessWidget {
  final String label;
  final double consumed;
  final int target;

  const _TodayMacroText({
    required this.label,
    required this.consumed,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label  ${_number(consumed)} / $target g',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.textSecondary,
      ),
    );
  }
}

class _RecoveryCard extends StatelessWidget {
  final RecoveryNutritionContext? recoveryContext;
  final RecoveryWorkoutSource source;
  final RecoveryWorkout differentWorkout;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<RecoveryWorkoutSource> onSourceChanged;
  final ValueChanged<String> onWorkoutTypeChanged;
  final ValueChanged<int> onDurationChanged;
  final ValueChanged<RecoveryWorkoutIntensity> onIntensityChanged;

  const _RecoveryCard({
    required this.recoveryContext,
    required this.source,
    required this.differentWorkout,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onSourceChanged,
    required this.onWorkoutTypeChanged,
    required this.onDurationChanged,
    required this.onIntensityChanged,
  });

  static const _engine = RecoveryNutritionEngine();
  static const _workoutTypes = [
    'Strength Training',
    'Cardio',
    'HIIT',
    'Sports',
    'Mobility',
  ];
  static const _durations = [30, 45, 60, 75, 90];

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null || recoveryContext == null) {
      return _SurfaceCard(
        child: Column(
          children: [
            Text(
              error ?? 'Recovery nutrition is unavailable.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    final recommendation = _engine.calculate(
      context: recoveryContext!,
      source: source,
      differentWorkout: differentWorkout,
    );
    return _SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 620;
              final workoutSummary = _RecoveryWorkoutSummary(
                recommendation: recommendation,
              );
              final targets = _RecoveryTargets(recommendation: recommendation);

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
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _WorkoutSourceChip(
                label: 'Followed my Training Plan',
                selected: source == RecoveryWorkoutSource.trainingPlan,
                onTap: () =>
                    onSourceChanged(RecoveryWorkoutSource.trainingPlan),
              ),
              _WorkoutSourceChip(
                label: 'Different Workout',
                selected: source == RecoveryWorkoutSource.differentWorkout,
                onTap: () =>
                    onSourceChanged(RecoveryWorkoutSource.differentWorkout),
              ),
              _WorkoutSourceChip(
                label: 'Rest Day',
                selected: source == RecoveryWorkoutSource.restDay,
                onTap: () => onSourceChanged(RecoveryWorkoutSource.restDay),
              ),
            ],
          ),
          if (source == RecoveryWorkoutSource.differentWorkout) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('workout-${differentWorkout.type}'),
                    initialValue: differentWorkout.type,
                    decoration: const InputDecoration(labelText: 'Workout'),
                    items: _workoutTypes
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onWorkoutTypeChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    key: ValueKey(
                      'duration-${differentWorkout.durationMinutes}',
                    ),
                    initialValue: differentWorkout.durationMinutes,
                    decoration: const InputDecoration(labelText: 'Duration'),
                    items: _durations
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text('$value min'),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) onDurationChanged(value);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<RecoveryWorkoutIntensity>(
              key: ValueKey('intensity-${differentWorkout.intensity.name}'),
              initialValue: differentWorkout.intensity,
              decoration: const InputDecoration(labelText: 'Intensity'),
              items: RecoveryWorkoutIntensity.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(_intensityLabel(value)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onIntensityChanged(value);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _RecoveryWorkoutSummary extends StatelessWidget {
  final RecoveryNutritionRecommendation recommendation;

  const _RecoveryWorkoutSummary({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final workout = recommendation.workout;
    final title = recommendation.isRestDay
        ? 'Rest Day'
        : workout?.name ?? 'Workout details unavailable';
    return Row(
      children: [
        _IconBox(
          icon: recommendation.isRestDay
              ? Icons.self_improvement_outlined
              : Icons.fitness_center_outlined,
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
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (workout != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${workout.durationMinutes} min · '
                  '${_intensityLabel(workout.intensity)}'
                  '${workout.exerciseCount == null ? '' : ' · ${workout.exerciseCount} exercises'}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
              if (recommendation.estimatedCaloriesBurned != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Estimated burn ~${recommendation.estimatedCaloriesBurned} kcal',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
              if (workout != null && !workout.isScheduledWorkout) ...[
                const SizedBox(height: 3),
                const Text(
                  'Exact plan session is not scheduled for today.',
                  style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _RecoveryTargets extends StatelessWidget {
  final RecoveryNutritionRecommendation recommendation;

  const _RecoveryTargets({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    if (recommendation.isRestDay) {
      final hydration = recommendation.dailyHydrationL;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'REST-DAY RECOVERY',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.7,
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            hydration == null
                ? 'Follow your daily Performance Fuel plan and hydrate normally.'
                : 'Follow your daily Performance Fuel plan, including ${_number(hydration)} L hydration.',
            style: const TextStyle(height: 1.4, color: AppTheme.textSecondary),
          ),
        ],
      );
    }
    if (recommendation.workout == null) {
      return const Text(
        'Add workout details to calculate recovery targets.',
        style: TextStyle(color: AppTheme.textSecondary),
      );
    }
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
                value: '${recommendation.proteinG} g',
              ),
            ),
            Expanded(
              child: _RecoveryMetric(
                label: 'Carbs',
                value: '${recommendation.carbsG} g',
              ),
            ),
            Expanded(
              child: _RecoveryMetric(
                label: 'Hydration',
                value: '${recommendation.hydrationMl} ml',
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Workout-specific guidance; estimated burn is not an eat-back target.',
          style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}

class _WorkoutSourceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WorkoutSourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
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
                color: selected
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _intensityLabel(RecoveryWorkoutIntensity intensity) {
  return switch (intensity) {
    RecoveryWorkoutIntensity.veryLight => 'Very Light',
    RecoveryWorkoutIntensity.light => 'Light',
    RecoveryWorkoutIntensity.moderate => 'Moderate',
    RecoveryWorkoutIntensity.hard => 'Hard',
    RecoveryWorkoutIntensity.veryHard => 'Very Hard',
  };
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
  final MealBuilderResult? result;
  final bool isLoading;
  final String? error;
  final VoidCallback onBuild;
  final ValueChanged<int> onSwapFood;
  final VoidCallback onOpenCalorieMagnifier;

  const _MealBuilderCard({
    required this.data,
    required this.result,
    required this.isLoading,
    required this.error,
    required this.onBuild,
    required this.onSwapFood,
    required this.onOpenCalorieMagnifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;

        if (isWide) {
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: _PrimaryMealCard(
                    data: data,
                    result: result,
                    isLoading: isLoading,
                    error: error,
                    onBuild: onBuild,
                    onSwapFood: onSwapFood,
                    alignActionToBottom: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AlternativeMealCard(data: data),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _CalorieMagnifierCard(
                          onTap: onOpenCalorieMagnifier,
                          alignActionToBottom: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _PrimaryMealCard(
              data: data,
              result: result,
              isLoading: isLoading,
              error: error,
              onBuild: onBuild,
              onSwapFood: onSwapFood,
            ),
            const SizedBox(height: 10),
            _AlternativeMealCard(data: data),
            const SizedBox(height: 10),
            _CalorieMagnifierCard(onTap: onOpenCalorieMagnifier),
          ],
        );
      },
    );
  }
}

class _PrimaryMealCard extends StatelessWidget {
  final _MealBuilderDemo data;
  final MealBuilderResult? result;
  final bool isLoading;
  final String? error;
  final VoidCallback onBuild;
  final ValueChanged<int> onSwapFood;
  final bool alignActionToBottom;

  const _PrimaryMealCard({
    required this.data,
    required this.result,
    required this.isLoading,
    required this.error,
    required this.onBuild,
    required this.onSwapFood,
    this.alignActionToBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    final macros = result?.totals;
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
              _MealChip('~${macros?.calories ?? data.calories} kcal'),
              _MealChip('${macros?.proteinG ?? data.protein} g Protein'),
              _MealChip('${macros?.carbsG ?? data.carbs} g Carbs'),
              if (macros != null) _MealChip('${macros.fatG} g Fat'),
            ],
          ),
          const SizedBox(height: 13),
          if (result == null) ...[
            _FoodSourceGroup(
              title: 'Protein Sources',
              sources: data.proteinSources,
            ),
            const SizedBox(height: 10),
            _FoodSourceGroup(
              title: 'Carbohydrate Sources',
              sources: data.carbohydrateSources,
            ),
          ] else ...[
            _GeneratedMealFoods(foods: result!.foods, onSwapFood: onSwapFood),
            if (result!.reason.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                result!.reason,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ],
          if (error != null) ...[
            const SizedBox(height: 9),
            Text(
              error!,
              style: const TextStyle(fontSize: 11, color: Colors.redAccent),
            ),
          ],
          if (alignActionToBottom)
            const Spacer()
          else
            const SizedBox(height: 13),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLoading ? null : onBuild,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(error == null ? 'Build My Meal' : 'Try Again'),
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedMealFoods extends StatefulWidget {
  final List<MealBuilderFood> foods;
  final ValueChanged<int> onSwapFood;

  const _GeneratedMealFoods({required this.foods, required this.onSwapFood});

  @override
  State<_GeneratedMealFoods> createState() => _GeneratedMealFoodsState();
}

class _GeneratedMealFoodsState extends State<_GeneratedMealFoods> {
  bool _useImperialUnits = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FOOD SOURCES + PORTIONS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            _MealPortionUnitToggle(
              useImperialUnits: _useImperialUnits,
              onChanged: (value) {
                setState(() => _useImperialUnits = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Recommended portions (${_useImperialUnits ? 'oz' : 'g'}) based on what you still need today.',
          style: const TextStyle(
            fontSize: 11,
            height: 1.35,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 7),
        for (var index = 0; index < widget.foods.length; index++) ...[
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MealBuilderFoodChip(
                      key: ValueKey(widget.foods[index].foodKey),
                      foodName: widget.foods[index].displayName,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _mealFoodNutritionLine(
                        widget.foods[index],
                        useImperialUnits: _useImperialUnits,
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Next ${widget.foods[index].displayName} alternative',
                onPressed: () => widget.onSwapFood(index),
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                padding: const EdgeInsets.all(8),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.refresh_rounded,
                  size: 21,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
          if (index != widget.foods.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _MealPortionUnitToggle extends StatelessWidget {
  final bool useImperialUnits;
  final ValueChanged<bool> onChanged;

  const _MealPortionUnitToggle({
    required this.useImperialUnits,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MealPortionUnitOption(
            label: 'g',
            selected: !useImperialUnits,
            onTap: () => onChanged(false),
          ),
          _MealPortionUnitOption(
            label: 'oz',
            selected: useImperialUnits,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _MealPortionUnitOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MealPortionUnitOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Show Meal Builder portions in $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: selected ? Colors.white : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

const double _gramsPerOunce = 28.3495;

String _displayMealPortion(int amountG, {required bool useImperialUnits}) {
  if (useImperialUnits) {
    return '${(amountG / _gramsPerOunce).toStringAsFixed(1)} oz';
  }
  return '${amountG.round()} g';
}

String _mealFoodNutritionLine(
  MealBuilderFood food, {
  required bool useImperialUnits,
}) {
  final portion = _displayMealPortion(
    food.amountG,
    useImperialUnits: useImperialUnits,
  );
  final macro = switch (food.role.trim().toLowerCase()) {
    'protein' => '${food.nutrition.proteinG} g protein',
    'carb' || 'carbohydrate' => '${food.nutrition.carbsG} g carbs',
    'fat' => '${food.nutrition.fatG} g fat',
    _ => _largestMealFoodMacro(food.nutrition),
  };
  return '$portion / ${food.nutrition.calories} kcal / $macro';
}

String _largestMealFoodMacro(MealBuilderMacros nutrition) {
  if (nutrition.proteinG >= nutrition.carbsG &&
      nutrition.proteinG >= nutrition.fatG) {
    return '${nutrition.proteinG} g protein';
  }
  if (nutrition.carbsG >= nutrition.fatG) {
    return '${nutrition.carbsG} g carbs';
  }
  return '${nutrition.fatG} g fat';
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

class _CalorieMagnifierCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool alignActionToBottom;

  const _CalorieMagnifierCard({
    required this.onTap,
    this.alignActionToBottom = false,
  });

  @override
  Widget build(BuildContext context) {
    const content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CalorieMagnifierIcon(),
        SizedBox(height: 18),
        Text(
          'Calorie Magnifier',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Take Photo or Upload Photo',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        SizedBox(height: 20),
      ],
    );

    return Semantics(
      button: true,
      label: 'Open Calorie Magnifier',
      child: GestureDetector(
        onTap: onTap,
        child: _SurfaceCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (alignActionToBottom)
                const Expanded(child: content)
              else
                content,
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Open Calorie Magnifier'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalorieMagnifierIcon extends StatelessWidget {
  const _CalorieMagnifierIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppTheme.visionCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(alpha: 0.16),
        ),
      ),
      child: const Icon(
        Icons.camera_alt_outlined,
        size: 34,
        color: AppTheme.primaryGreen,
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
              _MealBuilderFoodChip(key: ValueKey(source), foodName: source),
          ],
        ),
      ],
    );
  }
}

class _MealBuilderFoodChip extends StatefulWidget {
  final String foodName;

  const _MealBuilderFoodChip({super.key, required this.foodName});

  @override
  State<_MealBuilderFoodChip> createState() => _MealBuilderFoodChipState();
}

class _MealBuilderFoodChipState extends State<_MealBuilderFoodChip> {
  static final FoodVisualService _visualService = FoodVisualService();

  FoodVisual? _visual;

  @override
  void initState() {
    super.initState();
    _resolveImage();
  }

  @override
  void didUpdateWidget(covariant _MealBuilderFoodChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodName != widget.foodName) {
      _visual = null;
      _resolveImage();
    }
  }

  Future<void> _resolveImage() async {
    final requestedFood = widget.foodName;
    final visual = await _visualService.resolveFoodImage(requestedFood);
    if (!mounted || widget.foodName != requestedFood) return;

    if (!visual.isReady) {
      debugPrint(
        'Food visual unavailable for "$requestedFood": '
        '${visual.errorCode} ${visual.message}',
      );
    }
    setState(() => _visual = visual);
  }

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
          if (_visual == null)
            const _FoodImageLoadingPlaceholder()
          else if (_visual!.isReady)
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: Image.network(
                _visual!.imageUrl!,
                width: 24,
                height: 24,
                fit: BoxFit.cover,
                errorBuilder: (_, error, _) {
                  debugPrint(
                    'Food image load failed for "${widget.foodName}": $error',
                  );
                  return const _FoodImageFallback();
                },
              ),
            )
          else
            const _FoodImageFallback(),
          const SizedBox(width: 6),
          Text(
            widget.foodName,
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

class _FoodImageLoadingPlaceholder extends StatelessWidget {
  const _FoodImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE7ECE9),
      ),
      padding: const EdgeInsets.all(7),
      child: const CircularProgressIndicator(
        strokeWidth: 1.5,
        color: AppTheme.primaryGreen,
      ),
    );
  }
}

class _FoodImageFallback extends StatelessWidget {
  const _FoodImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFE7ECE9),
      ),
      child: const Icon(
        Icons.restaurant_outlined,
        size: 13,
        color: AppTheme.textSecondary,
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
  final List<RankedCookForGoalRecipe> recipes;
  final Set<int> refreshingIndexes;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<int> onTryAnother;

  const _RecipeList({
    required this.recipes,
    required this.refreshingIndexes,
    required this.isLoading,
    required this.error,
    required this.onRetry,
    required this.onTryAnother,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _SurfaceCard(
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      return _SurfaceCard(
        child: Column(
          children: [
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (recipes.isEmpty) {
      return _SurfaceCard(
        child: Column(
          children: [
            const Text(
              'No recipes safely match your current dietary restrictions.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 760;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var index = 0; index < recipes.length; index++) ...[
                Expanded(
                  child: _RecipeCard(
                    recommendation: recipes[index],
                    index: index,
                    isRefreshing: refreshingIndexes.contains(index),
                    onTryAnother: () => onTryAnother(index),
                  ),
                ),
                if (index != recipes.length - 1) const SizedBox(width: 10),
              ],
            ],
          );
        }

        return Column(
          children: [
            for (var index = 0; index < recipes.length; index++) ...[
              _RecipeCard(
                recommendation: recipes[index],
                index: index,
                isRefreshing: refreshingIndexes.contains(index),
                onTryAnother: () => onTryAnother(index),
              ),
              if (index != recipes.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _RecipeCard extends StatelessWidget {
  final RankedCookForGoalRecipe recommendation;
  final int index;
  final bool isRefreshing;
  final VoidCallback onTryAnother;

  const _RecipeCard({
    required this.recommendation,
    required this.index,
    required this.isRefreshing,
    required this.onTryAnother,
  });

  @override
  Widget build(BuildContext context) {
    final recipe = recommendation.recipe;
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
              if (recipe.imageAssetPath != null)
                NutritionAssetImage(
                  assetPath: recipe.imageAssetPath!,
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(16),
                  fallbackIcon: icons[index % icons.length],
                )
              else
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.visionCard,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    icons[index % icons.length],
                    color: AppTheme.primaryGreen,
                  ),
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
              _RecipeStat('~${recipe.nutrition.calories} kcal'),
              _RecipeStat('${recipe.nutrition.proteinG} g Protein'),
              _RecipeStat('${recipe.nutrition.carbsG} g Carbs'),
              _RecipeStat('${recipe.nutrition.fatG} g Fat'),
              _RecipeStat('${recipe.totalMinutes} min'),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            recommendation.reason,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              height: 1.35,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => CookForGoalRecipeScreen(recipe: recipe),
                    ),
                  );
                },
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
              IconButton(
                tooltip: 'Try Another Recipe',
                onPressed: isRefreshing ? null : onTryAnother,
                constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
                padding: const EdgeInsets.all(6),
                visualDensity: VisualDensity.compact,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.refresh_rounded,
                        size: 19,
                        color: AppTheme.primaryGreen,
                      ),
              ),
            ],
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
