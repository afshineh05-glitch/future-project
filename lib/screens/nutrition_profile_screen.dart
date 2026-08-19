import 'package:flutter/material.dart';

import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/services/nutrition_profile_service.dart';
import 'package:future_project/theme/app_theme.dart';

class NutritionProfileScreen extends StatefulWidget {
  final NutritionProfile? initialProfile;
  final bool isOnboarding;
  final ValueChanged<NutritionProfile>? onSaved;

  const NutritionProfileScreen({
    super.key,
    this.initialProfile,
    required this.isOnboarding,
    this.onSaved,
  });

  @override
  State<NutritionProfileScreen> createState() => _NutritionProfileScreenState();
}

class _NutritionProfileScreenState extends State<NutritionProfileScreen> {
  static const _dietTypes = ['Omnivore', 'Vegetarian', 'Vegan', 'Pescatarian'];
  static const _allergies = [
    'None',
    'Nuts',
    'Dairy',
    'Eggs',
    'Seafood',
    'Gluten',
    'Other',
  ];
  static const _mealCounts = ['2', '3', '4', '5+'];
  static const _cookingTimes = ['≤15 min', '≤30 min', '≤45 min'];
  static const _cookingSkills = ['Beginner', 'Comfortable', 'Advanced'];
  static const _budgets = ['Budget-conscious', 'Moderate', 'Flexible'];

  final _avoidController = TextEditingController();
  final _dislikeController = TextEditingController();
  final _service = NutritionProfileService();

  String? _dietType;
  final Set<String> _selectedAllergies = <String>{};
  final List<String> _foodsToAvoid = <String>[];
  final List<String> _dislikedFoods = <String>[];
  String? _mealsPerDay;
  String? _maximumCookingTime;
  String? _cookingSkill;
  String? _foodBudget;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile != null) {
      _dietType = profile.dietType;
      _selectedAllergies.addAll(profile.foodAllergies);
      _foodsToAvoid.addAll(profile.foodsToAvoid);
      _dislikedFoods.addAll(profile.dislikedFoods);
      _mealsPerDay = profile.mealsPerDay;
      _maximumCookingTime = profile.maximumCookingTime;
      _cookingSkill = profile.cookingSkill;
      _foodBudget = profile.foodBudget;
    } else {
      _selectedAllergies.add('None');
    }
  }

  @override
  void dispose() {
    _avoidController.dispose();
    _dislikeController.dispose();
    super.dispose();
  }

  void _toggleAllergy(String allergy) {
    setState(() {
      if (allergy == 'None') {
        _selectedAllergies
          ..clear()
          ..add('None');
        return;
      }

      _selectedAllergies.remove('None');
      if (!_selectedAllergies.add(allergy)) {
        _selectedAllergies.remove(allergy);
      }
      if (_selectedAllergies.isEmpty) {
        _selectedAllergies.add('None');
      }
    });
  }

  void _addCustomEntry(TextEditingController controller, List<String> list) {
    final value = controller.text.trim();
    if (value.isEmpty) return;
    final alreadyExists = list.any(
      (item) => item.toLowerCase() == value.toLowerCase(),
    );
    if (!alreadyExists) {
      setState(() => list.add(value));
    }
    controller.clear();
  }

  bool get _isComplete {
    return _dietType != null &&
        _selectedAllergies.isNotEmpty &&
        _mealsPerDay != null &&
        _maximumCookingTime != null &&
        _cookingSkill != null &&
        _foodBudget != null;
  }

  Future<void> _save() async {
    if (!_isComplete || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      final profile = NutritionProfile(
        userId: _service.requireCurrentUserId(),
        dietType: _dietType!,
        foodAllergies: _selectedAllergies.toList()..sort(),
        foodsToAvoid: List<String>.from(_foodsToAvoid),
        dislikedFoods: List<String>.from(_dislikedFoods),
        mealsPerDay: _mealsPerDay!,
        maximumCookingTime: _maximumCookingTime!,
        cookingSkill: _cookingSkill!,
        foodBudget: _foodBudget!,
      );

      await _service.save(profile);
      if (!mounted) return;
      widget.onSaved?.call(profile);

      if (!widget.isOnboarding) {
        Navigator.pop(context, profile);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save Nutrition Profile: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isOnboarding,
        title: Text(
          widget.isOnboarding
              ? 'Set Up Nutrition Profile'
              : 'Edit Nutrition Profile',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
        children: [
          Text(
            widget.isOnboarding
                ? 'Tell us about the foods and cooking choices that work for you. You only need to do this once.'
                : 'Update the food preferences used to personalize Nutrition.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          _QuestionCard(
            number: 1,
            title: 'Diet Type',
            child: _ChoiceWrap(
              options: _dietTypes,
              selected: _dietType,
              onSelected: (value) => setState(() => _dietType = value),
            ),
          ),
          _QuestionCard(
            number: 2,
            title: 'Food Allergies',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final allergy in _allergies)
                  FilterChip(
                    label: Text(allergy),
                    selected: _selectedAllergies.contains(allergy),
                    onSelected: (_) => _toggleAllergy(allergy),
                    selectedColor: AppTheme.visionCard,
                    checkmarkColor: AppTheme.primaryGreen,
                    side: const BorderSide(color: AppTheme.border),
                  ),
              ],
            ),
          ),
          _QuestionCard(
            number: 3,
            title: 'Foods to Avoid',
            subtitle: 'Add as many as needed.',
            child: _CustomEntries(
              controller: _avoidController,
              entries: _foodsToAvoid,
              hintText: 'Example: mushrooms',
              onAdd: () => _addCustomEntry(_avoidController, _foodsToAvoid),
              onRemove: (value) => setState(() => _foodsToAvoid.remove(value)),
            ),
          ),
          _QuestionCard(
            number: 4,
            title: 'Foods / Ingredients Disliked',
            subtitle: 'Add as many as needed.',
            child: _CustomEntries(
              controller: _dislikeController,
              entries: _dislikedFoods,
              hintText: 'Example: cilantro',
              onAdd: () => _addCustomEntry(_dislikeController, _dislikedFoods),
              onRemove: (value) => setState(() => _dislikedFoods.remove(value)),
            ),
          ),
          _QuestionCard(
            number: 5,
            title: 'Meals Per Day',
            child: _ChoiceWrap(
              options: _mealCounts,
              selected: _mealsPerDay,
              onSelected: (value) => setState(() => _mealsPerDay = value),
            ),
          ),
          _QuestionCard(
            number: 6,
            title: 'Maximum Cooking Time',
            child: _ChoiceWrap(
              options: _cookingTimes,
              selected: _maximumCookingTime,
              onSelected: (value) =>
                  setState(() => _maximumCookingTime = value),
            ),
          ),
          _QuestionCard(
            number: 7,
            title: 'Cooking Skill',
            child: _ChoiceWrap(
              options: _cookingSkills,
              selected: _cookingSkill,
              onSelected: (value) => setState(() => _cookingSkill = value),
            ),
          ),
          _QuestionCard(
            number: 8,
            title: 'Food Budget',
            child: _ChoiceWrap(
              options: _budgets,
              selected: _foodBudget,
              onSelected: (value) => setState(() => _foodBudget = value),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isComplete && !_isSaving ? _save : null,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving
                    ? 'Saving...'
                    : widget.isOnboarding
                    ? 'Save Nutrition Profile'
                    : 'Save Changes',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final int number;
  final String title;
  final String? subtitle;
  final Widget child;

  const _QuestionCard({
    required this.number,
    required this.title,
    this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                  '$number',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 37),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 13),
          child,
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _ChoiceWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in options)
          ChoiceChip(
            label: Text(option),
            selected: selected == option,
            onSelected: (_) => onSelected(option),
            selectedColor: AppTheme.visionCard,
            checkmarkColor: AppTheme.primaryGreen,
            side: const BorderSide(color: AppTheme.border),
          ),
      ],
    );
  }
}

class _CustomEntries extends StatelessWidget {
  final TextEditingController controller;
  final List<String> entries;
  final String hintText;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  const _CustomEntries({
    required this.controller,
    required this.entries,
    required this.hintText,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAdd(),
                decoration: InputDecoration(hintText: hintText, isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              tooltip: 'Add',
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final entry in entries)
                InputChip(
                  label: Text(entry),
                  onDeleted: () => onRemove(entry),
                  deleteIconColor: AppTheme.textSecondary,
                  side: const BorderSide(color: AppTheme.border),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
