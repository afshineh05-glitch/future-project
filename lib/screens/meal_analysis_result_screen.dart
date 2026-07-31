import 'dart:io';

import 'package:flutter/material.dart';

import 'package:future_project/models/meal_analysis_result.dart';
import 'package:future_project/theme/app_theme.dart';

class MealAnalysisResultScreen extends StatelessWidget {
  final File imageFile;
  final MealAnalysisResult result;

  const MealAnalysisResultScreen({
    super.key,
    required this.imageFile,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final String detectedFoodsText = result.detectedFoods.isEmpty
        ? 'No food items detected.'
        : result.detectedFoods
            .map((food) => '• $food')
            .join('\n');

    final int confidencePercent =
        (result.confidence.clamp(0.0, 1.0) * 100).round();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Meal Analysis'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.file(
              imageFile,
              width: double.infinity,
              height: 260,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: double.infinity,
                  height: 260,
                  alignment: Alignment.center,
                  color: AppTheme.card,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 48,
                    color: AppTheme.textSecondary,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          Text(
            result.mealName,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            'AI confidence: $confidencePercent%',
            style: const TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'Nutrition values are estimates based on the visible meal.',
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          _NutritionGrid(
            items: [
              _NutritionItem(
                label: 'Calories',
                value: '${result.calories} kcal',
                icon: Icons.local_fire_department_outlined,
              ),
              _NutritionItem(
                label: 'Protein',
                value: '${_formatNumber(result.protein)} g',
                icon: Icons.fitness_center_outlined,
              ),
              _NutritionItem(
                label: 'Carbs',
                value: '${_formatNumber(result.carbs)} g',
                icon: Icons.grain_outlined,
              ),
              _NutritionItem(
                label: 'Fat',
                value: '${_formatNumber(result.fat)} g',
                icon: Icons.opacity_outlined,
              ),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detected Food',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  detectedFoodsText,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.7,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Done'),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }
}

class _NutritionGrid extends StatelessWidget {
  final List<_NutritionItem> items;

  const _NutritionGrid({
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 1.8,
      ),
      itemBuilder: (context, index) {
        final _NutritionItem item = items[index];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                item.icon,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.value,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NutritionItem {
  final String label;
  final String value;
  final IconData icon;

  const _NutritionItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}