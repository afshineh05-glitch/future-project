
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/dashboard_screen.dart';
import 'package:future_project/theme/app_theme.dart';

class MyFoundationScreen extends StatefulWidget {
  const MyFoundationScreen({super.key});

  @override
  State<MyFoundationScreen> createState() {
    return _MyFoundationScreenState();
  }
}

class _MyFoundationScreenState extends State<MyFoundationScreen> {
  static const int _totalSteps = 8;

  static const List<String> _stepTitles = [
    'About You',
    'Your Goal',
    'Body Details',
    'Lifestyle',
    'Nutrition',
    'Measurements',
    'Body Photos',
    'Finish',
  ];

  static const List<String> _stepDescriptions = [
    'Tell MuscleUp the basics about you.',
    'Choose what you want to achieve.',
    'Add your current body information.',
    'Describe your daily activity and routine.',
    'Describe your eating habits and preferences.',
    'Add your starting body measurements.',
    'Add optional progress photos.',
    'Your foundation is set. MuscleUp now has what it needs to personalize your journey.',
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

  final TextEditingController _waistController =
      TextEditingController();

  final TextEditingController _chestController =
      TextEditingController();

  final TextEditingController _hipsController =
      TextEditingController();

  final TextEditingController _armsController =
      TextEditingController();

  final TextEditingController _thighsController =
      TextEditingController();

  final TextEditingController _neckController =
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

  final ImagePicker _bodyPhotoPicker = ImagePicker();

  Uint8List? _frontBodyPhoto;
  Uint8List? _sideBodyPhoto;
  Uint8List? _backBodyPhoto;

  bool _isPreparingBodyPhotoBaseline = false;
  bool _bodyPhotoBaselineReady = false;
  bool _isSavingFoundation = false;
  bool _isLoadingFoundation = true;
  bool _viewingSavedFoundation = false;

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
  void initState() {
    super.initState();
    _loadSavedFoundation();
  }

  Future<void> _loadSavedFoundation() async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoadingFoundation = false;
        });
      }
      return;
    }

    try {
      final Map<String, dynamic>? row = await supabase
          .from('user_foundations')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) {
        return;
      }

      if (row == null) {
        setState(() {
          _isLoadingFoundation = false;
        });
        return;
      }

      _hydrateFoundationFromDatabase(row);

      final bool completed = row['is_completed'] == true;

      setState(() {
        _isLoadingFoundation = false;
        _viewingSavedFoundation = completed;
        if (completed) {
          _currentStep = _totalSteps - 1;
        }
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingFoundation = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not load your saved Foundation: $error',
          ),
        ),
      );
    }
  }

  void _hydrateFoundationFromDatabase(
    Map<String, dynamic> row,
  ) {
    _measurementSystem =
        (row['measurement_system'] as String?) ?? 'metric';

    _selectedSex = row['sex'] as String?;
    _selectedGoal = row['primary_goal'] as String?;
    _selectedBodyType = row['body_type'] as String?;

    _ageController.text = _databaseNumberText(row['age']);

    final double? heightCm = _asDouble(row['height_cm']);
    final double? weightKg = _asDouble(row['weight_kg']);
    final double? targetWeightKg =
        _asDouble(row['target_weight_kg']);

    if (_measurementSystem == 'imperial') {
      if (heightCm != null) {
        final double totalInches = heightCm / 2.54;
        final int feet = totalInches ~/ 12;
        final int inches = (totalInches - (feet * 12)).round();
        _heightFeetController.text = '$feet';
        _heightInchesController.text = '$inches';
      }

      if (weightKg != null) {
        _weightController.text =
            _trimDatabaseNumber(weightKg / 0.45359237);
      }

      if (targetWeightKg != null) {
        _targetWeightController.text =
            _trimDatabaseNumber(targetWeightKg / 0.45359237);
      }
    } else {
      if (heightCm != null) {
        _heightCmController.text =
            _trimDatabaseNumber(heightCm);
      }

      if (weightKg != null) {
        _weightController.text =
            _trimDatabaseNumber(weightKg);
      }

      if (targetWeightKg != null) {
        _targetWeightController.text =
            _trimDatabaseNumber(targetWeightKg);
      }
    }

    _loadMeasurementController(
      _waistController,
      row['waist_cm'],
    );
    _loadMeasurementController(
      _chestController,
      row['chest_cm'],
    );
    _loadMeasurementController(
      _hipsController,
      row['hips_cm'],
    );
    _loadMeasurementController(
      _armsController,
      row['arm_cm'],
    );
    _loadMeasurementController(
      _thighsController,
      row['thigh_cm'],
    );
    _loadMeasurementController(
      _neckController,
      row['neck_cm'],
    );

    final Map<String, dynamic> lifestyle =
        _dynamicMap(row['lifestyle']);
    _lifestyleAnswers
      ..clear()
      ..addAll(
        lifestyle.map(
          (key, value) => MapEntry(
            key,
            value?.toString() ?? '',
          ),
        )..removeWhere((key, value) => value.isEmpty),
      );

    final Map<String, dynamic> nutrition =
        _dynamicMap(row['nutrition']);
    _nutritionAnswers
      ..clear()
      ..addAll(
        nutrition.map(
          (key, value) => MapEntry(
            key,
            value?.toString() ?? '',
          ),
        )..removeWhere((key, value) => value.isEmpty),
      );

    _replaceStringSet(
      _selectedEquipment,
      row['equipment'],
    );
    _replaceStringSet(
      _selectedAllergies,
      row['allergies'],
    );
    _replaceStringSet(
      _selectedMeals,
      row['meals'],
    );
    _replaceStringSet(
      _selectedFoodsToAvoid,
      row['foods_to_avoid'],
    );

    final dynamic lifestyleInjuries = lifestyle['injuries'];
    if (lifestyleInjuries is List) {
      _replaceStringSet(
        _selectedInjuries,
        lifestyleInjuries,
      );
    } else {
      final String? injuries = row['injuries'] as String?;
      _selectedInjuries.clear();

      if (injuries == 'No Injuries') {
        _selectedInjuries.add('none');
      } else if (injuries != null &&
          injuries.isNotEmpty &&
          injuries != 'Not set') {
        _selectedInjuries.addAll(
          injuries.split(' · '),
        );
      }
    }

    _bodyPhotoBaselineReady =
        row['body_photo_baseline_ready'] == true;
  }

  Map<String, dynamic> _dynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, item) => MapEntry(
          key.toString(),
          item,
        ),
      );
    }

    return <String, dynamic>{};
  }

  void _replaceStringSet(
    Set<String> target,
    dynamic value,
  ) {
    target.clear();

    if (value is List) {
      target.addAll(
        value
            .where((item) => item != null)
            .map((item) => item.toString()),
      );
    }
  }

  double? _asDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString() ?? '');
  }

  String _databaseNumberText(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return _trimDatabaseNumber(value.toDouble());
    }

    return value.toString();
  }

  String _trimDatabaseNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }

    return value.toStringAsFixed(1);
  }

  void _loadMeasurementController(
    TextEditingController controller,
    dynamic databaseValue,
  ) {
    final double? cm = _asDouble(databaseValue);

    if (cm == null) {
      controller.clear();
      return;
    }

    final double displayValue =
        _measurementSystem == 'imperial'
            ? cm / 2.54
            : cm;

    controller.text =
        _trimDatabaseNumber(displayValue);
  }

  void _editSavedFoundation() {
    setState(() {
      _viewingSavedFoundation = false;
      _currentStep = 0;
    });
  }

  void _returnToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const DashboardScreen(),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightCmController.dispose();
    _heightFeetController.dispose();
    _heightInchesController.dispose();
    _weightController.dispose();
    _targetWeightController.dispose();
    _waistController.dispose();
    _chestController.dispose();
    _hipsController.dispose();
    _armsController.dispose();
    _thighsController.dispose();
    _neckController.dispose();

    super.dispose();
  }

  Future<void> _goNext() async {
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

    if (_currentStep == 5 && !_validateBodyMeasurementsStep()) {
      return;
    }

    if (_isLastStep) {
      await _completeFoundation();
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
    const requiredQuestions = <String, String>{
      'activity': 'Question 1: How active are you during a typical day?',
      'occupation': 'Question 2: What best describes your occupation?',
      'exercise_days': 'Question 3: How many days per week do you exercise?',
      'workout_duration': 'Question 4: How long is your average workout?',
      'workout_intensity': 'Question 5: How would you describe your workout intensity?',
      'sleep_hours': 'Question 6: How many hours do you usually sleep?',
      'sleep_quality': 'Question 7: How would you rate your sleep quality?',
      'water': 'Question 8: How much water do you drink each day?',
      'stress': 'Question 9: How stressful is your daily life?',
      'steps': 'Question 10: How many steps do you usually walk each day?',
      'workout_time': 'Question 11: When do you usually prefer to work out?',
      'motivation': 'Question 12: What motivates you the most?',
      'gym_access': 'Question 13: Where do you usually work out?',
      'experience': 'Question 14: What is your training experience?',
      'obstacle': 'Question 15: What is your biggest obstacle to staying consistent?',
    };

    for (final entry in requiredQuestions.entries) {
      if (!_lifestyleAnswers.containsKey(entry.key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please answer ${entry.value}',
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
            'Please answer Question 16: What equipment do you have access to?',
          ),
        ),
      );
      return false;
    }

    if (_selectedInjuries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer Question 17: Do you currently have any injuries or physical limitations?',
          ),
        ),
      );
      return false;
    }

    final bool hasInjury =
        !_selectedInjuries.contains('none');

    if (hasInjury &&
        !_lifestyleAnswers.containsKey('pain')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Question 17A: How would you rate your pain?',
          ),
        ),
      );
      return false;
    }

    if (hasInjury &&
        !_lifestyleAnswers.containsKey('restriction')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please complete Question 17B: Does your injury affect your workouts?',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  bool _validateNutritionStep() {
    const requiredQuestions = <String, String>{
      'eating_style': 'Question 1: Which best describes your eating style?',
      'meals_per_day': 'Question 2: How many meals do you usually eat each day?',
      'cooking_frequency': 'Question 6: How often do you cook your own meals?',
      'eating_location': 'Question 7: Where do you usually eat?',
      'prep_time': 'Question 8: How much time can you spend preparing meals?',
      'nutrition_challenge': 'Question 9: What is your biggest nutrition challenge?',
      'ai_meal_plans': 'Question 10: Would you like AI-generated meal plans and recipes?',
    };

    for (final entry in requiredQuestions.entries) {
      if (!_nutritionAnswers.containsKey(entry.key)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please answer ${entry.value}',
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
            'Please answer Question 3: Which meals do you usually eat?',
          ),
        ),
      );
      return false;
    }

    if (_selectedAllergies.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer Question 4: Do you have any food allergies?',
          ),
        ),
      );
      return false;
    }

    if (_selectedFoodsToAvoid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please answer Question 5: Are there any foods you avoid?',
          ),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> _completeFoundation() async {
    if (_isSavingFoundation) {
      return;
    }

    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in before saving your Foundation.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSavingFoundation = true;
    });

    try {
      final DateTime now = DateTime.now().toUtc();

      final Map<String, dynamic> foundationData = <String, dynamic>{
        'user_id': user.id,
        'measurement_system': _measurementSystem,
        'current_section': _totalSteps,
        'completion_percent': 100,
        'is_completed': true,

        'age': int.tryParse(_ageController.text.trim()),
        'sex': _selectedSex,
        'height_cm': _heightCmForDatabase(),
        'weight_kg': _weightKgForDatabase(
          _weightController.text,
        ),
        'target_weight_kg': _weightKgForDatabase(
          _targetWeightController.text,
        ),

        'primary_goal': _selectedGoal,
        'body_type': _selectedBodyType,

        'training_level': _lifestyleAnswers['experience'],
        'training_days_per_week': _trainingDaysForDatabase(),
        'session_duration_minutes': _sessionDurationForDatabase(),
        'training_location': _lifestyleAnswers['gym_access'],
        'equipment': _selectedEquipment.toList(),
        'preferred_training_time': _lifestyleAnswers['workout_time'],

        'injuries': _foundationInjurySummary(),
        'pain_notes': _lifestyleAnswers['pain'],
        'exercises_to_avoid': <String>[],

        'job_activity_level': _lifestyleAnswers['activity'],
        'sleep_quality': _lifestyleAnswers['sleep_quality'],

        'diet_preference': _nutritionAnswers['eating_style'],
        'allergies': _selectedAllergies.toList(),
        'disliked_foods': _selectedFoodsToAvoid.toList(),
        'meals': _selectedMeals.toList(),
        'foods_to_avoid': _selectedFoodsToAvoid.toList(),
        'meals_per_day': _mealsPerDayForDatabase(),
        'cooking_level': _nutritionAnswers['cooking_frequency'],

        'lifestyle': <String, dynamic>{
          ..._lifestyleAnswers,
          'equipment': _selectedEquipment.toList(),
          'injuries': _selectedInjuries.toList(),
        },
        'nutrition': <String, dynamic>{
          ..._nutritionAnswers,
          'meals': _selectedMeals.toList(),
          'allergies': _selectedAllergies.toList(),
          'foods_to_avoid': _selectedFoodsToAvoid.toList(),
        },

        'waist_cm': _measurementCmForDatabase(_waistController),
        'chest_cm': _measurementCmForDatabase(_chestController),
        'hips_cm': _measurementCmForDatabase(_hipsController),
        'arm_cm': _measurementCmForDatabase(_armsController),
        'thigh_cm': _measurementCmForDatabase(_thighsController),
        'neck_cm': _measurementCmForDatabase(_neckController),

        // Photo URLs stay null until Storage upload is connected.
        'body_photo_baseline_ready': false,
        'completed_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      await supabase
          .from('user_foundations')
          .upsert(
            foundationData,
            onConflict: 'user_id',
          );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your Foundation was saved successfully.',
          ),
        ),
      );

      _returnToDashboard();
    } on PostgrestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save Foundation: ${error.message}',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not save your Foundation. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingFoundation = false;
        });
      }
    }
  }

  double? _heightCmForDatabase() {
    if (_isMetric) {
      return double.tryParse(
        _heightCmController.text.trim(),
      );
    }

    final double? feet = double.tryParse(
      _heightFeetController.text.trim(),
    );
    final double? inches = double.tryParse(
      _heightInchesController.text.trim(),
    );

    if (feet == null && inches == null) {
      return null;
    }

    final double totalInches =
        (feet ?? 0) * 12 + (inches ?? 0);

    return totalInches * 2.54;
  }

  double? _weightKgForDatabase(String value) {
    final double? parsed = double.tryParse(value.trim());

    if (parsed == null) {
      return null;
    }

    if (_isMetric) {
      return parsed;
    }

    return parsed * 0.45359237;
  }

  double? _measurementCmForDatabase(
    TextEditingController controller,
  ) {
    final double? parsed = double.tryParse(
      controller.text.trim(),
    );

    if (parsed == null) {
      return null;
    }

    if (_isMetric) {
      return parsed;
    }

    return parsed * 2.54;
  }

  int? _trainingDaysForDatabase() {
    switch (_lifestyleAnswers['exercise_days']) {
      case 'Never':
        return 0;
      case '1–2 Days':
        return 2;
      case '3–4 Days':
        return 4;
      case '5–6 Days':
        return 6;
      case 'Every Day':
        return 7;
      default:
        return null;
    }
  }

  int? _sessionDurationForDatabase() {
    switch (_lifestyleAnswers['workout_duration']) {
      case 'Less than 30 Minutes':
        return 20;
      case '30–45 Minutes':
        return 38;
      case '45–60 Minutes':
        return 53;
      case '60–90 Minutes':
        return 75;
      case 'More than 90 Minutes':
        return 100;
      default:
        return null;
    }
  }

  int? _mealsPerDayForDatabase() {
    switch (_nutritionAnswers['meals_per_day']) {
      case '2 Meals':
        return 2;
      case '3 Meals':
        return 3;
      case '4 Meals':
        return 4;
      case '5+ Meals':
        return 5;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFoundation) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
    if (_viewingSavedFoundation) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _returnToDashboard,
              icon: const Icon(
                Icons.dashboard_outlined,
              ),
              label: const Text(
                'Dashboard',
              ),
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
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _editSavedFoundation,
              icon: const Icon(
                Icons.edit_outlined,
              ),
              label: const Text(
                'Edit Foundation',
              ),
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
            ),
          ),
        ],
      );
    }

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
            onPressed: _isSavingFoundation ? null : _goNext,
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
            icon: _isSavingFoundation && _isLastStep
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : Icon(
                    _isLastStep
                        ? Icons.check_circle_outline
                        : Icons.arrow_forward,
                  ),
            label: Text(
              _isSavingFoundation && _isLastStep
                  ? 'Saving...'
                  : _isLastStep
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

    if (_currentStep == 5) {
      return _buildBodyMeasurementsStep();
    }

    if (_currentStep == 6) {
      return _buildBodyPhotosStep();
    }

    if (_currentStep == 7) {
      return _buildFinishStep();
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
            number: 16,
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
            number: 17,
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
              17,
              const _LifestyleQuestion(
                keyName: 'pain',
                title: 'How would you rate your pain?',
                options: ['Mild', 'Moderate', 'Severe'],
              ),
            ),
            _buildLifestyleQuestionCard(
              17,
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

  Widget _buildBodyMeasurementsStep() {
    final String unit = _isMetric ? 'cm' : 'in';

    return SingleChildScrollView(
      key: const ValueKey<String>('body-measurements'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            icon: Icons.straighten_outlined,
            title: 'Starting body measurements',
            description:
                'Enter all measurements below to create your starting baseline '
                'for future progress comparisons.',
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.calorieCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For accurate progress tracking, take your measurements '
                    'under similar conditions each time. Ideally, measure '
                    'in the morning, before eating and before training.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          _buildBodyMeasurementField(
            label: 'Waist',
            controller: _waistController,
            unit: unit,
            hint: _isMetric ? 'e.g. 86' : 'e.g. 34',
          ),
          _buildBodyMeasurementField(
            label: 'Chest',
            controller: _chestController,
            unit: unit,
            hint: _isMetric ? 'e.g. 102' : 'e.g. 40',
          ),
          _buildBodyMeasurementField(
            label: 'Hips',
            controller: _hipsController,
            unit: unit,
            hint: _isMetric ? 'e.g. 98' : 'e.g. 38.5',
          ),
          _buildBodyMeasurementField(
            label: 'Arms',
            controller: _armsController,
            unit: unit,
            hint: _isMetric ? 'e.g. 36' : 'e.g. 14',
          ),
          _buildBodyMeasurementField(
            label: 'Thighs',
            controller: _thighsController,
            unit: unit,
            hint: _isMetric ? 'e.g. 58' : 'e.g. 23',
          ),
          _buildBodyMeasurementField(
            label: 'Neck',
            controller: _neckController,
            unit: unit,
            hint: _isMetric ? 'e.g. 39' : 'e.g. 15.5',
          ),

          const SizedBox(height: 4),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Text(
              'These values will become your starting baseline. '
              'Future body check-ins can be compared with this first set.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyMeasurementField({
    required String label,
    required TextEditingController controller,
    required String unit,
    required String hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildFieldLabel(
            label: label,
            required: true,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                RegExp(r'^\d*\.?\d{0,1}'),
              ),
            ],
            decoration: _inputDecoration(
              hintText: hint,
              suffixText: unit,
            ),
            validator: _validateRequiredMeasurement,
          ),
        ],
      ),
    );
  }

  String? _validateRequiredMeasurement(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Required.';
    }

    final double? measurement = double.tryParse(text);

    if (measurement == null || measurement <= 0) {
      return 'Enter a valid measurement.';
    }

    if (_isMetric && measurement > 300) {
      return 'Please check this value.';
    }

    if (!_isMetric && measurement > 120) {
      return 'Please check this value.';
    }

    return null;
  }

  bool _validateBodyMeasurementsStep() {
    final List<TextEditingController> controllers = <TextEditingController>[
      _waistController,
      _chestController,
      _hipsController,
      _armsController,
      _thighsController,
      _neckController,
    ];

    for (final TextEditingController controller in controllers) {
      final String? error = _validateRequiredMeasurement(controller.text);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please complete all body measurements before continuing.',
            ),
          ),
        );
        return false;
      }
    }

    return true;
  }

  bool get _canUseBodyPhotoCamera {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  void _showBodyPhotoError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Future<void> _showBodyPhotoSourceSheet(
    String view,
  ) async {
    final ImageSource? source =
        await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Add $view Photo',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (_canUseBodyPhotoCamera)
                  ListTile(
                    leading: const Icon(
                      Icons.photo_camera_outlined,
                    ),
                    title: const Text('Camera'),
                    onTap: () {
                      Navigator.of(context).pop(
                        ImageSource.camera,
                      );
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text('Photo Library'),
                  onTap: () {
                    Navigator.of(context).pop(
                      ImageSource.gallery,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) {
      return;
    }

    await _pickBodyPhoto(
      view: view,
      source: source,
    );
  }

  Future<void> _pickBodyPhoto({
    required String view,
    required ImageSource source,
  }) async {
    try {
      final XFile? picked = await _bodyPhotoPicker.pickImage(
        source: source,
        imageQuality: 88,
        maxWidth: 1800,
      );

      if (picked == null) {
        return;
      }

      final Uint8List bytes = await picked.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        switch (view) {
          case 'Front':
            _frontBodyPhoto = bytes;
          case 'Side':
            _sideBodyPhoto = bytes;
          case 'Back':
            _backBodyPhoto = bytes;
        }

        _bodyPhotoBaselineReady = false;
      });
    } on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      _showBodyPhotoError(
        'Could not access photos: ${error.message ?? error.code}',
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showBodyPhotoError(
        'Could not add this photo. Please try again.',
      );
    }
  }

  Future<void> _prepareBodyPhotoBaseline() async {
    if (_frontBodyPhoto == null ||
        _sideBodyPhoto == null ||
        _backBodyPhoto == null) {
      _showBodyPhotoError(
        'Add Front, Side, and Back photos first.',
      );
      return;
    }

    setState(() {
      _isPreparingBodyPhotoBaseline = true;
      _bodyPhotoBaselineReady = false;
    });

    // This creates the secure baseline state in the onboarding UI.
    // The actual OpenAI/Vision request should be made from the app's
    // authenticated backend/service layer, not directly from this screen.
    await Future<void>.delayed(
      const Duration(milliseconds: 700),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isPreparingBodyPhotoBaseline = false;
      _bodyPhotoBaselineReady = true;
    });
  }

  Widget _buildBodyPhotosStep() {
    final bool allPhotosAdded =
        _frontBodyPhoto != null &&
        _sideBodyPhoto != null &&
        _backBodyPhoto != null;

    return SingleChildScrollView(
      key: const ValueKey<String>('body-photos'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionIntro(
            icon: Icons.photo_camera_outlined,
            title: 'Starting body photos',
            description:
                'Body photos are optional, but adding them gives MuscleUp '
                'a better baseline to track your progress and provide more '
                'useful progress insights over time.',
          ),
          const SizedBox(height: 20),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.calorieCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'For the most consistent progress photos, use similar '
                    'lighting, distance, camera angle, and pose each time.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          _buildBodyPhotoCard(
            title: 'Front',
            subtitle: 'Front view',
            icon: Icons.accessibility_new_outlined,
            bytes: _frontBodyPhoto,
          ),
          _buildBodyPhotoCard(
            title: 'Side',
            subtitle: 'Side view',
            icon: Icons.person_outline,
            bytes: _sideBodyPhoto,
          ),
          _buildBodyPhotoCard(
            title: 'Back',
            subtitle: 'Back view',
            icon: Icons.accessibility_new_outlined,
            bytes: _backBodyPhoto,
          ),

          const SizedBox(height: 4),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: _bodyPhotoBaselineReady
                    ? AppTheme.primaryGreen
                    : AppTheme.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _bodyPhotoBaselineReady
                          ? Icons.check_circle_outline
                          : Icons.auto_awesome_outlined,
                      color: AppTheme.primaryGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _bodyPhotoBaselineReady
                            ? 'AI baseline ready'
                            : 'Prepare AI comparison baseline',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _bodyPhotoBaselineReady
                      ? 'Your starting photo baseline is ready for future '
                          'five-week comparisons.'
                      : 'Once all three photos are added, prepare your '
                          'starting baseline for future AI-assisted comparisons.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: !allPhotosAdded ||
                            _isPreparingBodyPhotoBaseline
                        ? null
                        : _prepareBodyPhotoBaseline,
                    icon: _isPreparingBodyPhotoBaseline
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.auto_awesome_outlined,
                          ),
                    label: Text(
                      _isPreparingBodyPhotoBaseline
                          ? 'Preparing...'
                          : _bodyPhotoBaselineReady
                              ? 'Baseline Ready'
                              : 'Prepare Baseline',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

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
                  Icons.lock_outline,
                  size: 20,
                  color: AppTheme.primaryGreen,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Body photos are private. They should only be stored '
                    'and processed through your authenticated app storage '
                    'and secure backend.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppTheme.textSecondary,
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

  Widget _buildBodyPhotoCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Uint8List? bytes,
  }) {
    final bool hasPhoto = bytes != null;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPhoto
              ? AppTheme.primaryGreen
              : AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 86,
              height: 110,
              child: hasPhoto
                  ? Image.memory(
                      bytes,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: AppTheme.calorieCard,
                      alignment: Alignment.center,
                      child: Icon(
                        icon,
                        size: 38,
                        color: AppTheme.primaryGreen,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    _showBodyPhotoSourceSheet(title);
                  },
                  icon: Icon(
                    hasPhoto
                        ? Icons.refresh
                        : Icons.add_a_photo_outlined,
                    size: 18,
                  ),
                  label: Text(
                    hasPhoto ? 'Replace Photo' : 'Add Photo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishStep() {
    final String height = _foundationHeightSummary();
    final String currentWeight =
        '${_weightController.text.trim()} ${_isMetric ? 'kg' : 'lb'}';
    final String targetWeight =
        _targetWeightController.text.trim().isEmpty
            ? 'Not set'
            : '${_targetWeightController.text.trim()} ${_isMetric ? 'kg' : 'lb'}';

    final String photoSummary =
        _frontBodyPhoto != null ||
                _sideBodyPhoto != null ||
                _backBodyPhoto != null
            ? [
                if (_frontBodyPhoto != null) 'Front',
                if (_sideBodyPhoto != null) 'Side',
                if (_backBodyPhoto != null) 'Back',
              ].join(' · ')
            : 'Skipped';

    return SingleChildScrollView(
      key: const ValueKey<String>('finish'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: AppTheme.calorieCard,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 38,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'You’re All Set',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Here’s a summary of the foundation you created.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _buildFoundationSummaryCard(
            icon: Icons.person_outline,
            title: 'About You',
            rows: [
              ('Age', '${_ageController.text.trim()} years'),
              ('Sex', _formatFoundationValue(_selectedSex)),
              ('Height', height),
              ('Current Weight', currentWeight),
              ('Target Weight', targetWeight),
            ],
          ),

          _buildFoundationSummaryCard(
            icon: Icons.flag_outlined,
            title: 'Goal & Body',
            rows: [
              ('Primary Goal', _formatFoundationValue(_selectedGoal)),
              ('Body Type', _formatFoundationValue(_selectedBodyType)),
            ],
          ),

          _buildFoundationSummaryCard(
            icon: Icons.directions_walk_outlined,
            title: 'Lifestyle',
            rows: [
              (
                'Activity',
                _foundationAnswer(_lifestyleAnswers, 'activity'),
              ),
              (
                'Training Experience',
                _foundationAnswer(_lifestyleAnswers, 'experience'),
              ),
              (
                'Gym Access',
                _foundationAnswer(_lifestyleAnswers, 'gym_access'),
              ),
              (
                'Equipment',
                _selectedEquipment.isEmpty
                    ? 'Not set'
                    : _selectedEquipment.join(' · '),
              ),
              (
                'Injuries',
                _foundationInjurySummary(),
              ),
              (
                'Main Obstacle',
                _foundationAnswer(_lifestyleAnswers, 'obstacle'),
              ),
            ],
          ),

          _buildFoundationSummaryCard(
            icon: Icons.restaurant_menu_outlined,
            title: 'Nutrition',
            rows: [
              (
                'Eating Style',
                _foundationAnswer(_nutritionAnswers, 'eating_style'),
              ),
              (
                'Meals per Day',
                _foundationAnswer(_nutritionAnswers, 'meals_per_day'),
              ),
              (
                'Meals',
                _selectedMeals.isEmpty
                    ? 'Not set'
                    : _selectedMeals.join(' · '),
              ),
              (
                'Allergies',
                _selectedAllergies.isEmpty
                    ? 'Not set'
                    : _selectedAllergies.join(' · '),
              ),
              (
                'Foods Avoided',
                _selectedFoodsToAvoid.isEmpty
                    ? 'Not set'
                    : _selectedFoodsToAvoid.join(' · '),
              ),
              (
                'Meal Plans & Recipes',
                _foundationAnswer(_nutritionAnswers, 'ai_meal_plans'),
              ),
            ],
          ),

          _buildFoundationSummaryCard(
            icon: Icons.straighten_outlined,
            title: 'Body Measurements',
            rows: [
              ('Waist', _measurementSummary(_waistController)),
              ('Chest', _measurementSummary(_chestController)),
              ('Hips', _measurementSummary(_hipsController)),
              ('Arms', _measurementSummary(_armsController)),
              ('Thighs', _measurementSummary(_thighsController)),
              ('Neck', _measurementSummary(_neckController)),
            ],
          ),

          _buildFoundationSummaryCard(
            icon: Icons.photo_camera_outlined,
            title: 'Body Photos',
            rows: [
              ('Photos Added', photoSummary),
              (
                'AI Baseline',
                _bodyPhotoBaselineReady
                    ? 'Ready'
                    : photoSummary == 'Skipped'
                        ? 'Not created'
                        : 'Not prepared yet',
              ),
            ],
          ),

          const SizedBox(height: 4),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.calorieCard,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: AppTheme.primaryGreen,
                  size: 22,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'MuscleUp can use this foundation to personalize your '
                    'training, nutrition, and future progress check-ins.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppTheme.textSecondary,
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

  Widget _buildFoundationSummaryCard({
    required IconData icon,
    required String title,
    required List<(String, String)> rows,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 145,
                    child: Text(
                      row.$1,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _foundationAnswer(
    Map<String, String> source,
    String key,
  ) {
    return source[key] ?? 'Not set';
  }

  String _formatFoundationValue(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Not set';
    }

    return value
        .split('_')
        .map(
          (part) => part.isEmpty
              ? part
              : '${part[0].toUpperCase()}${part.substring(1)}',
        )
        .join(' ');
  }

  String _foundationHeightSummary() {
    if (_isMetric) {
      final String value = _heightCmController.text.trim();
      return value.isEmpty ? 'Not set' : '$value cm';
    }

    final String feet = _heightFeetController.text.trim();
    final String inches = _heightInchesController.text.trim();

    if (feet.isEmpty && inches.isEmpty) {
      return 'Not set';
    }

    return '${feet.isEmpty ? '0' : feet} ft '
        '${inches.isEmpty ? '0' : inches} in';
  }

  String _measurementSummary(
    TextEditingController controller,
  ) {
    final String value = controller.text.trim();

    if (value.isEmpty) {
      return 'Not set';
    }

    return '$value ${_isMetric ? 'cm' : 'in'}';
  }

  String _foundationInjurySummary() {
    if (_selectedInjuries.isEmpty) {
      return 'Not set';
    }

    if (_selectedInjuries.contains('none')) {
      return 'No Injuries';
    }

    return _selectedInjuries.join(' · ');
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