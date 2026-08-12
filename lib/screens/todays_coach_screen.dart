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
  String? _smartPriority;
  bool _isPriorityLoading = false;

  String? _smartMorningBrief;
  bool _isMorningBriefLoading = false;

  bool _isSendingQuestion = false;
  String? _lastQuestion;
  String? _lastAnswer;

  String? _wrapUpStatus;
  bool _isWrapUpLoading = false;
  bool _isWrapUpSaving = false;
  bool _wrapUpSavedToday = false;

  final TextEditingController _questionController =
      TextEditingController();

  final TextEditingController _wrapUpNoteController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFoundation();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _wrapUpNoteController.dispose();
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

      final bool shouldLoadPriority =
          row != null && row['is_completed'] == true;

      setState(() {
        _foundation = row;
        _todayState =
            row == null ? null : _buildTodayState(row);
        _smartPriority = null;
        _isPriorityLoading = shouldLoadPriority;
        _smartMorningBrief = null;
        _isMorningBriefLoading = shouldLoadPriority;
        _isLoading = false;
        _errorMessage = null;
      });

      if (shouldLoadPriority) {
        await Future.wait<void>([
          _loadSmartPriority(),
          _loadSmartMorningBrief(),
          _loadTodayWrapUp(),
        ]);
      }
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _foundation = null;
        _todayState = null;
        _smartPriority = null;
        _isPriorityLoading = false;
        _smartMorningBrief = null;
        _isMorningBriefLoading = false;
        _wrapUpStatus = null;
        _wrapUpNoteController.clear();
        _isWrapUpLoading = false;
        _isWrapUpSaving = false;
        _wrapUpSavedToday = false;
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

  bool _containsContextText(
    dynamic value,
    List<String> terms,
  ) {
    if (value == null) return false;

    if (value is Map) {
      for (final dynamic entryValue in value.values) {
        if (_containsContextText(entryValue, terms)) {
          return true;
        }
      }
      return false;
    }

    if (value is Iterable) {
      for (final dynamic item in value) {
        if (_containsContextText(item, terms)) {
          return true;
        }
      }
      return false;
    }

    final String normalized =
        value.toString().trim().toLowerCase();

    return terms.any(
      (String term) =>
          normalized.contains(term.toLowerCase()),
    );
  }

  String _nutritionStyle(
    Map<String, dynamic> nutrition,
    Map<String, dynamic> foundation,
  ) {
    final String nested =
        _textValue(
      nutrition,
      'eating_style',
      fallback: '',
    );

    if (nested.isNotEmpty) {
      return nested;
    }

    final dynamic topLevel =
        foundation['diet_preference'];

    return topLevel?.toString().trim() ?? '';
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

    final Map<String, dynamic> nutrition =
        _asMap(foundation['nutrition']);

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

    final String workoutTime =
        _textValue(
      lifestyle,
      'workout_time',
      fallback: '',
    );

    final String eatingStyle =
        _nutritionStyle(
      nutrition,
      foundation,
    );

    final String nutritionChallenge =
        _textValue(
      nutrition,
      'nutrition_challenge',
      fallback: '',
    );

    final bool limitedSleep =
        sleepHours == 'Less than 5 Hours' ||
        sleepHours == '5–6 Hours';

    final bool highStress =
        stress == 'High' ||
        stress == 'Very High';

    // This intentionally scans existing Foundation data rather than depending
    // on one exact field name. If fasting is stored later in Foundation or a
    // connected nutrition context, Today’s Priority can recognize it without
    // needing another UI card or a hardcoded one-field dependency.
    final bool fastingContext =
        _containsContextText(
      foundation,
      <String>[
        'fasting',
        'intermittent fast',
        'intermittent fasting',
        'time restricted eating',
        'time-restricted eating',
        'ramadan',
      ],
    );

    final bool ketoContext =
        eatingStyle.toLowerCase() == 'keto' ||
        _containsContextText(
          nutrition,
          <String>['keto', 'ketogenic'],
        );

    final bool lowCarbContext =
        eatingStyle.toLowerCase() == 'low carb' ||
        _containsContextText(
          nutrition,
          <String>['low carb', 'low-carb'],
        );

    final bool highProteinContext =
        eatingStyle.toLowerCase() == 'high protein' ||
        _containsContextText(
          nutrition,
          <String>['high protein', 'high-protein'],
        );

    final bool vegetarianContext =
        eatingStyle.toLowerCase() == 'vegetarian';

    final bool veganContext =
        eatingStyle.toLowerCase() == 'vegan';

    final bool pescatarianContext =
        eatingStyle.toLowerCase() == 'pescatarian';

    String priority;

    // Today’s Priority returns ONE main focus.
    // It respects recovery first, then established routines/restrictions,
    // then consistency obstacles, then the primary fitness goal.
    //
    // It never invents a workout or meal plan.

    if (limitedSleep) {
      if (fastingContext) {
        priority =
            'Protect recovery today while staying within your fasting routine. Keep your existing plan realistic and avoid forcing a high-demand day on limited sleep.';
      } else {
        priority =
            'Protect recovery today. Keep your effort realistic and avoid turning a low-sleep day into a high-demand day.';
      }
    } else if (highStress) {
      if (fastingContext) {
        priority =
            'Keep today controlled and stay consistent with your fasting routine. Focus on one meaningful health action instead of trying to do everything.';
      } else {
        priority =
            'Keep today controlled and consistent. Focus on one meaningful health action instead of trying to do everything.';
      }
    } else if (fastingContext) {
      priority = workoutTime.isEmpty
          ? 'Stay consistent with your fasting window today and organize your existing training and nutrition routine around it.'
          : 'Stay consistent with your fasting window and protect your $workoutTime training time. Keep both parts of your existing routine working together.';
    } else if (ketoContext) {
      priority =
          'Stay consistent with your keto routine today. Keep your food choices aligned with the eating pattern you already chose instead of making unnecessary changes.';
    } else if (lowCarbContext) {
      priority =
          'Stay consistent with your low-carb routine today. Keep your nutrition aligned with the approach you already chose.';
    } else if (highProteinContext) {
      if (goal == 'build_muscle') {
        priority = workoutTime.isEmpty
            ? 'Keep protein consistency and your planned training aligned today. Execute the routine you already have instead of adding more.'
            : 'Protect your $workoutTime training time and keep your high-protein routine consistent around it.';
      } else {
        priority =
            'Keep your high-protein routine consistent today and make it fit naturally into the rest of your existing plan.';
      }
    } else if (veganContext) {
      priority =
          'Keep today aligned with your vegan eating pattern and your current fitness goal. Consistency with the plan you already chose is the priority.';
    } else if (vegetarianContext) {
      priority =
          'Keep today aligned with your vegetarian eating pattern and your current fitness goal. Stay consistent rather than changing the plan unnecessarily.';
    } else if (pescatarianContext) {
      priority =
          'Keep today aligned with your pescatarian eating pattern and your current fitness goal. Consistency is the priority.';
    } else if (nutritionChallenge == 'Cravings') {
      priority =
          'Keep today structured around your normal meals and avoid letting cravings decide the direction of the day.';
    } else if (nutritionChallenge == 'Snacking') {
      priority =
          'Keep your eating structured today and avoid unnecessary snacking between the meals you already planned.';
    } else if (nutritionChallenge == 'Portion Control') {
      priority =
          'Keep portions intentional today and stay aligned with your existing nutrition routine.';
    } else if (nutritionChallenge == 'Eating Out Too Often') {
      priority =
          'Keep today close to your normal nutrition routine and avoid letting convenience replace the plan you already chose.';
    } else if (obstacle == 'Lack of Time' ||
        obstacle == 'Busy Schedule') {
      priority = workoutTime.isEmpty
          ? 'Protect one realistic block of time for your health today and treat it as non-negotiable.'
          : 'Protect your $workoutTime health block today. Keep that time clear and make consistency the priority.';
    } else if (obstacle == 'Low Energy') {
      priority =
          'Keep today simple and achievable. Consistency matters more than forcing a perfect day.';
    } else {
      switch (goal) {
        case 'build_muscle':
          priority = workoutTime.isEmpty
              ? 'Make your planned training the main physical priority today. Execute the plan instead of adding more.'
              : 'Protect your $workoutTime training time today. Execute your existing plan and make that the main physical priority.';
          break;

        case 'lose_fat':
          priority =
              'Keep today structured and consistent. Stay active and keep your existing nutrition approach aligned with your fat-loss goal.';
          break;

        case 'athletic_performance':
          priority = workoutTime.isEmpty
              ? 'Prioritize the quality of today’s planned work. Focus on execution rather than doing extra.'
              : 'Protect your $workoutTime training window and focus on quality execution rather than adding extra work.';
          break;

        case 'improve_fitness':
          priority = workoutTime.isEmpty
              ? 'Complete one meaningful block of planned movement today. Consistency is the win.'
              : 'Protect your $workoutTime activity window and complete the movement you already planned.';
          break;

        case 'maintain_weight':
          priority =
              'Keep your normal healthy routine steady today. There is no need to overcorrect when consistency is already the goal.';
          break;

        default:
          priority =
              'Choose one meaningful action that supports your health today and complete it consistently.';
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

  Future<void> _loadSmartMorningBrief() async {
    if (_foundation == null || _todayState == null) {
      if (mounted) {
        setState(() {
          _isMorningBriefLoading = false;
        });
      }
      return;
    }

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

    try {
      final FunctionResponse response =
          await Supabase.instance.client.functions.invoke(
        'todays-coach',
        body: <String, dynamic>{
          'action': 'generate_morning_brief',
          'dailyContext': <String, dynamic>{
            'localDate':
                '${now.year.toString().padLeft(4, '0')}-'
                '${now.month.toString().padLeft(2, '0')}-'
                '${now.day.toString().padLeft(2, '0')}',
            'localHour': now.hour,
            'weekday': weekdays[now.weekday - 1],
          },
        },
      );

      final dynamic data = response.data;

      if (data is Map &&
          data['morningBrief'] != null) {
        final String value =
            data['morningBrief'].toString().trim();

        if (value.isNotEmpty && mounted) {
          setState(() {
            _smartMorningBrief = value;
          });
        }
      }
    } catch (error) {
      debugPrint(
        'Smart Morning Brief fallback used: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMorningBriefLoading = false;
        });
      }
    }
  }

  Future<void> _loadSmartPriority() async {
    if (_foundation == null || _todayState == null) {
      if (mounted) {
        setState(() {
          _isPriorityLoading = false;
        });
      }
      return;
    }

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

    try {
      final FunctionResponse response =
          await Supabase.instance.client.functions.invoke(
        'todays-coach',
        body: <String, dynamic>{
          'action': 'generate_priority',
          'dailyContext': <String, dynamic>{
            'localDate':
                '${now.year.toString().padLeft(4, '0')}-'
                '${now.month.toString().padLeft(2, '0')}-'
                '${now.day.toString().padLeft(2, '0')}',
            'localHour': now.hour,
            'weekday': weekdays[now.weekday - 1],
            'priority': _todayState!.priority,
          },
        },
      );

      final dynamic data = response.data;

      if (data is Map && data['priority'] != null) {
        final String value =
            data['priority'].toString().trim();

        if (value.isNotEmpty && mounted) {
          setState(() {
            _smartPriority = value;
          });
        }
      }
    } catch (error) {
      // If the AI/cache request fails, the local rule-based priority remains
      // available as a safe fallback after loading finishes.
      debugPrint(
        'Smart Priority fallback used: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPriorityLoading = false;
        });
      }
    }
  }

  String get _todayDatabaseDate {
    final DateTime now = DateTime.now();

    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadTodayWrapUp() async {
    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) return;

    if (mounted) {
      setState(() {
        _isWrapUpLoading = true;
      });
    }

    try {
      final Map<String, dynamic>? row = await supabase
          .from('coach_daily_history')
          .select(
            'wrap_up_status, wrap_up_note',
          )
          .eq('user_id', user.id)
          .eq('day', _todayDatabaseDate)
          .maybeSingle();

      if (!mounted) return;

      final String? status =
          row?['wrap_up_status']?.toString();

      final String note =
          row?['wrap_up_note']?.toString() ?? '';

      setState(() {
        _wrapUpStatus =
            status == null || status.trim().isEmpty
                ? null
                : status.trim();
        _wrapUpNoteController.text = note;
        _wrapUpSavedToday = row != null;
        _isWrapUpLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isWrapUpLoading = false;
      });

      debugPrint(
        'Could not load today wrap-up: $error',
      );
    }
  }

  Future<void> _saveEveningWrapUp() async {
    if (_wrapUpStatus == null || _isWrapUpSaving) {
      return;
    }

    final SupabaseClient supabase = Supabase.instance.client;
    final User? user = supabase.auth.currentUser;

    if (user == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in to save your wrap-up.',
          ),
        ),
      );
      return;
    }

    final bool wasAlreadySaved =
        _wrapUpSavedToday;

    setState(() {
      _isWrapUpSaving = true;
    });

    final String note =
        _wrapUpNoteController.text.trim();

    try {
      await supabase
          .from('coach_daily_history')
          .upsert(
        <String, dynamic>{
          'user_id': user.id,
          'day': _todayDatabaseDate,
          'wrap_up_status': _wrapUpStatus,
          'wrap_up_note':
              note.isEmpty ? null : note,
          'updated_at':
              DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'user_id,day',
      );

      if (!mounted) return;

      setState(() {
        _isWrapUpSaving = false;
        _wrapUpSavedToday = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAlreadySaved
                ? 'Evening wrap-up updated.'
                : 'Evening wrap-up saved.',
          ),
        ),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;

      setState(() {
        _isWrapUpSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save wrap-up: ${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isWrapUpSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not save wrap-up: $error',
          ),
        ),
      );
    }
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
      child: _isMorningBriefLoading
          ? const Row(
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
                  'Preparing your morning brief...',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            )
          : Text(
              _smartMorningBrief ??
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
                if (_isPriorityLoading)
                  const Row(
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
                        'Preparing today’s priority...',
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.5,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    _smartPriority ?? _todayState!.priority,
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

    if (!evening) {
      return _CoachCard(
        icon: Icons.nights_stay_outlined,
        title: 'Check back this evening',
        child: const Text(
          'At the end of the day, Today’s Coach will help you make a quick reflection without turning it into another long form.',
          style: TextStyle(
            fontSize: 15,
            height: 1.55,
            color: AppTheme.textSecondary,
          ),
        ),
      );
    }

    if (_isWrapUpLoading) {
      return const _CoachCard(
        icon: Icons.nights_stay_outlined,
        title: 'How did today go?',
        child: Row(
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
              'Loading today’s wrap-up...',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return _CoachCard(
      icon: Icons.nights_stay_outlined,
      title: 'How did today go?',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Choose the option that best matches your day.',
            style: TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _WrapUpChoice(
                label: 'On track',
                selected:
                    _wrapUpStatus == 'on_track',
                onTap: () {
                  setState(() {
                    _wrapUpStatus = 'on_track';
                  });
                },
              ),
              _WrapUpChoice(
                label: 'Partly on track',
                selected:
                    _wrapUpStatus == 'partly_on_track',
                onTap: () {
                  setState(() {
                    _wrapUpStatus =
                        'partly_on_track';
                  });
                },
              ),
              _WrapUpChoice(
                label: 'Off track',
                selected:
                    _wrapUpStatus == 'off_track',
                onTap: () {
                  setState(() {
                    _wrapUpStatus = 'off_track';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _wrapUpNoteController,
            enabled: !_isWrapUpSaving,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              labelText: 'Anything worth noting? (optional)',
              hintText:
                  'Example: Low energy today or missed my workout.',
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.border,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: AppTheme.border,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  _wrapUpStatus == null ||
                          _isWrapUpSaving
                      ? null
                      : _saveEveningWrapUp,
              icon: _isWrapUpSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : Icon(
                      _wrapUpSavedToday
                          ? Icons.update_outlined
                          : Icons.check_outlined,
                    ),
              label: Text(
                _isWrapUpSaving
                    ? 'Saving...'
                    : _wrapUpSavedToday
                        ? 'Update Wrap-up'
                        : 'Save Wrap-up',
              ),
            ),
          ),
        ],
      ),
    );
  }

}

class _WrapUpChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _WrapUpChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(
            milliseconds: 160,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.calorieCard
                : AppTheme.background,
            borderRadius:
                BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryGreen
                  : AppTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                selected
                    ? Icons.check_circle
                    : Icons.circle_outlined,
                size: 19,
                color: selected
                    ? AppTheme.primaryGreen
                    : AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
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
