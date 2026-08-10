import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/my_foundation_screen.dart';
import 'package:future_project/theme/app_theme.dart';

class TodaysCoachScreen extends StatefulWidget {
  const TodaysCoachScreen({super.key});

  @override
  State<TodaysCoachScreen> createState() =>
      _TodaysCoachScreenState();
}

class _TodaysCoachScreenState
    extends State<TodaysCoachScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic>? _foundation;

  final TextEditingController _questionController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFoundation();
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _loadFoundation() async {
    final SupabaseClient supabase =
        Supabase.instance.client;

    final User? user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Please sign in to use Today’s Coach.';
      });

      return;
    }

    try {
      final Map<String, dynamic>? row =
          await supabase
              .from('user_foundations')
              .select()
              .eq('user_id', user.id)
              .maybeSingle();

      if (!mounted) return;

      setState(() {
        _foundation = row;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load your Foundation.';
      });
    }
  }

  bool get _foundationCompleted {
    return _foundation?['is_completed'] == true;
  }

  Map<String, dynamic> get _lifestyle {
    return _asMap(
      _foundation?['lifestyle'],
    );
  }

  Map<String, dynamic> get _nutrition {
    return _asMap(
      _foundation?['nutrition'],
    );
  }

  Map<String, dynamic> _asMap(
    dynamic value,
  ) {
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

  String _value(
    Map<String, dynamic> source,
    String key, {
    String fallback = 'Not set',
  }) {
    final dynamic raw = source[key];

    if (raw == null) {
      return fallback;
    }

    final String text =
        raw.toString().trim();

    if (text.isEmpty) {
      return fallback;
    }

    return text;
  }

  String get _goal {
    return _foundation?['primary_goal']
            ?.toString() ??
        'improve_health';
  }

  String get _goalLabel {
    switch (_goal) {
      case 'lose_fat':
        return 'Lose Fat';

      case 'build_muscle':
        return 'Build Muscle';

      case 'maintain_weight':
        return 'Maintain Weight';

      case 'improve_fitness':
        return 'Improve Fitness';

      case 'athletic_performance':
        return 'Athletic Performance';

      default:
        return 'Improve Health';
    }
  }

  String get _greeting {
    final int hour =
        DateTime.now().hour;

    if (hour < 12) {
      return 'Good morning';
    }

    if (hour < 18) {
      return 'Good afternoon';
    }

    return 'Good evening';
  }

  String get _morningBrief {
    final String sleepQuality =
        _value(
      _lifestyle,
      'sleep_quality',
    );

    final String stress =
        _value(
      _lifestyle,
      'stress',
    );

    return 'Your current goal is $_goalLabel. '
        'Your usual sleep quality is $sleepQuality '
        'and your daily stress is $stress. '
        'Today, keep your attention on the few things '
        'that matter most.';
  }

  String get _todayPriority {
    final String obstacle =
        _value(
      _lifestyle,
      'obstacle',
      fallback: '',
    );

    if (obstacle == 'Lack of Time' ||
        obstacle == 'Busy Schedule') {
      return 'Protect one realistic block of time '
          'for your health today.';
    }

    if (obstacle == 'Low Energy') {
      return 'Keep today simple. Prioritize movement, '
          'hydration, and recovery.';
    }

    switch (_goal) {
      case 'build_muscle':
        return 'Make your planned training the main '
            'physical priority today.';

      case 'lose_fat':
        return 'Keep meals structured and stay active '
            'without trying to make the day perfect.';

      case 'athletic_performance':
        return 'Prioritize training quality and recovery '
            'today.';

      case 'improve_fitness':
        return 'Get one meaningful block of movement '
            'into your day.';

      case 'maintain_weight':
        return 'Stay consistent with your normal healthy '
            'routine today.';

      default:
        return 'Keep the basics steady today: movement, '
            'nutrition, hydration, and recovery.';
    }
  }

  List<_DailySignal> get _dailySignals {
    final String workoutTime =
        _value(
      _lifestyle,
      'workout_time',
    );

    final String water =
        _value(
      _lifestyle,
      'water',
    );

    final String sleep =
        _value(
      _lifestyle,
      'sleep_hours',
    );

    final String nutritionStyle =
        _value(
      _nutrition,
      'eating_style',
    );

    return [
      _DailySignal(
        icon:
            Icons.fitness_center_outlined,
        title: 'Training',
        text: workoutTime == 'Not set'
            ? 'Keep your planned movement on the calendar.'
            : 'Preferred training time: $workoutTime',
      ),
      _DailySignal(
        icon:
            Icons.water_drop_outlined,
        title: 'Hydration',
        text: water == 'Not set'
            ? 'Keep water available throughout the day.'
            : 'Usual intake: $water',
      ),
      _DailySignal(
        icon:
            Icons.bedtime_outlined,
        title: 'Recovery',
        text: sleep == 'Not set'
            ? 'Protect your sleep window tonight.'
            : 'Usual sleep: $sleep',
      ),
      _DailySignal(
        icon:
            Icons.restaurant_menu_outlined,
        title: 'Nutrition',
        text: nutritionStyle ==
                'Not set'
            ? 'Keep meals simple and consistent.'
            : 'Current eating style: $nutritionStyle',
      ),
    ];
  }

  String? get _smartReminder {
    final String water =
        _value(
      _lifestyle,
      'water',
      fallback: '',
    );

    final String sleep =
        _value(
      _lifestyle,
      'sleep_hours',
      fallback: '',
    );

    if (water == 'Less than 1 L') {
      return 'Hydration may need a little more attention today.';
    }

    if (sleep ==
            'Less than 5 Hours' ||
        sleep == '5–6 Hours') {
      return 'Recovery may need extra attention today.';
    }

    return null;
  }

  Future<void> _openFoundation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const MyFoundationScreen(),
      ),
    );

    if (!mounted) return;

    await _loadFoundation();
  }

  void _askCoach() {
    final String question =
        _questionController.text
            .trim();

    if (question.isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      const SnackBar(
        content: Text(
          'AI responses will be connected in the next step.',
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Today’s Coach',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        backgroundColor:
            AppTheme.background,
        foregroundColor:
            AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(
            24,
          ),
          child: Text(
            _errorMessage!,
            textAlign:
                TextAlign.center,
            style: const TextStyle(
              color:
                  AppTheme.textSecondary,
            ),
          ),
        ),
      );
    }

    if (!_foundationCompleted) {
      return _buildFoundationRequired();
    }

    return RefreshIndicator(
      onRefresh:
          _loadFoundation,
      child: ListView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.fromLTRB(
          24,
          16,
          24,
          32,
        ),
        children: [
          Text(
            _greeting,
            style:
                const TextStyle(
              fontSize: 30,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppTheme.textPrimary,
            ),
          ),

          const SizedBox(
            height: 24,
          ),

          _CoachCard(
            icon:
                Icons.wb_sunny_outlined,
            title:
                'Morning Brief',
            text: _morningBrief,
          ),

          const SizedBox(
            height: 16,
          ),

          _CoachCard(
            icon: Icons
                .center_focus_strong_outlined,
            title:
                'Today’s Priority',
            text:
                _todayPriority,
            highlighted: true,
          ),

          if (_smartReminder != null) ...[
            const SizedBox(
              height: 16,
            ),

            _CoachCard(
              icon: Icons
                  .notifications_active_outlined,
              title:
                  'Smart Reminder',
              text:
                  _smartReminder!,
            ),
          ],

          const SizedBox(
            height: 28,
          ),

          const Text(
            'Today at a Glance',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppTheme.textPrimary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'A quick coordination of the parts of your day that matter.',
            style: TextStyle(
              fontSize: 14,
              color:
                  AppTheme.textSecondary,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          ..._dailySignals.map(
            (signal) =>
                Padding(
              padding:
                  const EdgeInsets.only(
                bottom: 12,
              ),
              child:
                  _DailySignalCard(
                signal: signal,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            'Ask Today’s Coach',
            style: TextStyle(
              fontSize: 22,
              fontWeight:
                  FontWeight.w800,
              color:
                  AppTheme.textPrimary,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          const Text(
            'Ask a simple question about today’s health, routine, or priorities.',
            style: TextStyle(
              fontSize: 14,
              color:
                  AppTheme.textSecondary,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          _buildQuestionBox(),

          const SizedBox(
            height: 28,
          ),

          _buildEveningWrapUp(),
        ],
      ),
    );
  }

  Widget _buildFoundationRequired() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons
                  .account_tree_outlined,
              size: 58,
              color:
                  AppTheme.primaryGreen,
            ),

            const SizedBox(
              height: 18,
            ),

            const Text(
              'Complete My Foundation first',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight:
                    FontWeight.w800,
                color:
                    AppTheme.textPrimary,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            const Text(
              'Today’s Coach uses your Foundation to understand your goals and daily context.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                height: 1.5,
                color:
                    AppTheme.textSecondary,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            FilledButton(
              onPressed:
                  _openFoundation,
              child: const Text(
                'Open My Foundation',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionBox() {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller:
                  _questionController,
              textInputAction:
                  TextInputAction.send,
              onSubmitted: (_) {
                _askCoach();
              },
              decoration:
                  const InputDecoration(
                hintText:
                    'What should I focus on today?',
                border:
                    InputBorder.none,
              ),
            ),
          ),

          IconButton.filled(
            onPressed:
                _askCoach,
            icon: const Icon(
              Icons.arrow_upward,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEveningWrapUp() {
    final bool evening =
        DateTime.now().hour >= 18;

    return _CoachCard(
      icon:
          Icons.nights_stay_outlined,
      title:
          'Evening Wrap-up',
      text: evening
          ? 'Take a quick look at what went well, what got in the way, and what may deserve attention tomorrow.'
          : 'A very short end-of-day reflection will appear here this evening.',
    );
  }
}

class _CoachCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final bool highlighted;

  const _CoachCard({
    required this.icon,
    required this.title,
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration: BoxDecoration(
        color: highlighted
            ? AppTheme.calorieCard
            : AppTheme.card,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: highlighted
              ? AppTheme.primaryGreen
                  .withValues(
                    alpha: 0.35,
                  )
              : AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color:
                AppTheme.primaryGreen,
            size: 28,
          ),

          const SizedBox(
            width: 15,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize: 18,
                    fontWeight:
                        FontWeight.w800,
                    color: AppTheme
                        .textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  text,
                  style:
                      const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme
                        .textSecondary,
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

class _DailySignal {
  final IconData icon;
  final String title;
  final String text;

  const _DailySignal({
    required this.icon,
    required this.title,
    required this.text,
  });
}

class _DailySignalCard
    extends StatelessWidget {
  final _DailySignal signal;

  const _DailySignalCard({
    required this.signal,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            signal.icon,
            color:
                AppTheme.primaryGreen,
          ),

          const SizedBox(
            width: 14,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.w700,
                    color: AppTheme
                        .textPrimary,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  signal.text,
                  style:
                      const TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: AppTheme
                        .textSecondary,
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