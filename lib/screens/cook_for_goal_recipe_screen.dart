import 'package:flutter/material.dart';

import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/nutrition_asset_image.dart';

class CookForGoalRecipeScreen extends StatelessWidget {
  final CookForGoalRecipe recipe;

  const CookForGoalRecipeScreen({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    final nutrition = recipe.nutrition;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Recipe')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          if (recipe.imageAssetPath != null)
            NutritionAssetImage(
              assetPath: recipe.imageAssetPath!,
              width: double.infinity,
              height: 210,
              borderRadius: BorderRadius.circular(22),
              fallbackIcon: Icons.restaurant_outlined,
            )
          else
            Container(
              height: 150,
              decoration: BoxDecoration(
                color: AppTheme.visionCard,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                size: 48,
                color: AppTheme.primaryGreen,
              ),
            ),
          const SizedBox(height: 18),
          Text(
            recipe.name,
            style: const TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _DetailChip('${nutrition.calories} kcal'),
              _DetailChip('${nutrition.proteinG} g protein'),
              _DetailChip('${nutrition.carbsG} g carbs'),
              _DetailChip('${nutrition.fatG} g fat'),
              _DetailChip('${recipe.servings} serving'),
              _DetailChip('${recipe.preparationMinutes} min prep'),
              _DetailChip('${recipe.cookingMinutes} min cook'),
            ],
          ),
          const SizedBox(height: 24),
          const _DetailHeading('Ingredients'),
          const SizedBox(height: 10),
          for (final ingredient in recipe.ingredients)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${ingredient.quantity} ${ingredient.name}',
                      style: const TextStyle(
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 18),
          const _DetailHeading('Instructions'),
          const SizedBox(height: 10),
          for (final instruction in recipe.instructions)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 27,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${instruction.step}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      instruction.text,
                      style: const TextStyle(
                        height: 1.45,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailHeading extends StatelessWidget {
  final String label;

  const _DetailHeading(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}
