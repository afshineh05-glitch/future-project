import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/my_foundation_screen.dart';
import 'package:future_project/theme/app_theme.dart';

class TodayCoachState {
  final String morningBrief;
  final String priority;
  final String? reminder;
  final String eveningWrapUp;

  const TodayCoachState({
    required this.morningBrief,
    required this.priority,
    required this.reminder,
    required this.eveningWrapUp,
  });
}

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
  TodayCoachState? _todayState;

  bool _isSendingQuestion = false;
  String? _lastQuestion;
  String? _lastAnswer;

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
    final SupabaseClient supabase = Supabase.instance.client;
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
      final Map<String, dynamic>? row = await supabase
          .from('user_foundations')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _foundation = row;
        _todayState =
            row == null ? null : _buildTodayState(row);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _foundation = null;
        _todayState = null;
        _errorMessage =
            'Could not load your Foundation.';
      });
    }
  }

  bool get _foundationCompleted =>
      _foundation?['is_completed'] == true;

  Map<String, dynamic> get _lifestyle =>
      _asMap(_foundation?['lifestyle']);

  Map<String, dynamic> get _nutrition =>
      _asMap(_foundation?['nutrition']);

  Map<String, dynamic> _asMap(dynamic value) {
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

  String _textValue(
    Map<String, dynamic> map,
    String key, {
    String fallback = 'Not set',
  }) {
    final dynamic value = map[key];

    if (value == null) return fallback;

    final String text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _goalLabelFor(String goal) {
    switch (goal) {
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

  TodayCoachState _buildTodayState(
    Map<String, dynamic> foundation,
  ) {
    final Map<String, dynamic> lifestyle =
        _asMap(foundation['lifestyle']);

    final String goal =
        foundation['primary_goal']?.toString() ??
        'improve_health';

    final String goalLabel = _goalLabelFor(goal);

    final String sleepQuality =
        _textValue(
      lifestyle,
      'sleep_quality',
    );

    final String sleepHours =
        _textValue(
      lifestyle,
      'sleep_hours',
    );

    final String stress =
        _textValue(
      lifestyle,
      'stress',
    );

    final String obstacle =
        _textValue(
      lifestyle,
      'obstacle',
      fallback: '',
    );

    String priority;

    if (obstacle == 'Lack of Time' ||
        obstacle == 'Busy Schedule') {
      priority =
          'Protect one realistic block of time for your health today.';
    } else if (obstacle == 'Low Energy') {
      priority =
          'Keep today simple. Prioritize movement, hydration, and recovery.';
    } else {
      switch (goal) {
        case 'build_muscle':
          priority =
              'Make your planned training the main physical priority today.';
          break;
        case 'lose_fat':
          priority =
              'Keep meals structured and stay active without chasing perfection.';
          break;
        case 'athletic_performance':
          priority =
              'Prioritize training quality and recovery today.';
          break;
        case 'improve_fitness':
          priority =
              'Get one meaningful block of movement into your day.';
          break;
        case 'maintain_weight':
          priority =
              'Stay consistent with your normal healthy routine today.';
          break;
        default:
          priority =
              'Keep the basics steady today: movement, nutrition, hydration, and recovery.';
      }
    }

    String? reminder;

    if (sleepHours == 'Less than 5 Hours' ||
        sleepHours == '5–6 Hours') {
      reminder =
          'Recovery may need extra attention today.';
    } else if (stress == 'High' ||
        stress == 'Very High') {
      reminder =
          'Your stress is usually high. Keep today realistic.';
    }

    final String morningBrief;

    if (sleepQuality != 'Not set' &&
        stress != 'Not set') {
      morningBrief =
          'Your current goal is $goalLabel. '
          'Your usual sleep quality is $sleepQuality '
          'and your daily stress is $stress. '
          'Today, keep your attention on the few things that matter most.';
    } else {
      morningBrief =
          'Your current goal is $goalLabel. '
          'Today’s Coach will keep the day simple and point you toward the highest-value actions.';
    }

    return TodayCoachState(
      morningBrief: morningBrief,
      priority: priority,
      reminder: reminder,
      eveningWrapUp:
          'Take a quick look at what went well, '
          'what got in the way, and what may deserve attention tomorrow.',
    );
  }

  List<_DailySignal> get _signals {
    final String workoutTime =
        _textValue(_lifestyle, 'workout_time');
    final String water =
        _textValue(_lifestyle, 'water');
    final String sleepHours =
        _textValue(_lifestyle, 'sleep_hours');
    final String eatingStyle =
        _textValue(_nutrition, 'eating_style');

    return <_DailySignal>[
      _DailySignal(
        icon: Icons.fitness_center_outlined,
        title: 'Training',
        value: workoutTime == 'Not set'
            ? 'Keep your planned movement on the calendar.'
            : 'Preferred time: $workoutTime',
      ),
      _DailySignal(
        icon: Icons.water_drop_outlined,
        title: 'Hydration',
        value: water == 'Not set'
            ? 'Keep water available throughout the day.'
            : 'Usual intake: $water',
      ),
      _DailySignal(
        icon: Icons.bedtime_outlined,
        title: 'Recovery',
        value: sleepHours == 'Not set'
            ? 'Protect your sleep window tonight.'
            : 'Usual sleep: $sleepHours',
      ),
      _DailySignal(
        icon: Icons.restaurant_menu_outlined,
        title: 'Nutrition',
        value: eatingStyle == 'Not set'
            ? 'Keep meals simple and consistent.'
            : 'Current style: $eatingStyle',
      ),
    ];
  }

  String get _timeGreeting {
    final int hour = DateTime.now().hour;

    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  String get _dateLabel {
    final DateTime now = DateTime.now();

    const List<String> weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${weekdays[now.weekday - 1]}, '
        '${months[now.month - 1]} ${now.day}';
  }

  Future<void> _openFoundation() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MyFoundationScreen(),
      ),
    );

    if (!mounted) return;
    await _loadFoundation();
  }

  Future<void> _submitQuestion() async {
    final String question =
        _questionController.text.trim();

    if (question.isEmpty || _isSendingQuestion) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isSendingQuestion = true;
      _lastQuestion = question;
      _lastAnswer = null;
    });

    try {
      final FunctionResponse response =
          await Supabase.instance.client.functions.invoke(
        'todays-coach',
        body: <String, dynamic>{
          'question': question,
          'foundation': _foundation ?? <String, dynamic>{},
          'dailyContext': <String, dynamic>{
            'morningBrief': _todayState?.morningBrief,
            'priority': _todayState?.priority,
            'reminder': _todayState?.reminder,
            'eveningWrapUp': _todayState?.eveningWrapUp,
          },
        },
      );

      final dynamic data = response.data;

      String answer;

      if (data is Map && data['answer'] != null) {
        answer = data['answer'].toString().trim();

        // The backend intentionally returns a normal coach message even when
        // a request is blocked as out-of-scope. Always surface that message in
        // the chat instead of replacing it with a generic snackbar/error.
        if (data['allowed'] == false && answer.isEmpty) {
          answer =
              'Today’s Coach is designed specifically for fitness and health. '
              'I can help with training, recovery, nutrition, hydration, sleep, '
              'and fitness progress.';
        }
      } else if (data is Map && data['error'] != null) {
        throw Exception(data['error'].toString());
      } else {
        throw Exception(
          'Today’s Coach returned an invalid response.',
        );
      }

      if (answer.isEmpty) {
        throw Exception(
          'Today’s Coach returned an empty response.',
        );
      }

      if (!mounted) return;

      setState(() {
        _lastAnswer = answer;
        _isSendingQuestion = false;
      });

      _questionController.clear();
    } on FunctionException catch (error) {
      if (!mounted) return;

      setState(() {
        _isSendingQuestion = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Today’s Coach could not answer: '
            '${error.details ?? error.reasonPhrase ?? error.status}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isSendingQuestion = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not reach Today’s Coach: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Today’s Coach',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (!_foundationCompleted) {
      return _buildFoundationRequiredState();
    }

    if (_todayState == null) {
      return _buildErrorState(
        message:
            'Could not prepare Today’s Coach for this Foundation.',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFoundation,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          24,
          16,
          24,
          32,
        ),
        children: <Widget>[
          _buildHeader(),
          const SizedBox(height: 22),
          _buildMorningBrief(),
          const SizedBox(height: 18),
          _buildPriorityCard(),

          if (_todayState!.reminder != null) ...[
            const SizedBox(height: 18),
            _buildReminderCard(),
          ],

          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Daily Signals',
            subtitle:
                'A quick read across the parts of your day that matter.',
          ),
          const SizedBox(height: 14),
          _buildSignals(),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Ask Today’s Coach',
            subtitle:
                'Ask about fitness, training, recovery, nutrition, hydration, sleep, or fitness progress.',
          ),
          const SizedBox(height: 14),
          _buildAskCoach(),
          const SizedBox(height: 28),
          const _SectionTitle(
            title: 'Evening Wrap-up',
            subtitle:
                'A light check-in, not another task list.',
          ),
          const SizedBox(height: 14),
          _buildEveningWrapUp(),
        ],
      ),
    );
  }

  Widget _buildErrorState({
    String? message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 54,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 14),
            Text(
              message ?? _errorMessage ?? 'Something went wrong.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _loadFoundation,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoundationRequiredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(
            maxWidth: 720,
          ),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.card,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: AppTheme.calorieCard,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppTheme.primaryGreen,
                  size: 34,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Finish My Foundation first',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Today’s Coach needs your Foundation before it can give useful daily guidance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: _openFoundation,
                icon: const Icon(
                  Icons.account_tree_outlined,
                ),
                label: const Text(
                  'Open My Foundation',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _timeGreeting,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          _dateLabel,
          style: const TextStyle(
            fontSize: 15,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildMorningBrief() {
    return _CoachCard(
      icon: Icons.wb_sunny_outlined,
      title: 'Morning Brief',
      child: Text(
        _todayState!.morningBrief,
        style: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildPriorityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.calorieCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.primaryGreen.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.center_focus_strong_outlined,
            color: AppTheme.primaryGreen,
            size: 30,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today’s Priority',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _todayState!.priority,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard() {
    return _CoachCard(
      icon: Icons.notifications_active_outlined,
      title: 'Smart Reminder',
      child: Text(
        _todayState!.reminder!,
        style: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Widget _buildSignals() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final bool twoColumns =
            constraints.maxWidth >= 800;

        if (!twoColumns) {
          return Column(
            children: _signals
                .map(
                  (signal) => Padding(
                    padding:
                        const EdgeInsets.only(
                      bottom: 12,
                    ),
                    child: _DailySignalCard(
                      signal: signal,
                    ),
                  ),
                )
                .toList(),
          );
        }

        return Wrap(
          spacing: 14,
          runSpacing: 14,
          children: _signals
              .map(
                (signal) => SizedBox(
                  width:
                      (constraints.maxWidth - 14) / 2,
                  child: _DailySignalCard(
                    signal: signal,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAskCoach() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_lastQuestion != null) ...[
            _ChatBubble(
              label: 'You',
              text: _lastQuestion!,
              isCoach: false,
            ),
            const SizedBox(height: 10),
          ],
          if (_isSendingQuestion) ...[
            const _CoachThinkingBubble(),
            const SizedBox(height: 10),
          ] else if (_lastAnswer != null) ...[
            _ChatBubble(
              label: 'Today’s Coach',
              text: _lastAnswer!,
              isCoach: true,
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _questionController,
                  enabled: !_isSendingQuestion,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (!_isSendingQuestion) {
                      _submitQuestion();
                    }
                  },
                  decoration: const InputDecoration(
                    hintText:
                        'What should I focus on today?',
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filled(
                onPressed:
                    _isSendingQuestion ? null : _submitQuestion,
                icon: _isSendingQuestion
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                        ),
                      )
                    : const Icon(
                        Icons.arrow_upward,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEveningWrapUp() {
    final bool evening =
        DateTime.now().hour >= 18;

    return _CoachCard(
      icon: Icons.nights_stay_outlined,
      title: evening
          ? 'How did today go?'
          : 'Check back this evening',
      child: Text(
        evening
            ? _todayState!.eveningWrapUp
            : 'At the end of the day, Today’s Coach will help you make a quick reflection without turning it into another long form.',
        style: const TextStyle(
          fontSize: 15,
          height: 1.55,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String label;
  final String text;
  final bool isCoach;

  const _ChatBubble({
    required this.label,
    required this.text,
    required this.isCoach,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment:
          isCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 760,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCoach
              ? AppTheme.calorieCard
              : AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isCoach
                ? AppTheme.primaryGreen.withValues(alpha: 0.25)
                : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: isCoach
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              text,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachThinkingBubble extends StatelessWidget {
  const _CoachThinkingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: AppTheme.calorieCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.primaryGreen.withValues(
              alpha: 0.25,
            ),
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Today’s Coach is thinking...',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 14,
            height: 1.45,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CoachCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _CoachCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.calorieCard,
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 13),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DailySignal {
  final IconData icon;
  final String title;
  final String value;

  const _DailySignal({
    required this.icon,
    required this.title,
    required this.value,
  });
}

class _DailySignalCard extends StatelessWidget {
  final _DailySignal signal;

  const _DailySignalCard({
    required this.signal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.calorieCard,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              signal.icon,
              color: AppTheme.primaryGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  signal.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  signal.value,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: AppTheme.textSecondary,
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