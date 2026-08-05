import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:future_project/theme/app_theme.dart';

class MyFoundationScreen extends StatefulWidget {
  const MyFoundationScreen({super.key});

  @override
  State<MyFoundationScreen> createState() {
    return _MyFoundationScreenState();
  }
}

class _MyFoundationScreenState extends State<MyFoundationScreen> {
  static const int _totalSteps = 12;

  static const List<String> _stepTitles = [
    'About You',
    'Your Goal',
    'Body Details',
    'Lifestyle',
    'Nutrition',
    'Health',
    'Nutrition',
    'Measurements',
    'Body Photos',
    'Preferences',
    'Review',
    'Finish',
  ];

  static const List<String> _stepDescriptions = [
    'Tell MuscleUp the basics about you.',
    'Choose what you want to achieve.',
    'Add your current body information.',
    'Describe your daily activity and routine.',
    'Describe your eating habits and preferences.',
    'Share any limitations that may affect training.',
    'Describe your eating habits and preferences.',
    'Add optional body measurements.',
    'Add optional progress photos.',
    'Choose how your coach should guide you.',
    'Review the information you provided.',
    'Your personal foundation is ready.',
  ];

  final GlobalKey<FormState> _aboutYouFormKey =
      GlobalKey<FormState>();

  final GlobalKey<FormState> _goalFormKey =
      GlobalKey<FormState>();

  final TextEditingController _ageController =
      TextEditingController();

  final TextEditingController _heightCmController =
      TextEditingController();

  final TextEditingController _heightFeetController =
      TextEditingController();

  final TextEditingController _heightInchesController =
      TextEditingController();

  final TextEditingController _weightController =
      TextEditingController();

  final TextEditingController _targetWeightController =
      TextEditingController();
String _measurementSystem = 'metric';
  String? _selectedSex;
  String? _selectedGoal;
  String? _selectedBodyType;

  final Map<String, String> _lifestyleAnswers = <String, String>{};
  final Set<String> _selectedEquipment = <String>{};
  final Set<String> _selectedInjuries = <String>{};

  final Map<String, String> _nutritionAnswers = <String, String>{};
  final Set<String> _selectedMeals = <String>{};
  final Set<String> _selectedAllergies = <String>{};
  final Set<String> _selectedFoodsToAvoid = <String>{};

  int _currentStep = 0;

  double get _progress {
    return (_currentStep + 1) / _totalSteps;
  }

  bool get _isFirstStep {
    return _currentStep == 0;
  }

  bool get _isLastStep {
    return _currentStep == _totalSteps - 1;
  }

  bool get _isMetric {
    return _measurementSystem == 'metric';
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightCmController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();

    super.dispose();
  }

  void _goNext() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 0 && !_validateAboutYouStep()) {
      return;
    }

    if (_currentStep == 1 && !_validateGoalStep()) {
      return;
    }

    if (_currentStep == 2 && !_validateBodyTypeStep()) {
      return;
    }

    if (_currentStep == 3 && !_validateLifestyleStep()) {
      return;
    }

    if (_currentStep == 4 && !_validateNutritionStep()) {
      return;
    }

    if (_isLastStep) {
      _completeFoundation();
      return;
    }

    setState(() {
      _currentStep++;
    });
  }

  void _goBack() {
    FocusScope.of(context).unfocus();

    if (_isFirstStep) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _currentStep--;
    });
  }

  bool _validateAboutYouStep() {
    final bool formIsValid =
        _aboutYouFormKey.currentState?.validate() ?? false;

    if (_selectedSex == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your sex.',
          ),
        ),
      );

      return false;
    }

    return formIsValid;
  }

  bool _validateGoalStep() {
    final bool formIsValid =
        _goalFormKey.currentState?.validate() ?? false;

    if (_selectedGoal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please choose your primary goal.',
          ),
        ),
      );

      return false;
    }

    return formIsValid;
  }

  bool _validateBodyTypeStep() {
    if (_selectedBodyType != null) {
      return true;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Please select the body type closest to you.',
        ),
      ),
    );

    return false;
  }


  bool _validateLifestyleStep() {
    const requiredKeys = <String>[
      'activity',
      'occupation',
      'exercise_days',
      'workout_duration',
      'workout_intensity',
      'sleep_hours',
      'sleep_quality',
      'water',
      'stress',
      'steps',
      'workout_time',
      'motivation',
      'gym_access',
      'experience',
      'obstacle',
    ];

    for (final key in requiredKeys) {
      if (!_lifestyleAnswers.containsKey(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please answer all Lifestyle questions.',
            ),
          ),
        );
        return false;
      }
    }

    if (_selectedEquipment.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your available equipment.',
          ),
        ),
      );
      return false;
    }

    if (_selectedInjuries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your injury status.',
          ),
        ),
      );
      return false;
    }

    final hasInjury =
        !_selectedInjuries.contains('none');

    if (hasInjury &&
        (!_lifestyleAnswers.containsKey('pain') ||
            !_lifestyleAnswers.containsKey('restriction'))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete the injury details.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  bool _validateNutritionStep() {
    const requiredKeys = <String>[
      'eating_style',
      'meals_per_day',
      'cooking_frequency',
      'eating_location',
      'prep_time',
      'nutrition_challenge',
      'ai_meal_plans',
    ];

    for (final String key in requiredKeys) {
      if (!_nutritionAnswers.containsKey(key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please answer all Nutrition questions.',
            ),
          ),
        );
        return false;
      }
    }

    if (_selectedMeals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select the meals you usually eat.',
          ),
        ),
      );
      return false;
    }

    if (_selectedAllergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select your allergy status.',
          ),
        ),
      );
      return false;
    }

    if (_selectedFoodsToAvoid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select foods you avoid, or None.',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  void _completeFoundation() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'My Foundation is ready to be saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentTitle =
        _stepTitles[_currentStep];

    final String currentDescription =
        _stepDescriptions[_currentStep];

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        leading: IconButton(
          tooltip: _isFirstStep ? 'Exit' : 'Back',
          onPressed: _goBack,
          icon: const Icon(
            Icons.arrow_back,
          ),
        ),
        title: const Text(
          'My Foundation',
          style: TextStyle(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            24,
            12,
            24,
            24,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _buildProgressHeader(),

              const SizedBox(height: 28),

              Text(
                currentTitle,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                currentDescription,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'The more MuscleUp understands you, '
                'the better it can guide you.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),

              const SizedBox(height: 22),

              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.card,
                    borderRadius:
                        BorderRadius.circular(24),
                    border: Border.all(
                      color: AppTheme.border,
                    ),
                  ),
                  child: AnimatedSwitcher(
                    duration:
                        const Duration(milliseconds: 250),
                    child: _buildStepContent(),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
            Text(
              '${(_progress * 100).round()}%',
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
            value: _progress,
            minHeight: 9,
            backgroundColor: AppTheme.border,
            valueColor:
                const AlwaysStoppedAnimation<Color>(
              AppTheme.primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _goBack,
            style: OutlinedButton.styleFrom(
              foregroundColor:
                  AppTheme.textPrimary,
              minimumSize:
                  const Size.fromHeight(54),
              side: const BorderSide(
                color: AppTheme.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
            ),
            child: Text(
              _isFirstStep ? 'Exit' : 'Back',
            ),
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: _goNext,
            style: FilledButton.styleFrom(
              backgroundColor:
                  AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              minimumSize:
                  const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(18),
              ),
            ),
            icon: Icon(
              _isLastStep
                  ? Icons.check_circle_outline
                  : Icons.arrow_forward,
            ),
            label: Text(
              _isLastStep
                  ? 'Complete'
                  : 'Continue',
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildStepContent() {
    if (_currentStep == 0) {
      return _buildAboutYouStep();
    }

    if (_currentStep == 1) {
      return _buildGoalStep();
    }

    if (_currentStep == 2) {
      return _buildBodyTypeStep();
    }

    if (_currentStep == 3) {
      return _buildLifestyleStep();
    }

    if (_currentStep == 4) {
      return _buildNutritionStep();
    }

    return _buildPlaceholderStep();
  }

  Widget _buildAboutYouStep() {
    return SingleChildScrollView(
      key: const ValueKey<String>('about-you'),
      child: Form(
        key: _aboutYouFormKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildSectionIntro(
              icon: Icons.person_outline,
              title: 'Let’s start with you',
              description:
                  'These details help MuscleUp calculate '
                  'a safer and more relevant starting point.',
            ),

            const SizedBox(height: 26),

            _buildFieldLabel(
              label: 'Measurement System',
              required: true,
            ),

            const SizedBox(height: 10),

            _buildMeasurementSelector(),

            const SizedBox(height: 24),

            _buildFieldLabel(
              label: 'Age',
              required: true,
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _ageController,
              keyboardType:
                  TextInputType.number,
              textInputAction:
                  TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: _inputDecoration(
                hintText: 'Enter your age',
                suffixText: 'years',
              ),
              validator: _validateAge,
            ),

            const SizedBox(height: 20),

            _buildFieldLabel(
              label: 'Sex',
              required: true,
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _selectedSex,
              isExpanded: true,
              decoration: _inputDecoration(
                hintText: 'Select',
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'male',
                  child: Text('Male'),
                ),
                DropdownMenuItem<String>(
                  value: 'female',
                  child: Text('Female'),
                ),
                DropdownMenuItem<String>(
                  value: 'prefer_not_to_say',
                  child: Text(
                    'Prefer not to say',
                  ),
                ),
              ],
              onChanged: (String? value) {
                setState(() {
                  _selectedSex = value;
                  _selectedBodyType = null;
                });
              },
              validator: (String? value) {
                if (value == null) {
                  return 'Please select an option.';
                }

                return null;
              },
            ),

            const SizedBox(height: 20),

            _buildHeightFields(),

            const SizedBox(height: 20),

            _buildFieldLabel(
              label: 'Current Weight',
              required: true,
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction:
                  TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,1}'),
                ),
              ],
              decoration: _inputDecoration(
                hintText:
                    'Enter your current weight',
                suffixText: _isMetric ? 'kg' : 'lb',
              ),
              validator: _validateWeight,
            ),

            const SizedBox(height: 20),

            _buildFieldLabel(
              label: 'Target Weight',
              required: false,
            ),

            const SizedBox(height: 8),

            TextFormField(
              controller:
                  _targetWeightController,
              keyboardType:
                  const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction:
                  TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,1}'),
                ),
              ],
              decoration: _inputDecoration(
                hintText: 'Optional',
                suffixText: _isMetric ? 'kg' : 'lb',
              ),
              validator: _validateOptionalWeight,
            ),

            const SizedBox(height: 12),

            const Text(
              'You can update these values later.',
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGoalStep() {
    return SingleChildScrollView(
      key: const ValueKey<String>('your-goal'),
      child: Form(
        key: _goalFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionIntro(
              icon: Icons.flag_outlined,
              title: 'What are you working toward?',
              description:
                  'Choose your primary fitness goal.',
            ),
            const SizedBox(height: 26),
            _buildFieldLabel(
              label: 'Primary Goal',
              required: true,
            ),
            const SizedBox(height: 12),
            _buildGoalOptions(),
          ],
        ),
      ),
    );
  }

  Widget _buildMeasurementSelector() {
    return Row(
      children: [
        Expanded(
          child: _SelectionCard(
            selected: _measurementSystem == 'metric',
            title: 'Metric',
            subtitle: 'cm & kg',
            onTap: () {
              setState(() {
                _measurementSystem = 'metric';
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SelectionCard(
            selected:
                _measurementSystem == 'imperial',
            title: 'Imperial',
            subtitle: 'ft, in & lb',
            onTap: () {
              setState(() {
                _measurementSystem = 'imperial';
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeightFields() {
    if (_isMetric) {
      return Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(
            label: 'Height',
            required: true,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _heightCmController,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            textInputAction:
                TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,1}'),
              ),
            ],
            decoration: _inputDecoration(
              hintText: 'Enter your height',
              suffixText: 'cm',
            ),
            validator: _validateHeightCm,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(
          label: 'Height',
          required: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller:
                    _heightFeetController,
                keyboardType:
                    TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly,
                  LengthLimitingTextInputFormatter(
                    1,
                  ),
                ],
                decoration: _inputDecoration(
                  hintText: 'Feet',
                  suffixText: 'ft',
                ),
                validator: _validateHeightFeet,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller:
                    _heightInchesController,
                keyboardType:
                    TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter
                      .digitsOnly,
                  LengthLimitingTextInputFormatter(
                    2,
                  ),
                ],
                decoration: _inputDecoration(
                  hintText: 'Inches',
                  suffixText: 'in',
                ),
                validator: _validateHeightInches,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGoalOptions() {
    const goals = [
      ('lose_fat', 'Lose Fat'),
      ('build_muscle', 'Build Muscle'),
      ('maintain_weight', 'Maintain Weight'),
      ('improve_fitness', 'Improve Fitness'),
      ('improve_health', 'Improve Health'),
      ('athletic_performance', 'Athletic Performance'),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: goals.map((goal) {
        final bool selected =
            _selectedGoal == goal.$1;

        return ChoiceChip(
          label: Text(goal.$2),
          selected: selected,
          onSelected: (_) {
            setState(() {
              _selectedGoal = goal.$1;
            });
          },
          selectedColor:
              AppTheme.primaryGreen.withValues(
            alpha: 0.14,
          ),
          side: BorderSide(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.border,
          ),
          labelStyle: TextStyle(
            color: selected
                ? AppTheme.primaryGreen
                : AppTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        );
      }).toList(),
    );
  }


  Widget _buildBodyTypeStep() {
    final bool isFemale = _selectedSex == 'female';

    final List<_BodyTypeOption> bodyTypes = [
      _BodyTypeOption(
        value: 'ectomorph',
        title: 'Ectomorph',
        subtitle: 'Naturally lean with a lighter frame',
        imagePath: isFemale
            ? 'assets/body_types/female_ectomorph.png'
            : 'assets/body_types/male_ectomorph.png',
      ),
      _BodyTypeOption(
        value: 'mesomorph',
        title: 'Mesomorph',
        subtitle: 'Naturally athletic and muscular',
        imagePath: isFemale
            ? 'assets/body_types/female_mesomorph.png'
            : 'assets/body_types/male_mesomorph.png',
      ),
      _BodyTypeOption(
        value: 'endomorph',
        title: 'Endomorph',
        subtitle: 'Broader frame with easier weight gain',
        imagePath: isFemale
            ? 'assets/body_types/female_endomorph.png'
            : 'assets/body_types/male_endomorph.png',
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('body-type'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            icon: Icons.accessibility_new_outlined,
            title: 'Which body type looks closest to you?',
            description:
                'Choose the option that most closely matches your current physique.',
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.calorieCard,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Most people are a mix of body types. '
                    'Choose the closest current match.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.45,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (
              BuildContext context,
              BoxConstraints constraints,
            ) {
              if (constraints.maxWidth >= 850) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (
                      int index = 0;
                      index < bodyTypes.length;
                      index++
                    )
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            right: index == bodyTypes.length - 1
                                ? 0
                                : 14,
                          ),
                          child: _buildBodyTypeCard(
                            bodyTypes[index],
                          ),
                        ),
                      ),
                  ],
                );
              }

              return Column(
                children: [
                  for (final _BodyTypeOption bodyType in bodyTypes)
                    Padding(
                      padding: const EdgeInsets.only(
                        bottom: 14,
                      ),
                      child: _buildBodyTypeCard(
                        bodyType,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBodyTypeCard(
    _BodyTypeOption bodyType,
  ) {
    final bool selected =
        _selectedBodyType == bodyType.value;

    return AnimatedScale(
      scale: selected ? 1.015 : 1,
      duration: const Duration(milliseconds: 180),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedBodyType = bodyType.value;
            });
          },
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primaryGreen.withValues(
                      alpha: 0.08,
                    )
                  : AppTheme.background,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected
                    ? AppTheme.primaryGreen
                    : AppTheme.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius:
                          const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: AspectRatio(
                        aspectRatio: 0.82,
                        child: Image.asset(
                          bodyType.imagePath,
                          fit: BoxFit.contain,
                          errorBuilder: (
                            BuildContext context,
                            Object error,
                            StackTrace? stackTrace,
                          ) {
                            return Container(
                              color: AppTheme.calorieCard,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.broken_image_outlined,
                                size: 58,
                                color: AppTheme.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (selected)
                      const Positioned(
                        top: 12,
                        right: 12,
                        child: CircleAvatar(
                          radius: 17,
                          backgroundColor:
                              AppTheme.primaryGreen,
                          child: Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 21,
                          ),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    14,
                    16,
                    18,
                  ),
                  child: Column(
                    children: [
                      Text(
                        bodyType.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: selected
                              ? AppTheme.primaryGreen
                              : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        bodyType.subtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildLifestyleStep() {
    final hasInjury =
        _selectedInjuries.isNotEmpty &&
        !_selectedInjuries.contains('none');

    final questions = <_LifestyleQuestion>[
      const _LifestyleQuestion(
        keyName: 'activity',
        title: 'How active are you during a typical day?',
        options: [
          'Mostly Sitting',
          'Lightly Active',
          'Moderately Active',
          'Very Active',
          'Extremely Active',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'occupation',
        title: 'What best describes your occupation?',
        options: [
          'Office / Desk Job',
          'Student',
          'Remote Worker',
          'Retail / Customer Service',
          'Physical Labor',
          'Healthcare',
          'Other',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'exercise_days',
        title: 'How many days per week do you exercise?',
        options: [
          'Never',
          '1–2 Days',
          '3–4 Days',
          '5–6 Days',
          'Every Day',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'workout_duration',
        title: 'How long is your average workout?',
        options: [
          'Less than 30 Minutes',
          '30–45 Minutes',
          '45–60 Minutes',
          '60–90 Minutes',
          'More than 90 Minutes',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'workout_intensity',
        title: 'How would you describe your workout intensity?',
        options: [
          'Very Light',
          'Light',
          'Moderate',
          'Hard',
          'Very Hard',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'sleep_hours',
        title: 'How many hours do you usually sleep?',
        options: [
          'Less than 5 Hours',
          '5–6 Hours',
          '6–7 Hours',
          '7–8 Hours',
          'More than 8 Hours',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'sleep_quality',
        title: 'How would you rate your sleep quality?',
        options: ['Poor', 'Fair', 'Good', 'Excellent'],
      ),
      const _LifestyleQuestion(
        keyName: 'water',
        title: 'How much water do you drink each day?',
        options: [
          'Less than 1 L',
          '1–2 L',
          '2–3 L',
          '3–4 L',
          'More than 4 L',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'stress',
        title: 'How stressful is your daily life?',
        options: [
          'Very Low',
          'Low',
          'Moderate',
          'High',
          'Very High',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'steps',
        title: 'How many steps do you usually walk each day?',
        options: [
          'Less than 3,000',
          '3,000–6,000',
          '6,000–10,000',
          '10,000–15,000',
          'More than 15,000',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'workout_time',
        title: 'When do you usually prefer to work out?',
        options: [
          'Early Morning',
          'Morning',
          'Afternoon',
          'Evening',
          'Late Night',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'motivation',
        title: 'What motivates you the most?',
        options: [
          'Build Muscle',
          'Lose Fat',
          'Improve Health',
          'Increase Energy',
          'Athletic Performance',
          'Look Better',
          'Feel More Confident',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'gym_access',
        title: 'Where do you usually work out?',
        options: [
          'Home Only',
          'Gym Only',
          'Home & Gym',
          'Outdoors',
          'Not Sure Yet',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'experience',
        title: 'What is your training experience?',
        options: [
          'Beginner',
          'Intermediate',
          'Advanced',
        ],
      ),
      const _LifestyleQuestion(
        keyName: 'obstacle',
        title: 'What is your biggest obstacle to staying consistent?',
        options: [
          'Lack of Time',
          'Lack of Motivation',
          'Busy Schedule',
          'Poor Nutrition',
          'Low Energy',
          "Don't Know What to Do",
          'Inconsistent Routine',
          'Other',
        ],
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('lifestyle'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            icon: Icons.directions_walk_outlined,
            title: 'Tell us about your lifestyle',
            description:
                'Tap the options that best describe you. '
                'No typing required.',
          ),
          const SizedBox(height: 24),
          ...List.generate(
            questions.length,
            (index) => _buildLifestyleQuestionCard(
              index + 1,
              questions[index],
            ),
          ),
          _buildMultiSelectQuestion(
            number: 14,
            title: 'What equipment do you have access to?',
            selected: _selectedEquipment,
            options: const [
              'Bodyweight Only',
              'Resistance Bands',
              'Dumbbells',
              'Barbell & Plates',
              'Home Gym',
              'Full Commercial Gym',
            ],
            onToggle: (value) {
              setState(() {
                _selectedEquipment.contains(value)
                    ? _selectedEquipment.remove(value)
                    : _selectedEquipment.add(value);
              });
            },
          ),
          _buildMultiSelectQuestion(
            number: 16,
            title:
                'Do you currently have any injuries or physical limitations?',
            selected: _selectedInjuries,
            options: const [
              'No Injuries',
              'Knee',
              'Ankle / Foot',
              'Hip',
              'Lower Back',
              'Upper Back',
              'Shoulder',
              'Elbow',
              'Wrist / Hand',
              'Neck',
              'Other',
            ],
            onToggle: (value) {
              setState(() {
                if (value == 'No Injuries') {
                  _selectedInjuries
                    ..clear()
                    ..add('none');
                  _lifestyleAnswers
                    ..remove('pain')
                    ..remove('restriction');
                } else {
                  _selectedInjuries.remove('none');
                  _selectedInjuries.contains(value)
                      ? _selectedInjuries.remove(value)
                      : _selectedInjuries.add(value);
                }
              });
            },
          ),
          if (hasInjury) ...[
            _buildLifestyleQuestionCard(
              16,
              const _LifestyleQuestion(
                keyName: 'pain',
                title: 'How would you rate your pain?',
                options: ['Mild', 'Moderate', 'Severe'],
              ),
            ),
            _buildLifestyleQuestionCard(
              16,
              const _LifestyleQuestion(
                keyName: 'restriction',
                title: 'Does your injury affect your workouts?',
                options: [
                  'No Limitations',
                  'Minor Exercise Modifications',
                  'Avoid Certain Exercises',
                  'Need a Fully Modified Program',
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLifestyleQuestionCard(
    int number,
    _LifestyleQuestion question,
  ) {
    final selected =
        _lifestyleAnswers[question.keyName];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. ${question.title}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: question.options.map((option) {
              final isSelected = selected == option;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) {
                  setState(() {
                    _lifestyleAnswers[question.keyName] =
                        option;
                  });
                },
                selectedColor:
                    AppTheme.primaryGreen.withValues(
                  alpha: 0.14,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.border,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiSelectQuestion({
    required int number,
    required String title,
    required Set<String> selected,
    required List<String> options,
    required ValueChanged<String> onToggle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$number. $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select all that apply.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map((option) {
              final key =
                  option == 'No Injuries' ? 'none' : option;
              final isSelected = selected.contains(key);

              return FilterChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) => onToggle(option),
                selectedColor:
                    AppTheme.primaryGreen.withValues(
                  alpha: 0.14,
                ),
                side: BorderSide(
                  color: isSelected
                      ? AppTheme.primaryGreen
                      : AppTheme.border,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionStep() {
    final List<_NutritionQuestion> questions = <_NutritionQuestion>[
      const _NutritionQuestion(
        keyName: 'eating_style',
        title: 'Which best describes your eating style?',
        options: <String>[
          'No Preference',
          'High Protein',
          'Balanced Diet',
          'Low Carb',
          'Keto',
          'Vegetarian',
          'Vegan',
          'Pescatarian',
        ],
      ),
      const _NutritionQuestion(
        keyName: 'meals_per_day',
        title: 'How many meals do you usually eat each day?',
        options: <String>[
          '2 Meals',
          '3 Meals',
          '4 Meals',
          '5+ Meals',
          "I Don't Have a Fixed Schedule",
        ],
      ),
      const _NutritionQuestion(
        keyName: 'cooking_frequency',
        title: 'How often do you cook your own meals?',
        options: <String>[
          'Every Meal',
          'Most Meals',
          'Sometimes',
          'Rarely',
          'Never',
        ],
      ),
      const _NutritionQuestion(
        keyName: 'eating_location',
        title: 'Where do you usually eat?',
        options: <String>[
          'Mostly Home',
          'Mostly Restaurants',
          'Mostly Takeaway',
          'Mixed',
        ],
      ),
      const _NutritionQuestion(
        keyName: 'prep_time',
        title: 'How much time can you spend preparing meals?',
        options: <String>[
          'Less than 15 Minutes',
          '15–30 Minutes',
          '30–60 Minutes',
          'More than 1 Hour',
          "Doesn't Matter",
        ],
      ),
      const _NutritionQuestion(
        keyName: 'nutrition_challenge',
        title: 'What is your biggest nutrition challenge?',
        options: <String>[
          'Cravings',
          'Snacking',
          'Portion Control',
          'Lack of Time',
          'Budget',
          "Don't Know What to Cook",
          'Eating Out Too Often',
          'Sugar',
          'Soft Drinks',
        ],
      ),
      const _NutritionQuestion(
        keyName: 'ai_meal_plans',
        title: 'Would you like AI-generated meal plans and recipes?',
        options: <String>[
          'Yes',
          'No',
        ],
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey<String>('nutrition'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildSectionIntro(
            icon: Icons.restaurant_menu_outlined,
            title: 'Tell us about your nutrition',
            description:
                'Tap the options that best match your eating habits. '
                'MuscleUp will use them to personalize meals and recipes.',
          ),
          const SizedBox(height: 24),

          _buildNutritionQuestionCard(
            number: 1,
            question: questions[0],
          ),
          _buildNutritionQuestionCard(
            number: 2,
            question: questions[1],
          ),

          _buildNutritionMultiSelectQuestion(
            number: 3,
            title: 'Which meals do you usually eat?',
            selected: _selectedMeals,
            options: const <String>[
              'Breakfast',
              'Lunch',
              'Dinner',
              'Morning Snack',
              'Afternoon Snack',
              'Evening Snack',
            ],
            onToggle: (String value) {
              setState(() {
                _selectedMeals.contains(value)
                    ? _selectedMeals.remove(value)
                    : _selectedMeals.add(value);
              });
            },
          ),

          _buildNutritionMultiSelectQuestion(
            number: 4,
            title: 'Do you have any food allergies?',
            selected: _selectedAllergies,
            options: const <String>[
              'None',
              'Dairy',
              'Eggs',
              'Gluten',
              'Peanuts',
              'Tree Nuts',
              'Soy',
              'Fish',
              'Shellfish',
              'Sesame',
              'Other',
            ],
            onToggle: (String value) {
              _toggleExclusiveNoneOption(
                selected: _selectedAllergies,
                value: value,
              );
            },
          ),

          _buildNutritionMultiSelectQuestion(
            number: 5,
            title: 'Are there any foods you avoid?',
            selected: _selectedFoodsToAvoid,
            options: const <String>[
              'None',
              'Beef',
              'Pork',
              'Seafood',
              'Dairy',
              'Gluten',
              'Spicy Foods',
              'Processed Foods',
              'Sugar',
              'Other',
            ],
            onToggle: (String value) {
              _toggleExclusiveNoneOption(
                selected: _selectedFoodsToAvoid,
                value: value,
              );
            },
          ),

          _buildNutritionQuestionCard(
            number: 6,
            question: questions[2],
          ),
          _buildNutritionQuestionCard(
            number: 7,
            question: questions[3],
          ),
          _buildNutritionQuestionCard(
            number: 8,
            question: questions[4],
          ),
          _buildNutritionQuestionCard(
            number: 9,
            question: questions[5],
          ),
          _buildNutritionQuestionCard(
            number: 10,
            question: questions[6],
          ),
        ],
      ),
    );
  }

  void _toggleExclusiveNoneOption({
    required Set<String> selected,
    required String value,
  }) {
    setState(() {
      if (value == 'None') {
        selected
          ..clear()
          ..add('None');
        return;
      }

      selected.remove('None');

      if (selected.contains(value)) {
        selected.remove(value);
      } else {
        selected.add(value);
      }
    });
  }

  Widget _buildNutritionQuestionCard({
    required int number,
    required _NutritionQuestion question,
  }) {
    final String? selected =
        _nutritionAnswers[question.keyName];

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$number. ${question.title}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: question.options.map(
              (String option) {
                final bool isSelected =
                    selected == option;

                return ChoiceChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (bool _) {
                    setState(() {
                      _nutritionAnswers[question.keyName] =
                          option;
                    });
                  },
                  selectedColor:
                      AppTheme.primaryGreen.withValues(
                    alpha: 0.14,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.border,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionMultiSelectQuestion({
    required int number,
    required String title,
    required Set<String> selected,
    required List<String> options,
    required ValueChanged<String> onToggle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$number. $title',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Select all that apply.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: options.map(
              (String option) {
                final bool isSelected =
                    selected.contains(option);

                return FilterChip(
                  label: Text(option),
                  selected: isSelected,
                  onSelected: (bool _) {
                    onToggle(option);
                  },
                  selectedColor:
                      AppTheme.primaryGreen.withValues(
                    alpha: 0.14,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.border,
                  ),
                  labelStyle: TextStyle(
                    color: isSelected
                        ? AppTheme.primaryGreen
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderStep() {
    return Center(
      key: ValueKey<int>(_currentStep),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppTheme.calorieCard,
                borderRadius:
                    BorderRadius.circular(22),
              ),
              alignment: Alignment.center,
              child: Icon(
                _getStepIcon(),
                size: 36,
                color: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _stepTitles[_currentStep],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _getPlaceholderText(),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionIntro({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: AppTheme.calorieCard,
            borderRadius:
                BorderRadius.circular(17),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 28,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFieldLabel({
    required String label,
    required bool required,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          required ? 'Required' : 'Optional',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: required
                ? AppTheme.primaryGreen
                : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hintText,
      suffixText: suffixText,
      filled: true,
      fillColor: AppTheme.background,
      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.border,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.border,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: AppTheme.primaryGreen,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
        ),
      ),
      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Colors.redAccent,
          width: 1.5,
        ),
      ),
    );
  }

  String? _validateAge(String? value) {
    final int? age =
        int.tryParse(value?.trim() ?? '');

    if (age == null) {
      return 'Please enter your age.';
    }

    if (age < 13 || age > 100) {
      return 'Enter an age between 13 and 100.';
    }

    return null;
  }

  String? _validateHeightCm(String? value) {
    final double? height =
        double.tryParse(value?.trim() ?? '');

    if (height == null) {
      return 'Please enter your height.';
    }

    if (height < 100 || height > 250) {
      return 'Enter a height between 100 and 250 cm.';
    }

    return null;
  }

  String? _validateHeightFeet(String? value) {
    final int? feet =
        int.tryParse(value?.trim() ?? '');

    if (feet == null) {
      return 'Required.';
    }

    if (feet < 3 || feet > 8) {
      return 'Use 3–8 ft.';
    }

    return null;
  }

  String? _validateHeightInches(
    String? value,
  ) {
    final int? inches =
        int.tryParse(value?.trim() ?? '');

    if (inches == null) {
      return 'Required.';
    }

    if (inches < 0 || inches > 11) {
      return 'Use 0–11 in.';
    }

    return null;
  }

  String? _validateWeight(String? value) {
    final double? weight =
        double.tryParse(value?.trim() ?? '');

    if (weight == null) {
      return 'Please enter your weight.';
    }

    if (_isMetric) {
      if (weight < 30 || weight > 350) {
        return 'Enter 30–350 kg.';
      }
    } else {
      if (weight < 66 || weight > 772) {
        return 'Enter 66–772 lb.';
      }
    }

    return null;
  }

  String? _validateOptionalWeight(
    String? value,
  ) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return _validateWeight(text);
  }

  IconData _getStepIcon() {
    const List<IconData> icons = [
      Icons.person_outline,
      Icons.flag_outlined,
      Icons.monitor_weight_outlined,
      Icons.directions_walk_outlined,
      Icons.fitness_center_outlined,
      Icons.health_and_safety_outlined,
      Icons.restaurant_menu_outlined,
      Icons.straighten_outlined,
      Icons.photo_camera_outlined,
      Icons.tune_outlined,
      Icons.fact_check_outlined,
      Icons.auto_awesome_outlined,
    ];

    return icons[_currentStep];
  }

  String _getPlaceholderText() {
    if (_isLastStep) {
      return 'You have reached the final step. '
          'Soon this button will save your profile '
          'and prepare your AI Coach.';
    }

    return 'The questions for this section '
        'will be added in the next stage.';
  }
}


class _NutritionQuestion {
  final String keyName;
  final String title;
  final List<String> options;

  const _NutritionQuestion({
    required this.keyName,
    required this.title,
    required this.options,
  });
}

class _LifestyleQuestion {
  final String keyName;
  final String title;
  final List<String> options;

  const _LifestyleQuestion({
    required this.keyName,
    required this.title,
    required this.options,
  });
}

class _BodyTypeOption {
  final String value;
  final String title;
  final String subtitle;
  final String imagePath;

  const _BodyTypeOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.imagePath,
  });
}

class _SelectionCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryGreen.withValues(
                    alpha: 0.1,
                  )
                : AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryGreen
                  : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.primaryGreen
                      : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}