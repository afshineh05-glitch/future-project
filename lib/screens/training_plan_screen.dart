import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/exercise_video_player.dart';

class TrainingPlanScreen extends StatefulWidget {
  const TrainingPlanScreen({super.key});

  @override
  State<TrainingPlanScreen> createState() => _TrainingPlanScreenState();
}

class _TrainingPlanScreenState extends State<TrainingPlanScreen> {
  bool loading = true;
  bool _isAdjusting = false;
  String? error;
  Map<String, dynamic>? plan;
  List<Map<String, dynamic>> days = [];
  int selectedDayIndex = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = Supabase.instance.client;
    final user = s.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Please sign in first.';
      });
      return;
    }

    try {
      final p = await s
          .from('training_plans')
          .select(
            'id, goal, experience_level, cycle_start, cycle_end, cycle_weeks, status',
          )
          .eq('user_id', user.id)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (p == null) {
        if (!mounted) return;
        setState(() {
          plan = null;
          days = [];
          loading = false;
          selectedDayIndex = 0;
        });
        return;
      }

      final raw = await s
          .from('training_days')
          .select(
            'id, day_number, title, focus, '
            'training_exercises('
            'id, exercise_name, sets, reps, suggested_weight, weight_unit, '
            'rest_seconds, exercise_order, video_url, '
            'primary_muscles, secondary_muscles'
            ')',
          )
          .eq('plan_id', p['id'])
          .order('day_number');

      final loaded = (raw as List).map((e) {
        final d = Map<String, dynamic>.from(e as Map);

        final ex = ((d['training_exercises'] as List?) ?? [])
            .map((x) => Map<String, dynamic>.from(x as Map))
            .toList()
          ..sort(
            (a, b) =>
                ((a['exercise_order'] as num?)?.toInt() ?? 0).compareTo(
              (b['exercise_order'] as num?)?.toInt() ?? 0,
            ),
          );

        d['training_exercises'] = ex;
        return d;
      }).toList()
        ..sort(
          (a, b) =>
              ((a['day_number'] as num?)?.toInt() ?? 0).compareTo(
            (b['day_number'] as num?)?.toInt() ?? 0,
          ),
        );

      if (!mounted) return;
      setState(() {
        plan = Map<String, dynamic>.from(p);
        days = loaded;
        loading = false;
        error = null;

        if (selectedDayIndex >= loaded.length) {
          selectedDayIndex = 0;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'Could not load Training Plan: $e';
      });
    }
  }


  Future<void> _showAdjustPlanSheet() async {
    if (_isAdjusting || plan == null) return;

    final Map<String, dynamic>? request =
        await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: AppTheme.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext sheetContext) {
        return _AdjustPlanSheet(days: days);
      },
    );

    if (!mounted || request == null) return;

    setState(() {
      _isAdjusting = true;
      error = null;
    });

    try {
      final FunctionResponse response =
          await Supabase.instance.client.functions.invoke(
        'generate-training-plan',
        body: <String, dynamic>{
          'mode': 'adjust',
          'reason_code': request['reason_code'],
          'reason_label': request['reason_label'],
          'day_number': request['day_number'],
          'exercise_name': request['exercise_name'],
          'user_note': request['user_note'],
          'new_session_minutes': request['new_session_minutes'],
        },
      );

      if (response.status < 200 || response.status >= 300) {
        throw Exception(
          'Adjustment returned ${response.status}: ${response.data}',
        );
      }

      selectedDayIndex = 0;
      await _load();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your adjusted Training Plan is ready.'),
        ),
      );
    } on FunctionException catch (e) {
      if (!mounted) return;
      setState(() {
        error =
            'Could not adjust Training Plan: '
            '${e.details ?? e.reasonPhrase ?? e.status}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Could not adjust Training Plan: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAdjusting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Training Plan',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppTheme.primaryGreen,
            ),
          ),
        ],
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
      floatingActionButton:
          plan == null || loading || error != null
              ? null
              : FloatingActionButton.extended(
                  onPressed:
                      _isAdjusting ? null : _showAdjustPlanSheet,
                  backgroundColor: AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: _isAdjusting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.tune_rounded),
                  label: Text(
                    _isAdjusting
                        ? 'Adjusting...'
                        : 'Adjust My Plan',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          children: [
            if (loading)
              const Padding(
                padding: EdgeInsets.only(top: 140),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (error != null)
              _Info(
                title: 'Could not load Training Plan',
                text: error!,
              )
            else if (plan == null)
              const _Info(
                title: 'No active Training Plan yet',
                text:
                    'Your personalized training cycle will appear here once it is generated.',
              )
            else ...[
              _PlanSummary(plan: plan!),
              const SizedBox(height: 18),
              if (days.isNotEmpty) ...[
                _DaySelector(
                  days: days,
                  selectedIndex: selectedDayIndex,
                  onSelected: (index) {
                    setState(() => selectedDayIndex = index);
                  },
                ),
                const SizedBox(height: 16),
                _TrainingDayCard(
                  day: days[selectedDayIndex],
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _AdjustPlanSheet extends StatefulWidget {
  final List<Map<String, dynamic>> days;

  const _AdjustPlanSheet({
    required this.days,
  });

  @override
  State<_AdjustPlanSheet> createState() =>
      _AdjustPlanSheetState();
}

class _AdjustPlanSheetState extends State<_AdjustPlanSheet> {
  static const List<Map<String, String>> _reasons =
      <Map<String, String>>[
    <String, String>{
      'code': 'too_difficult',
      'label': 'The plan is too difficult',
    },
    <String, String>{
      'code': 'too_easy',
      'label': 'The plan is too easy',
    },
    <String, String>{
      'code': 'dislike_exercise',
      'label': "I don't like some exercises",
    },
    <String, String>{
      'code': 'missing_equipment',
      'label': "I don't have the required equipment",
    },
    <String, String>{
      'code': 'time_changed',
      'label': 'My available training time changed',
    },
    <String, String>{
      'code': 'physical_limitation',
      'label': 'I have new pain or a physical limitation',
    },
    <String, String>{
      'code': 'other',
      'label': 'Other',
    },
  ];

  String? _selectedReasonCode;
  String? _selectedReasonLabel;

  int? _selectedDayNumber;
  String? _selectedExerciseName;

  final TextEditingController _noteController =
      TextEditingController();

  final TextEditingController _minutesController =
      TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _exerciseTargets {
    final List<Map<String, dynamic>> targets =
        <Map<String, dynamic>>[];

    for (final Map<String, dynamic> day in widget.days) {
      final int dayNumber =
          (day['day_number'] as num?)?.toInt() ?? 0;

      final List<Map<String, dynamic>> exercises =
          (day['training_exercises']
                      as List<Map<String, dynamic>>?) ??
              <Map<String, dynamic>>[];

      for (final Map<String, dynamic> exercise in exercises) {
        final String name =
            exercise['exercise_name']?.toString() ??
                'Exercise';

        targets.add(
          <String, dynamic>{
            'day_number': dayNumber,
            'exercise_name': name,
          },
        );
      }
    }

    return targets;
  }

  bool get _needsExerciseTarget {
    return _selectedReasonCode == 'too_difficult' ||
        _selectedReasonCode == 'too_easy' ||
        _selectedReasonCode == 'dislike_exercise' ||
        _selectedReasonCode == 'missing_equipment';
  }

  bool get _canSubmit {
    if (_selectedReasonCode == null) return false;

    if (_needsExerciseTarget) {
      return _selectedDayNumber != null &&
          (_selectedExerciseName?.isNotEmpty ?? false);
    }

    if (_selectedReasonCode == 'time_changed') {
      final int? minutes =
          int.tryParse(_minutesController.text.trim());

      return minutes != null &&
          minutes >= 15 &&
          minutes <= 180;
    }

    if (_selectedReasonCode == 'physical_limitation' ||
        _selectedReasonCode == 'other') {
      return _noteController.text.trim().isNotEmpty;
    }

    return true;
  }

  void _chooseReason(
    String code,
    String label,
  ) {
    setState(() {
      _selectedReasonCode = code;
      _selectedReasonLabel = label;
      _selectedDayNumber = null;
      _selectedExerciseName = null;
      _noteController.clear();
      _minutesController.clear();
    });
  }

  void _submit() {
    if (!_canSubmit) return;

    final int? newMinutes =
        _selectedReasonCode == 'time_changed'
            ? int.tryParse(
                _minutesController.text.trim(),
              )
            : null;

    final String targetLabel =
        _selectedDayNumber != null &&
                (_selectedExerciseName?.isNotEmpty ?? false)
            ? 'Day $_selectedDayNumber · $_selectedExerciseName'
            : '';

    Navigator.of(context).pop(
      <String, dynamic>{
        'reason_code': _selectedReasonCode,
        'reason_label': _selectedReasonLabel,
        'day_number': _selectedDayNumber,
        'exercise_name': _selectedExerciseName,
        'target_label': targetLabel,
        'user_note': _noteController.text.trim(),
        'new_session_minutes': newMinutes,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Adjust My Plan',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Tell MuscleUp why you want a change, then identify the exact part of the plan when needed.',
                style: TextStyle(
                  height: 1.45,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 18),

              if (_selectedReasonCode == null)
                _buildReasonStep()
              else
                _buildDetailStep(),

              if (_selectedReasonCode != null) ...<Widget>[
                const SizedBox(height: 20),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedReasonCode = null;
                            _selectedReasonLabel = null;
                            _selectedDayNumber = null;
                            _selectedExerciseName = null;
                            _noteController.clear();
                            _minutesController.clear();
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize:
                              const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed:
                            _canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              AppTheme.primaryGreen,
                          foregroundColor: Colors.white,
                          minimumSize:
                              const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Update My Plan',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),
              const Text(
                'Your current plan stays active until a replacement is successfully created.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReasonStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Why do you want to adjust your plan?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ..._reasons.map(
          (Map<String, String> reason) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _chooseReason(
                    reason['code']!,
                    reason['label']!,
                  ),
                  borderRadius:
                      BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: AppTheme.border,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            reason['label']!,
                            style: const TextStyle(
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  AppTheme.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color:
                              AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDetailStep() {
    if (_needsExerciseTarget) {
      final String title;

      switch (_selectedReasonCode) {
        case 'too_difficult':
          title = 'Which exercise feels too difficult?';
          break;
        case 'too_easy':
          title = 'Which exercise feels too easy?';
          break;
        case 'dislike_exercise':
          title = 'Which exercise do you want changed?';
          break;
        case 'missing_equipment':
          title = 'Which exercise needs equipment you do not have?';
          break;
        default:
          title = 'Which exercise should change?';
      }

      return _buildExerciseTargetStep(title);
    }

    if (_selectedReasonCode == 'time_changed') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'How much time do you have per session now?',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _minutesController,
            keyboardType: TextInputType.number,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Example: 45',
              suffixText: 'minutes',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide:
                    BorderSide(color: AppTheme.border),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Use a value between 15 and 180 minutes.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
    }

    if (_selectedReasonCode == 'physical_limitation') {
      return _buildNoteStep(
        title: 'What changed physically?',
        hint:
            'Example: Overhead pressing bothers my right shoulder.',
      );
    }

    return _buildNoteStep(
      title: 'What would you like changed?',
      hint:
          'Tell MuscleUp what is not working for you.',
    );
  }

  Widget _buildExerciseTargetStep(
    String title,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _selectedDayNumber == null
              ? null
              : '$_selectedDayNumber::$_selectedExerciseName',
          isExpanded: true,
          decoration: InputDecoration(
            hintText: 'Select exercise',
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
          ),
          items: _exerciseTargets
              .map<DropdownMenuItem<String>>(
            (Map<String, dynamic> target) {
              final int dayNumber =
                  target['day_number'] as int;

              final String name =
                  target['exercise_name']
                      .toString();

              return DropdownMenuItem<String>(
                value: '$dayNumber::$name',
                child: Text(
                  'Day $dayNumber · $name',
                ),
              );
            },
          ).toList(),
          onChanged: (String? value) {
            if (value == null) return;

            final int splitIndex =
                value.indexOf('::');

            if (splitIndex <= 0) return;

            setState(() {
              _selectedDayNumber =
                  int.tryParse(
                value.substring(0, splitIndex),
              );

              _selectedExerciseName =
                  value.substring(splitIndex + 2);
            });
          },
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _noteController,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText:
                'Optional: tell us what specifically is wrong.',
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoteStep({
    required String title,
    required String hint,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _noteController,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppTheme.background,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),
              borderSide:
                  BorderSide(color: AppTheme.border),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanSummary extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _PlanSummary({required this.plan});

  @override
  Widget build(BuildContext context) {
    final goal = plan['goal']?.toString() ?? 'Personalized Training';
    final level = plan['experience_level']?.toString() ?? 'Personalized';
    final weeks = (plan['cycle_weeks'] as num?)?.toInt() ?? 0;

    return _Panel(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.fitness_center_rounded,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  goal,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$level • $weeks-week cycle',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
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

class _DaySelector extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _DaySelector({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        height: 58,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: days.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = days[index];
          final active = selectedIndex == index;
          final number = (day['day_number'] as num?)?.toInt() ?? index + 1;
          final focus = day['focus']?.toString().trim() ?? '';

          return InkWell(
            onTap: () => onSelected(index),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              constraints: const BoxConstraints(minWidth: 82),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                color: active ? AppTheme.primaryGreen : AppTheme.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? AppTheme.primaryGreen : AppTheme.border,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Day $number',
                    style: TextStyle(
                      color: active
                          ? Colors.white
                          : AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (focus.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      focus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: active
                            ? Colors.white.withValues(alpha: .8)
                            : AppTheme.textSecondary,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
        ),
      ),
    );
  }
}

class _TrainingDayCard extends StatelessWidget {
  final Map<String, dynamic> day;

  const _TrainingDayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    final dayNumber = (day['day_number'] as num?)?.toInt() ?? 0;
    final title = day['title']?.toString() ?? 'Training Day';
    final focus = day['focus']?.toString() ?? '';
    final exercises =
        (day['training_exercises'] as List<Map<String, dynamic>>?) ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Panel(
          child: Row(
            children: [
              const Icon(
                Icons.fitness_center_rounded,
                color: AppTheme.primaryGreen,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Day $dayNumber • $title',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (focus.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        focus,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (exercises.isEmpty)
          const _Panel(
            child: Text(
              'No exercises added yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          )
        else
          ...List.generate(
            exercises.length,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ExerciseCard(
                number: index + 1,
                exercise: exercises[index],
              ),
            ),
          ),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  final int number;
  final Map<String, dynamic> exercise;

  const _ExerciseCard({
    required this.number,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['exercise_name']?.toString() ?? 'Exercise';
    final sets = (exercise['sets'] as num?)?.toInt() ?? 0;
    final reps = exercise['reps']?.toString() ?? '';
    final restSeconds = (exercise['rest_seconds'] as num?)?.toInt();
    final primary = _stringList(exercise['primary_muscles']);
    final secondary = _stringList(exercise['secondary_muscles']);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExerciseDetailScreen(exercise: exercise),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(
                    Icons.accessibility_new_rounded,
                    color: AppTheme.primaryGreen,
                    size: 30,
                  ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$number',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$sets sets × $reps reps'
                    '${restSeconds == null ? '' : '  •  ${_formatRest(restSeconds)} rest'}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  if (primary.isNotEmpty || secondary.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      children: [
                        ...primary.take(2).map(
                              (m) => _MuscleChip(
                                label: m,
                                primary: true,
                              ),
                            ),
                        ...secondary.take(1).map(
                              (m) => _MuscleChip(
                                label: m,
                                primary: false,
                              ),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class ExerciseDetailScreen extends StatelessWidget {
  final Map<String, dynamic> exercise;

  const ExerciseDetailScreen({
    super.key,
    required this.exercise,
  });

  @override
  Widget build(BuildContext context) {
    final name = exercise['exercise_name']?.toString() ?? 'Exercise';
    final sets = (exercise['sets'] as num?)?.toInt() ?? 0;
    final reps = exercise['reps']?.toString() ?? '';
    final restSeconds = (exercise['rest_seconds'] as num?)?.toInt();
    final weight = exercise['suggested_weight'];
    final weightUnit = exercise['weight_unit']?.toString() ?? 'lb';
    final primary = _stringList(exercise['primary_muscles']);
    final secondary = _stringList(exercise['secondary_muscles']);

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text(
            'Exercise Detail',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          backgroundColor: AppTheme.background,
          foregroundColor: AppTheme.textPrimary,
          elevation: 0,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _StatGrid(
                    sets: sets,
                    reps: reps,
                    restSeconds: restSeconds,
                    weight: weight,
                    weightUnit: weightUnit,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.card,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: AppTheme.primaryGreen,
                      labelColor: AppTheme.primaryGreen,
                      unselectedLabelColor: AppTheme.textSecondary,
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: 'Overview'),
                        Tab(text: 'Muscles'),
                        Tab(text: 'Video'),
                        Tab(text: 'How to Perform'),
                        Tab(text: 'Tips'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 610,
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _OverviewTab(
                          name: name,
                          primary: primary,
                          secondary: secondary,
                        ),
                        _MusclesTab(
                          primary: primary,
                          secondary: secondary,
                        ),
                        _VideoTab(
                          name: name,
                          videoUrl:
                              exercise['video_url']?.toString(),
                        ),
                        _HowToTab(name: name),
                        const _TipsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  final int sets;
  final String reps;
  final int? restSeconds;
  final dynamic weight;
  final String weightUnit;

  const _StatGrid({
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.weight,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: _MiniStat(
              icon: Icons.layers_rounded,
              value: '$sets',
              label: 'Sets',
            ),
          ),
          _divider(),
          Expanded(
            child: _MiniStat(
              icon: Icons.repeat_rounded,
              value: reps,
              label: 'Reps',
            ),
          ),
          _divider(),
          Expanded(
            child: _MiniStat(
              icon: Icons.timer_outlined,
              value: restSeconds == null ? '—' : _formatRest(restSeconds!),
              label: 'Rest',
            ),
          ),
          _divider(),
          Expanded(
            child: _MiniStat(
              icon: Icons.fitness_center_rounded,
              value: weight == null ? 'Auto' : '$weight $weightUnit',
              label: 'Weight',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 44,
        color: AppTheme.border,
      );
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryGreen,
          size: 20,
        ),
        const SizedBox(height: 5),
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final String name;
  final List<String> primary;
  final List<String> secondary;

  const _OverviewTab({
    required this.name,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'About this exercise',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                primary.isEmpty
                    ? '$name is part of your personalized training plan.'
                    : '$name primarily targets ${primary.join(', ')}'
                        '${secondary.isEmpty ? '.' : ' and also uses ${secondary.join(', ')}.'}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _MuscleLegend(
          primary: primary,
          secondary: secondary,
        ),
      ],
    );
  }
}

class _MusclesTab extends StatelessWidget {
  final List<String> primary;
  final List<String> secondary;

  const _MusclesTab({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Target Muscles',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _BodyMapCard(
                      label: 'Front',
                      isBack: false,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _BodyMapCard(
                      label: 'Back',
                      isBack: true,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _MuscleLegend(
                primary: primary,
                secondary: secondary,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BodyMapCard extends StatelessWidget {
  final String label;
  final bool isBack;
  final List<String> primary;
  final List<String> secondary;

  const _BodyMapCard({
    required this.label,
    required this.isBack,
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _BodyMapPainter(
                isBack: isBack,
                primary: primary,
                secondary: secondary,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BodyMapPainter extends CustomPainter {
  final bool isBack;
  final List<String> primary;
  final List<String> secondary;

  _BodyMapPainter({
    required this.isBack,
    required this.primary,
    required this.secondary,
  });

  bool _contains(List<String> muscles, List<String> needles) {
    final text = muscles.join(' ').toLowerCase();
    return needles.any((n) => text.contains(n));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final base = Paint()..color = AppTheme.textSecondary.withValues(alpha: .28);
    final primaryPaint = Paint()..color = AppTheme.primaryGreen;
    final secondaryPaint =
        Paint()..color = AppTheme.primaryGreen.withValues(alpha: .45);

    Paint musclePaint(List<String> names) {
      if (_contains(primary, names)) return primaryPaint;
      if (_contains(secondary, names)) return secondaryPaint;
      return base;
    }

    // Head
    canvas.drawCircle(Offset(cx, 24), 16, base);

    // Torso
    final torso = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, 92),
        width: 62,
        height: 104,
      ),
      const Radius.circular(24),
    );
    canvas.drawRRect(torso, base);

    // Chest / upper back
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, 69),
        width: 57,
        height: 37,
      ),
      musclePaint(
        isBack
            ? ['back', 'lat', 'trapezius', 'trap', 'rhomboid']
            : ['chest', 'pectoral', 'pec'],
      ),
    );

    // Core
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, 108),
          width: 31,
          height: 48,
        ),
        const Radius.circular(12),
      ),
      musclePaint(['core', 'ab', 'oblique']),
    );

    // Shoulders
    for (final dx in [-39.0, 39.0]) {
      canvas.drawCircle(
        Offset(cx + dx, 62),
        13,
        musclePaint(['shoulder', 'deltoid', 'delt']),
      );
    }

    // Arms
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * 48;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 99),
            width: 17,
            height: 58,
          ),
          const Radius.circular(9),
        ),
        musclePaint(
          isBack
              ? ['tricep', 'arm']
              : ['bicep', 'tricep', 'arm'],
        ),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + side * 55, 149),
            width: 14,
            height: 50,
          ),
          const Radius.circular(8),
        ),
        musclePaint(['forearm']),
      );
    }

    // Glutes / hips
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, 148),
        width: 57,
        height: 35,
      ),
      musclePaint(['glute', 'hip']),
    );

    // Legs
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * 19;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 189),
            width: 25,
            height: 74,
          ),
          const Radius.circular(12),
        ),
        musclePaint(
          isBack
              ? ['hamstring', 'glute', 'leg']
              : ['quad', 'quadricep', 'leg'],
        ),
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(x, 248),
            width: 18,
            height: 52,
          ),
          const Radius.circular(10),
        ),
        musclePaint(['calf', 'calves']),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BodyMapPainter oldDelegate) {
    return oldDelegate.isBack != isBack ||
        oldDelegate.primary.join('|') != primary.join('|') ||
        oldDelegate.secondary.join('|') != secondary.join('|');
  }
}

class _MuscleLegend extends StatelessWidget {
  final List<String> primary;
  final List<String> secondary;

  const _MuscleLegend({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    if (primary.isEmpty && secondary.isEmpty) {
      return const _Panel(
        child: Text(
          'Target-muscle data is not available for this exercise yet.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            height: 1.5,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (primary.isNotEmpty) ...[
          const _LegendTitle(
            color: AppTheme.primaryGreen,
            title: 'Primary',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: primary
                .map(
                  (m) => _MuscleChip(
                    label: m,
                    primary: true,
                  ),
                )
                .toList(),
          ),
        ],
        if (primary.isNotEmpty && secondary.isNotEmpty)
          const SizedBox(height: 16),
        if (secondary.isNotEmpty) ...[
          _LegendTitle(
            color: AppTheme.primaryGreen.withValues(alpha: .45),
            title: 'Secondary',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: secondary
                .map(
                  (m) => _MuscleChip(
                    label: m,
                    primary: false,
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _LegendTitle extends StatelessWidget {
  final Color color;
  final String title;

  const _LegendTitle({
    required this.color,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 7),
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _VideoTab extends StatelessWidget {
  final String name;
  final String? videoUrl;

  const _VideoTab({
    required this.name,
    required this.videoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        ExerciseVideoPlayer(
          exerciseName: name,
          existingVideoUrl: videoUrl,
        ),
      ],
    );
  }
}

class _HowToTab extends StatelessWidget {
  final String name;

  const _HowToTab({required this.name});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How to Perform',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              _Step(number: 1, text: 'Set up in a stable starting position.'),
              _Step(
                number: 2,
                text: 'Use a controlled range of motion and keep your body aligned.',
              ),
              _Step(
                number: 3,
                text: 'Control the lowering phase instead of dropping the weight.',
              ),
              _Step(
                number: 4,
                text: 'Finish each repetition with control and consistent breathing.',
              ),
              const SizedBox(height: 10),
              Text(
                'Exercise-specific coaching for $name can be connected to the AI exercise library next.',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TipsTab extends StatelessWidget {
  const _TipsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Coach Tips',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 14),
              _Tip(
                icon: Icons.speed_rounded,
                text: 'Do not rush the repetition. Control matters more than momentum.',
              ),
              _Tip(
                icon: Icons.air_rounded,
                text: 'Avoid holding your breath through the entire set.',
              ),
              _Tip(
                icon: Icons.shield_outlined,
                text: 'Stop if you feel sharp pain or unusual joint discomfort.',
              ),
              _Tip(
                icon: Icons.tune_rounded,
                text: 'Use a load that lets you keep good technique across the target rep range.',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;

  const _Step({
    required this.number,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 27,
            height: 27,
            decoration: const BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.45,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: AppTheme.primaryGreen,
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  final bool primary;

  const _MuscleChip({
    required this.label,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(
          alpha: primary ? .16 : .07,
        ),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(
            alpha: primary ? .34 : .16,
          ),
        ),
      ),
      child: Text(
        _prettyMuscle(label),
        style: TextStyle(
          color: primary
              ? AppTheme.primaryGreen
              : AppTheme.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  final String title;
  final String text;

  const _Info({
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: _Panel(
        child: Column(
          children: [
            const Icon(
              Icons.fitness_center_outlined,
              size: 42,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                height: 1.5,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: child,
    );
  }
}

List<String> _stringList(dynamic value) {
  if (value == null) return [];

  if (value is List) {
    return value
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  final text = value.toString().trim();
  if (text.isEmpty) return [];

  return text
      .replaceAll('[', '')
      .replaceAll(']', '')
      .split(',')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

String _formatRest(int seconds) {
  if (seconds < 60) return '${seconds}s';

  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;

  if (remainder == 0) return '${minutes}m';
  return '${minutes}m ${remainder}s';
}

String _prettyMuscle(String raw) {
  final cleaned = raw.replaceAll('_', ' ').trim();
  if (cleaned.isEmpty) return cleaned;

  return cleaned
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map(
        (w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}',
      )
      .join(' ');
}