import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:future_project/models/future_vision.dart';
import 'package:future_project/models/future_body_template.dart';
import 'package:future_project/models/future_self_generation.dart';
import 'package:future_project/screens/body_progress_screen.dart';
import 'package:future_project/screens/vision_milestones_screen.dart';
import 'package:future_project/screens/nutrition_home_screen.dart';
import 'package:future_project/screens/training_plan_screen.dart';
import 'package:future_project/services/future_vision_service.dart';
import 'package:future_project/services/future_self_image_service.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/my_why_section.dart';

class VisionScreen extends StatefulWidget {
  const VisionScreen({super.key});

  @override
  State<VisionScreen> createState() => _VisionScreenState();
}

class _VisionScreenState extends State<VisionScreen> {
  static const _aspirations = <(String, String)>[
    ('fat_loss', 'Lose body fat'),
    ('build_muscle', 'Build muscle'),
    ('feel_healthier', 'Feel healthier'),
    ('become_stronger', 'Become stronger'),
    ('improve_fitness', 'Improve fitness'),
  ];
  static const _feelings = <String>[
    'Confident',
    'Energetic',
    'Strong',
    'Healthy',
    'Athletic',
  ];

  final _service = FutureVisionService();
  FutureVisionState? _state;
  String? _aspiration;
  final Set<String> _selectedFeelings = {};
  bool _loading = true;
  bool _saving = false;
  bool _editingIdentity = false;
  bool _showAllEvidence = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await _service.load();
      if (!mounted) return;
      setState(() {
        _state = state;
        _aspiration =
            state.vision?.primaryGoal ?? _visionGoal(state.foundationGoal);
        _selectedFeelings
          ..clear()
          ..addAll(state.vision?.desiredFeelings ?? const []);
        _loading = false;
        _error = null;
        _editingIdentity = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  String? _visionGoal(String goal) => switch (goal) {
    'fat_loss' => 'fat_loss',
    'build_muscle' || 'muscle_gain' => 'build_muscle',
    'health' => 'feel_healthier',
    'athletic_performance' || 'fitness' => 'improve_fitness',
    _ => null,
  };

  Future<void> _saveVision() async {
    if (_aspiration == null || _selectedFeelings.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _service.saveVision(
        primaryGoal: _aspiration!,
        desiredFeelings: _selectedFeelings.toList(growable: false),
      );
      await _load();
    } catch (error) {
      if (mounted) _message('Could not save your Vision: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveReflection(String response) async {
    await _runSave(() => _service.saveReflection(response: response));
  }

  Future<void> _runSave(Future<void> Function() save) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await save();
      await _load();
    } catch (error) {
      if (mounted) _message('Could not save this change: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openTodayAction(VisionActionDestination destination) async {
    final Widget? screen = switch (destination) {
      VisionActionDestination.trainingPlan => const TrainingPlanScreen(),
      VisionActionDestination.nutrition => const NutritionHomeScreen(),
      VisionActionDestination.bodyProgress => const BodyProgressScreen(),
      VisionActionDestination.none => null,
    };
    if (screen == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'My Vision',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                children: [
                  if (_state!.vision == null || _editingIdentity)
                    _buildSetup()
                  else
                    _buildHero(_state!.vision!),
                  if (_state!.vision != null && !_editingIdentity) ...[
                    const SizedBox(height: 24),
                    _buildFutureSelfVisual(),
                    const SizedBox(height: 30),
                    _buildBelief(),
                    const SizedBox(height: 32),
                    _buildWhy(),
                    const SizedBox(height: 32),
                    _buildJourney(),
                    const SizedBox(height: 32),
                    _buildProgress(),
                    const SizedBox(height: 32),
                    _buildFutureNote(),
                    const SizedBox(height: 32),
                    _buildTodayConnection(),
                    const SizedBox(height: 32),
                    _buildReflection(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSetup() => _Surface(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('MY FUTURE SELF'),
        const SizedBox(height: 14),
        const Text(
          'Build the person you want to become.',
          style: TextStyle(
            fontSize: 30,
            height: 1.12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Define the future you\'re working toward.',
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 30),
        const Text('What change matters most to you?', style: _questionStyle),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _aspirations
              .map(
                (item) => ChoiceChip(
                  label: Text(item.$2),
                  selected: _aspiration == item.$1,
                  onSelected: (_) => setState(() => _aspiration = item.$1),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 28),
        const Text(
          'How do you want your future self to feel?',
          style: _questionStyle,
        ),
        const SizedBox(height: 6),
        const Text(
          'Choose all that fit.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _feelings
              .map(
                (feeling) => FilterChip(
                  label: Text(feeling),
                  selected: _selectedFeelings.contains(feeling),
                  onSelected: (selected) => setState(
                    () => selected
                        ? _selectedFeelings.add(feeling)
                        : _selectedFeelings.remove(feeling),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 30),
        FilledButton(
          onPressed:
              _aspiration != null && _selectedFeelings.isNotEmpty && !_saving
              ? _saveVision
              : null,
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
          child: Text(_saving ? 'Saving your Vision…' : 'Build My Vision'),
        ),
        if (_editingIdentity) ...[
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => setState(() => _editingIdentity = false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _buildHero(FutureVision vision) => Container(
    padding: const EdgeInsets.fromLTRB(26, 24, 26, 26),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF0B4938), Color(0xFF24765D)],
      ),
      borderRadius: BorderRadius.circular(30),
      boxShadow: const [
        BoxShadow(
          color: Color(0x260E5A43),
          blurRadius: 28,
          offset: Offset(0, 14),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: _Eyebrow('MY VISION', light: true)),
            IconButton(
              tooltip: 'Edit future identity',
              onPressed: () => setState(() => _editingIdentity = true),
              icon: const Icon(
                Icons.edit_outlined,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Text(
          _heroIdentityStatement(vision),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: 1.14,
            fontWeight: FontWeight.w800,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'This is who I\'m becoming.',
          style: TextStyle(
            color: Color(0xFFD8F2E8),
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 30),
        Divider(color: Colors.white.withValues(alpha: .18), height: 1),
        const SizedBox(height: 20),
        _buildHeroProgress(),
        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: .18), height: 1),
        const SizedBox(height: 20),
        _buildHeroMilestone(),
        const SizedBox(height: 20),
        Divider(color: Colors.white.withValues(alpha: .18), height: 1),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _HeroContext(
                label: 'PRIMARY GOAL',
                value: _aspirationLabel(vision.primaryGoal),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: _HeroContext(
                label: 'JOURNEY STARTED',
                value: _shortDate(vision.createdAt),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildHeroProgress() {
    final progress = _state!.progress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PROGRESS',
          style: TextStyle(
            color: Color(0xFFBDE8D7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (progress.canShowPercentage) ...[
          Text(
            '${(progress.overallProgress * 100).round()}%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Toward my Vision',
            style: TextStyle(color: Color(0xFFD8F2E8), fontSize: 14),
          ),
        ] else ...[
          const Text(
            'BUILDING YOUR BASELINE',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your progress picture will become clearer as you complete training and Body Progress checks.',
            style: TextStyle(
              color: Color(0xFFD8F2E8),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHeroMilestone() {
    final milestone = _state!.milestones.nextMilestone;
    if (milestone == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT MILESTONE',
          style: TextStyle(
            color: Color(0xFFBDE8D7),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          milestone.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_milestoneValue(milestone.currentValue)} / ${_milestoneValue(milestone.targetValue)}',
          style: const TextStyle(color: Color(0xFFD8F2E8), fontSize: 13),
        ),
        const SizedBox(height: 9),
        LinearProgressIndicator(
          value: milestone.normalizedProgress,
          minHeight: 5,
          borderRadius: BorderRadius.circular(99),
          backgroundColor: Colors.white.withValues(alpha: .18),
          color: Colors.white,
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => VisionMilestonesScreen(state: _state!.milestones),
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 34),
          ),
          child: const Text('View All Milestones'),
        ),
      ],
    );
  }

  String _milestoneValue(double value) => value == value.roundToDouble()
      ? value.round().toString()
      : value.toStringAsFixed(1);

  Widget _buildFutureSelfVisual() => _FutureSelfVisual(vision: _state!.vision!);
  Widget _buildBelief() => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 3,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(width: 18),
              const Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trust the future you chose.',
                        style: TextStyle(
                          fontSize: 27,
                          height: 1.25,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -.3,
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Every action is a vote for the person you\'re becoming.',
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildWhy() {
    return MyWhySection(
      key: ValueKey(_state!.vision!.userId),
      legacyPlaintext: _state!.vision!.why,
    );
  }

  Widget _buildJourney() {
    final stage = _state!.stage;
    final labels = ['STARTED', 'BUILDING', 'BECOMING', 'LIVING IT'];
    final activeIndex = stage.index;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('YOUR JOURNEY'),
        const SizedBox(height: 8),
        const Text(
          'You\'re building evidence that this is becoming who you are.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 18),
        Text(
          labels[activeIndex],
          style: const TextStyle(
            color: AppTheme.primaryGreen,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _stageMessage(stage),
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.45),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: _JourneyFact(
                label: 'JOURNEY STARTED',
                value: _shortDate(_state!.vision!.createdAt),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _JourneyFact(
                label: 'MEANINGFUL SIGNALS',
                value: '${_state!.meaningfulSignalCount} recorded',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgress() {
    final evidence = _showAllEvidence
        ? _state!.evidence
        : _state!.evidence.take(3).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('EVIDENCE OF CHANGE'),
        const SizedBox(height: 8),
        const Text(
          'Real actions that show you\'re moving forward.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 16),
        if (evidence.isEmpty)
          const Text(
            'Your first verified action will appear here.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                for (var index = 0; index < evidence.length; index++) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppTheme.visionCard,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _evidenceIcon(evidence[index].type),
                            color: AppTheme.primaryGreen,
                            size: 17,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                evidence[index].label,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                evidence[index].detail,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (index != evidence.length - 1)
                    const Divider(height: 1, indent: 60),
                ],
              ],
            ),
          ),
        if (_state!.evidence.length > 3)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () =>
                  setState(() => _showAllEvidence = !_showAllEvidence),
              child: Text(_showAllEvidence ? 'Show less' : 'View more'),
            ),
          ),
      ],
    );
  }

  Widget _buildFutureNote() => Container(
    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
    decoration: BoxDecoration(
      color: AppTheme.visionCard,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow('FROM YOUR FUTURE SELF'),
        const SizedBox(height: 10),
        Text(
          _state!.futureSelfMessage,
          style: const TextStyle(
            fontSize: 19,
            height: 1.48,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _buildTodayConnection() {
    final action = _state!.todayAction;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('TODAY → MY VISION'),
        const SizedBox(height: 8),
        const Text(
          'One action that moves you closer today.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xFF123F33),
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x24123F33),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow('TODAY', light: true),
              const SizedBox(height: 10),
              Text(
                action.action,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                action.source,
                style: const TextStyle(
                  color: Color(0xFFBDE8D7),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                action.explanation,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Icon(
                  Icons.arrow_downward_rounded,
                  color: Color(0xFFBDE8D7),
                ),
              ),
              const _Eyebrow('MY VISION', light: true),
              const SizedBox(height: 10),
              Text(
                _visionDestination(_state!.vision!, separator: ' • '),
                style: const TextStyle(
                  color: Color(0xFFD8F2E8),
                  fontSize: 18,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (action.ctaLabel != null) ...[
                const SizedBox(height: 18),
                OutlinedButton(
                  onPressed: () => _openTodayAction(action.destination),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  child: Text(action.ctaLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReflection() {
    final selected = _state!.todayReflection?.response;
    const options = [
      ('yes', 'YES'),
      ('a_little', 'A LITTLE'),
      ('not_today', 'NOT TODAY'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('BEFORE YOU FINISH TODAY'),
        const SizedBox(height: 8),
        const Text(
          'Did your actions today match the person you\'re becoming?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            height: 1.4,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (option) => ChoiceChip(
                  label: Text(option.$2),
                  selected: selected == option.$1,
                  onSelected: _saving
                      ? null
                      : (_) => _saveReflection(option.$1),
                ),
              )
              .toList(),
        ),
        if (selected != null) ...[
          const SizedBox(height: 12),
          Text(
            _reflectionResponse(selected),
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, {Widget? trailing}) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            letterSpacing: 1.35,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      ?trailing,
    ],
  );

  String _heroIdentityStatement(FutureVision vision) {
    final qualities = <String>[
      switch (vision.primaryGoal) {
        'fat_loss' => 'Leaner',
        'build_muscle' || 'muscle_gain' => 'More muscular',
        'feel_healthier' || 'health' => 'Healthier',
        'become_stronger' => 'Stronger',
        'improve_fitness' || 'fitness' => 'Fitter',
        'athletic_performance' => 'More athletic',
        _ => 'Becoming my future self',
      },
    ];
    for (final feeling in vision.desiredFeelings) {
      final quality = switch (feeling.trim().toLowerCase()) {
        'confident' => 'More confident',
        'energetic' => 'More energetic',
        'strong' => 'Stronger',
        'healthy' => 'Healthier',
        'athletic' => 'More athletic',
        _ => feeling.trim(),
      };
      if (quality.isNotEmpty &&
          !qualities.any(
            (existing) => existing.toLowerCase() == quality.toLowerCase(),
          )) {
        qualities.add(quality);
      }
    }
    return '${qualities.take(3).join('. ')}.';
  }

  String _aspirationLabel(String goal) =>
      _aspirations
          .where((item) => item.$1 == goal)
          .map((item) => item.$2)
          .firstOrNull ??
      'My future self';

  String _stageMessage(VisionJourneyStage stage) => switch (stage) {
    VisionJourneyStage.starting =>
      'You chose a direction and gave your future a starting point.',
    VisionJourneyStage.building =>
      'You are creating the structure that helps your vision become real.',
    VisionJourneyStage.becoming =>
      'Your actions are starting to match the future you chose.',
    VisionJourneyStage.livingIt =>
      'The future you chose is becoming part of how you live.',
  };

  IconData _evidenceIcon(VisionEvidenceType type) => switch (type) {
    VisionEvidenceType.visionStarted => Icons.explore_outlined,
    VisionEvidenceType.foundationCompleted => Icons.flag_outlined,
    VisionEvidenceType.bodyProgress => Icons.straighten_rounded,
    VisionEvidenceType.trainingPlanCreated => Icons.fitness_center_outlined,
    VisionEvidenceType.workoutCompleted => Icons.task_alt_rounded,
    VisionEvidenceType.trainingConsistency =>
      Icons.local_fire_department_outlined,
    VisionEvidenceType.nutritionStarted ||
    VisionEvidenceType.nutritionConsistency => Icons.restaurant_outlined,
    VisionEvidenceType.reflectionStarted ||
    VisionEvidenceType.reflectionConsistency => Icons.self_improvement_rounded,
    VisionEvidenceType.returnedAfterGap => Icons.replay_rounded,
  };

  String _reflectionResponse(String response) => switch (response) {
    'yes' => 'Keep building on it.',
    'a_little' => 'Small steps still count.',
    'not_today' =>
      'That\'s useful to know. One day doesn\'t change your direction.',
    _ => '',
  };

  String _visionDestination(FutureVision vision, {String separator = ' and '}) {
    final goal = _aspirationLabel(vision.primaryGoal);
    final feeling = vision.desiredFeelings.firstOrNull;
    return feeling == null ? goal : '$goal${separator}Feel $feeling';
  }

  String _shortDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  static const _questionStyle = TextStyle(
    fontWeight: FontWeight.w700,
    color: AppTheme.textPrimary,
  );
}

class _FutureSelfVisual extends StatefulWidget {
  final FutureVision vision;

  const _FutureSelfVisual({required this.vision});

  @override
  State<_FutureSelfVisual> createState() => _FutureSelfVisualState();
}

class _FutureSelfVisualState extends State<_FutureSelfVisual> {
  final _imageService = FutureSelfImageService();
  final _picker = ImagePicker();
  String? _currentPhotoPath;
  String? _futurePhotoPath;
  String? _currentPreviewUrl;
  String? _futurePreviewUrl;
  Uint8List? _localCurrentPreviewBytes;
  bool _savingPhoto = false;
  bool _generatingFutureSelf = false;
  bool _removingFutureSelf = false;
  bool _generationFailed = false;
  bool _generationSafetyRejected = false;
  String? _generationErrorMessage;
  FutureSelfInputMode? _inputMode;
  FutureSelfInputMode? _currentPhotoMode;
  FutureSelfInputMode? _futurePhotoMode;
  String? _lastGenerationButtonDebugState;

  @override
  void initState() {
    super.initState();
    _currentPhotoPath = widget.vision.currentPhotoPath;
    _futurePhotoPath = widget.vision.futureSelfImagePath;
    _inputMode = widget.vision.futureSelfInputMode;
    _currentPhotoMode = widget.vision.currentPhotoInputMode;
    _futurePhotoMode = widget.vision.futureSelfGeneratedInputMode;
    _loadPreviewUrls();
    _hydrateStoredPhotoReferences();
  }

  @override
  void didUpdateWidget(covariant _FutureSelfVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vision.currentPhotoPath != widget.vision.currentPhotoPath ||
        oldWidget.vision.futureSelfImagePath !=
            widget.vision.futureSelfImagePath ||
        oldWidget.vision.futureSelfInputMode !=
            widget.vision.futureSelfInputMode ||
        oldWidget.vision.currentPhotoInputMode !=
            widget.vision.currentPhotoInputMode ||
        oldWidget.vision.futureSelfGeneratedInputMode !=
            widget.vision.futureSelfGeneratedInputMode) {
      _currentPhotoPath = widget.vision.currentPhotoPath;
      _futurePhotoPath = widget.vision.futureSelfImagePath;
      _inputMode = widget.vision.futureSelfInputMode;
      _currentPhotoMode = widget.vision.currentPhotoInputMode;
      _futurePhotoMode = widget.vision.futureSelfGeneratedInputMode;
      _generationFailed = false;
      _generationSafetyRejected = false;
      _loadPreviewUrls();
    }
  }

  Future<void> _loadPreviewUrls() async {
    final paths = (_activeCurrentPhotoPath, _activeFuturePhotoPath);
    final urls = await Future.wait([
      _safePreviewUrl(paths.$1),
      _safePreviewUrl(paths.$2),
    ]);
    if (!mounted ||
        paths.$1 != _activeCurrentPhotoPath ||
        paths.$2 != _activeFuturePhotoPath) {
      return;
    }
    setState(() {
      _currentPreviewUrl = urls[0];
      _futurePreviewUrl = urls[1];
    });
  }

  Future<String?> _safePreviewUrl(String? path) async {
    try {
      return await _imageService.createPreviewUrl(path);
    } catch (error) {
      debugPrint('Future Self preview unavailable: $error');
      return null;
    }
  }

  Future<void> _hydrateStoredPhotoReferences() async {
    try {
      final references = await _imageService.loadPhotoReferences();
      if (!mounted) return;
      final savedCurrentPath = references.currentPhotoPath?.trim();
      final savedFuturePath = references.futurePhotoPath?.trim();
      final savedMode = references.selectedMode;
      final nextCurrentPath = savedCurrentPath?.isNotEmpty == true
          ? savedCurrentPath
          : _currentPhotoPath;
      final nextFuturePath = savedFuturePath?.isNotEmpty == true
          ? savedFuturePath
          : _futurePhotoPath;
      if (nextCurrentPath == _currentPhotoPath &&
          nextFuturePath == _futurePhotoPath &&
          savedMode == _inputMode &&
          references.currentPhotoMode == _currentPhotoMode &&
          references.generatedImageMode == _futurePhotoMode) {
        return;
      }
      setState(() {
        _currentPhotoPath = nextCurrentPath;
        _futurePhotoPath = nextFuturePath;
        _inputMode = savedMode;
        _currentPhotoMode = references.currentPhotoMode;
        _futurePhotoMode = references.generatedImageMode;
      });
      await _loadPreviewUrls();
    } catch (error, stackTrace) {
      debugPrint('Future Self saved photo reference load failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool get _canGenerateFutureSelf {
    final hasSavedCurrentPhoto =
        _activeCurrentPhotoPath?.trim().isNotEmpty == true;
    return _imageService.hasAuthenticatedUser &&
        hasSavedCurrentPhoto &&
        !_generatingFutureSelf;
  }

  String? get _activeCurrentPhotoPath =>
      _inputMode != null && _currentPhotoMode == _inputMode
      ? _currentPhotoPath
      : null;

  String? get _activeFuturePhotoPath =>
      _inputMode != null && _futurePhotoMode == _inputMode
      ? _futurePhotoPath
      : null;

  Future<void> _selectInputMode(FutureSelfInputMode mode) async {
    if (mode == _inputMode || _generatingFutureSelf || _savingPhoto) return;
    final previous = _inputMode;
    setState(() {
      _inputMode = mode;
      _currentPreviewUrl = null;
      _futurePreviewUrl = null;
      _generationFailed = false;
      _generationSafetyRejected = false;
      _generationErrorMessage = null;
    });
    try {
      await _imageService.saveInputMode(mode);
      await _loadPreviewUrls();
    } catch (error, stackTrace) {
      debugPrint('Future Self mode persistence failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() => _inputMode = previous);
      await _loadPreviewUrls();
      if (mounted) _showMessage('Could not save this Future Self mode.');
    }
  }

  void _debugGenerationButtonState(bool canGenerate) {
    if (!kDebugMode) return;
    final state =
        'authenticated=${_imageService.hasAuthenticatedUser};'
        'hasVision=true;'
        'currentPhotoPath=${_activeCurrentPhotoPath ?? 'null'};'
        'isGenerating=$_generatingFutureSelf;'
        'canGenerate=$canGenerate';
    if (state == _lastGenerationButtonDebugState) return;
    _lastGenerationButtonDebugState = state;
    debugPrint('Future Self button state:');
    debugPrint('authenticated=${_imageService.hasAuthenticatedUser}');
    debugPrint('hasVision=true');
    debugPrint('currentPhotoPath=${_activeCurrentPhotoPath ?? 'null'}');
    debugPrint('isGenerating=$_generatingFutureSelf');
    debugPrint('canGenerate=$canGenerate');
  }

  Future<void> _selectPhoto() async {
    if (_savingPhoto) return;
    final inputMode = _inputMode;
    if (inputMode == null) {
      _showMessage('Choose Face Only or Full Body first.');
      return;
    }

    try {
      debugPrint('VISION PHOTO: opening image picker');

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1280,
        maxHeight: 1600,
      );

      debugPrint(
        'VISION PHOTO: picker returned ${picked == null ? 'null' : 'a file'}',
      );

      if (picked == null || !mounted) return;

      debugPrint('VISION PHOTO: filename=${picked.name}');
      debugPrint('VISION PHOTO: path=${picked.path}');

      final extension = picked.name.contains('.')
          ? picked.name.split('.').last.toLowerCase()
          : picked.path.split('.').last.toLowerCase();

      debugPrint('VISION PHOTO: extension=$extension');

      if (!['jpg', 'jpeg', 'png'].contains(extension)) {
        throw FormatException('Unsupported image format: $extension');
      }

      final bytes = await picked.readAsBytes();

      debugPrint('VISION PHOTO: byteLength=${bytes.length}');

      if (bytes.isEmpty) {
        throw const FormatException('Selected image bytes are empty.');
      }
      final localValidation = _imageService.photoValidator.validate(
        bytes: bytes,
        mode: inputMode,
      );
      if (!localValidation.canGenerate) {
        throw FormatException(
          localValidation.userMessage ?? 'Please choose another clear photo.',
        );
      }

      if (!mounted) return;

      setState(() {
        _localCurrentPreviewBytes = bytes;
        _savingPhoto = true;
      });

      debugPrint('VISION PHOTO: starting persistent upload');

      final path = await _imageService.uploadCurrentPhoto(
        bytes: bytes,
        fileExtension: extension,
        inputMode: inputMode,
      );

      debugPrint('VISION PHOTO: upload/persistence succeeded');
      debugPrint('VISION PHOTO: saved storage path=$path');

      if (path.trim().isEmpty) {
        throw StateError('Photo upload returned an empty storage path.');
      }

      final previewUrl = await _safePreviewUrl(path);

      debugPrint(
        'VISION PHOTO: persisted preview available=${previewUrl != null}',
      );

      if (!mounted) return;

      setState(() {
        _currentPhotoPath = path;
        _currentPhotoMode = inputMode;
        _currentPreviewUrl = previewUrl;
        if (previewUrl != null) {
          _localCurrentPreviewBytes = null;
        }
        _futurePhotoPath = null;
        _futurePhotoMode = null;
        _futurePreviewUrl = null;
        _generationFailed = false;
        _generationSafetyRejected = false;
        _generationErrorMessage = null;
      });

      debugPrint('VISION PHOTO: currentPhotoPath state=$_currentPhotoPath');
      _showMessage('Photo saved.');
    } on StorageException catch (error, stackTrace) {
      debugPrint('========== CURRENT PHOTO STORAGE ERROR ==========');
      debugPrint('message: ${error.message}');
      debugPrint('statusCode: ${error.statusCode}');
      debugPrint('error: ${error.error}');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('=================================================');

      if (mounted) {
        _showMessage('Could not save this photo. Please try again.');
      }
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('========== CURRENT PHOTO DATABASE ERROR ==========');
      debugPrint('message: ${error.message}');
      debugPrint('code: ${error.code}');
      debugPrint('details: ${error.details}');
      debugPrint('hint: ${error.hint}');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==================================================');

      if (mounted) {
        _showMessage('Could not save this photo. Please try again.');
      }
    } on FormatException catch (error, stackTrace) {
      debugPrint('========== CURRENT PHOTO FORMAT ERROR ==========');
      debugPrint(error.message);
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('================================================');

      if (mounted) {
        _showMessage('Please choose a JPG or PNG photo.');
      }
    } catch (error, stackTrace) {
      debugPrint('========== CURRENT PHOTO UNKNOWN ERROR ==========');
      debugPrint('$error');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('=================================================');

      if (mounted) {
        _showMessage('Could not save this photo. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _savingPhoto = false);
      }
    }
  }

  Future<void> _removePhoto() async {
    if (_savingPhoto) return;
    setState(() => _savingPhoto = true);
    try {
      await _imageService.removeCurrentPhoto();
      if (!mounted) return;
      setState(() {
        _currentPhotoPath = null;
        _currentPhotoMode = null;
        _currentPreviewUrl = null;
        _localCurrentPreviewBytes = null;
        _futurePhotoPath = null;
        _futurePhotoMode = null;
        _futurePreviewUrl = null;
        _generationFailed = false;
        _generationSafetyRejected = false;
        _generationErrorMessage = null;
      });
    } catch (error) {
      if (mounted) _showMessage('Could not remove this photo.');
      debugPrint('Future Self photo removal failed: $error');
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  Future<void> _generateFutureSelf() async {
    final currentPath = _activeCurrentPhotoPath;
    final inputMode = _inputMode;
    if (currentPath == null || inputMode == null || _generatingFutureSelf) {
      return;
    }
    setState(() {
      _generatingFutureSelf = true;
      _generationFailed = false;
      _generationSafetyRejected = false;
      _generationErrorMessage = null;
    });
    try {
      final result = await _imageService.generateFutureSelf(
        widget.vision,
        currentPhotoPath: currentPath,
        inputMode: inputMode,
      );
      final previewUrl = await _safePreviewUrl(result.storagePath);
      if (!mounted) return;
      setState(() {
        _futurePhotoPath = result.storagePath;
        _futurePhotoMode = result.inputMode;
        _futurePreviewUrl = previewUrl;
      });
    } on FutureSelfSafetyRejectedException catch (error, stackTrace) {
      debugPrint('Future Self generation safety rejection: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _generationFailed = true;
          _generationSafetyRejected = true;
        });
      }
    } on FutureBodyTemplateUnavailableException catch (error, stackTrace) {
      debugPrint('Future Self body template unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _generationFailed = true;
          _generationErrorMessage =
              'A body template for Face Only mode is not available yet.';
        });
      }
    } on FutureSelfPhotoRejectedException catch (error, stackTrace) {
      debugPrint('Future Self photo validation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _generationFailed = true;
          _generationErrorMessage = error.userMessage;
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Future Self generation UI failure: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _generationFailed = true);
    } finally {
      if (mounted) setState(() => _generatingFutureSelf = false);
    }
  }

  Future<void> _removeFutureSelf() async {
    if (_removingFutureSelf || _generatingFutureSelf) return;
    setState(() => _removingFutureSelf = true);
    try {
      await _imageService.removeFutureSelfImage();
      if (!mounted) return;
      setState(() {
        _futurePhotoPath = null;
        _futurePhotoMode = null;
        _futurePreviewUrl = null;
        _generationFailed = false;
        _generationSafetyRejected = false;
        _generationErrorMessage = null;
      });
    } catch (error, stackTrace) {
      debugPrint('Future Self image removal failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage('Could not remove your Future Self image.');
    } finally {
      if (mounted) setState(() => _removingFutureSelf = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _canGenerateFutureSelf;
    _debugGenerationButtonState(canGenerate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FUTURE SELF',
          style: TextStyle(
            fontSize: 13,
            letterSpacing: 1.35,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Visualize your progress after 8 months of consistent training.',
          style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        SegmentedButton<FutureSelfInputMode>(
          emptySelectionAllowed: true,
          segments: const [
            ButtonSegment(
              value: FutureSelfInputMode.faceOnly,
              label: Text('FACE ONLY'),
            ),
            ButtonSegment(
              value: FutureSelfInputMode.fullBody,
              label: Text('FULL BODY'),
            ),
          ],
          selected: _inputMode == null ? const {} : {_inputMode!},
          onSelectionChanged: (selection) => _selectInputMode(selection.first),
        ),
        const SizedBox(height: 10),
        Text(
          _inputMode == null
              ? 'Choose how you want to create your Future Self.'
              : _inputMode == FutureSelfInputMode.faceOnly
              ? 'Use a clear face photo. Body visualization based on your profile data.'
              : 'Use a clear full-body photo in regular workout clothing. Stand naturally, face the camera, keep your arms relaxed, show your full body, use good lighting, and include one person only.',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final panels = [
              _FutureSelfVisualPanel(
                label: 'CURRENT YOU',
                imageUrl: _activeCurrentPhotoPath == null
                    ? null
                    : _currentPreviewUrl,
                imageBytes: _localCurrentPreviewBytes,
                placeholderIcon: Icons.person_outline_rounded,
                placeholderTitle: _inputMode == FutureSelfInputMode.faceOnly
                    ? 'Add a clear face photo'
                    : 'Add a clear full-body photo',
                placeholderText: _inputMode == FutureSelfInputMode.faceOnly
                    ? 'Body visualization based on your profile data.'
                    : 'Use regular workout clothing with your full body visible.',
                isLoading: false,
                errorText: null,
                actions: _savingPhoto
                    ? const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ]
                    : [
                        OutlinedButton.icon(
                          onPressed: _inputMode == null ? null : _selectPhoto,
                          icon: Icon(
                            _activeCurrentPhotoPath == null
                                ? Icons.add_photo_alternate_outlined
                                : Icons.refresh_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _activeCurrentPhotoPath == null
                                ? 'Add photo'
                                : 'Replace',
                          ),
                        ),
                        if (_activeCurrentPhotoPath != null)
                          IconButton(
                            tooltip: 'Remove current photo',
                            onPressed: _removePhoto,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                      ],
              ),
              _FutureSelfVisualPanel(
                label: 'FUTURE YOU',
                imageUrl: _activeFuturePhotoPath == null
                    ? null
                    : _futurePreviewUrl,
                imageBytes: null,
                placeholderIcon: Icons.auto_awesome_rounded,
                placeholderTitle: 'Your 8-month Future Self visualization.',
                placeholderText:
                    'Noticeable, believable progress based on your saved goal.',
                isLoading: _generatingFutureSelf && _futurePreviewUrl == null,
                errorText: _generationFailed && _futurePreviewUrl == null
                    ? _generationErrorMessage ??
                          (_generationSafetyRejected
                              ? 'This photo can\'t be used for Future Self generation.\nTry a photo in regular workout clothing.'
                              : 'Couldn\'t create your Future Self.')
                    : null,
                actions: _futurePreviewUrl == null
                    ? [
                        FilledButton.icon(
                          onPressed: _generationSafetyRejected
                              ? (_savingPhoto ? null : _selectPhoto)
                              : (canGenerate ? _generateFutureSelf : null),
                          icon: Icon(
                            _generationSafetyRejected
                                ? Icons.add_photo_alternate_outlined
                                : Icons.auto_awesome_rounded,
                            size: 18,
                          ),
                          label: Text(
                            _generationSafetyRejected
                                ? 'Choose another photo'
                                : _generationFailed
                                ? 'Try Again'
                                : 'Create My Future Self',
                          ),
                        ),
                      ]
                    : [
                        if (_generationFailed)
                          Text(
                            _generationErrorMessage ??
                                (_generationSafetyRejected
                                    ? 'This photo can\'t be used for Future Self generation.\nTry a photo in regular workout clothing.'
                                    : 'Couldn\'t create your Future Self.'),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        if (_generationSafetyRejected)
                          OutlinedButton(
                            onPressed: _savingPhoto ? null : _selectPhoto,
                            child: const Text('Choose another photo'),
                          )
                        else
                          OutlinedButton(
                            onPressed:
                                _generatingFutureSelf || _removingFutureSelf
                                ? null
                                : _generateFutureSelf,
                            child: _generatingFutureSelf
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Regenerate'),
                          ),
                        TextButton(
                          onPressed:
                              _generatingFutureSelf || _removingFutureSelf
                              ? null
                              : _removeFutureSelf,
                          child: Text(
                            _removingFutureSelf
                                ? 'Removing...'
                                : 'Remove Future Image',
                          ),
                        ),
                      ],
              ),
            ];
            if (constraints.maxWidth >= 680) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: panels[0]),
                  const SizedBox(width: 14),
                  Expanded(child: panels[1]),
                ],
              );
            }
            return Column(
              children: [panels[0], const SizedBox(height: 14), panels[1]],
            );
          },
        ),
        const SizedBox(height: 10),
        const Text(
          'AI visualization of your goal, not a predicted result.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _FutureSelfVisualPanel extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final Uint8List? imageBytes;
  final IconData placeholderIcon;
  final String placeholderTitle;
  final String placeholderText;
  final List<Widget> actions;
  final bool isLoading;
  final String? errorText;

  const _FutureSelfVisualPanel({
    required this.label,
    required this.imageUrl,
    required this.imageBytes,
    required this.placeholderIcon,
    required this.placeholderTitle,
    required this.placeholderText,
    required this.actions,
    required this.isLoading,
    required this.errorText,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 2, 4, 10),
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: ColoredBox(
              color: AppTheme.visionCard,
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      cacheWidth: 900,
                      filterQuality: FilterQuality.medium,
                    )
                  : isLoading
                  ? _loadingState()
                  : errorText != null
                  ? _errorState(errorText!)
                  : imageUrl == null
                  ? _placeholder()
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      cacheWidth: 900,
                      filterQuality: FilterQuality.medium,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                          ? child
                          : const ColoredBox(
                              color: AppTheme.visionCard,
                              child: Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                      errorBuilder: (_, _, _) => _placeholder(),
                    ),
            ),
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: actions),
        ],
      ],
    ),
  );

  Widget _placeholder() => ColoredBox(
    color: AppTheme.visionCard,
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(placeholderIcon, color: AppTheme.primaryGreen, size: 18),
          const SizedBox(height: 8),
          Text(
            placeholderTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            placeholderText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _loadingState() => const ColoredBox(
    color: AppTheme.visionCard,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: 12),
          Text(
            'Creating your future self...',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    ),
  );

  Widget _errorState(String message) => ColoredBox(
    color: AppTheme.visionCard,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
    ),
  );
}

class _Surface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Surface({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class _Eyebrow extends StatelessWidget {
  final String text;
  final bool light;
  const _Eyebrow(this.text, {this.light = false});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: light ? const Color(0xFFBDE8D7) : AppTheme.primaryGreen,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    ),
  );
}

class _HeroContext extends StatelessWidget {
  final String label;
  final String value;

  const _HeroContext({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFFBDE8D7),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
      const SizedBox(height: 7),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          height: 1.25,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _JourneyFact extends StatelessWidget {
  final String label;
  final String value;
  const _JourneyFact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 9,
          letterSpacing: 1,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.cloud_off_outlined,
            color: AppTheme.textSecondary,
            size: 36,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
