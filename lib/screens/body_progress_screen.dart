import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:future_project/models/body_progress.dart';
import 'package:future_project/services/body_progress_service.dart';
import 'package:future_project/theme/app_theme.dart';

class BodyProgressScreen extends StatefulWidget {
  const BodyProgressScreen({super.key});

  @override
  State<BodyProgressScreen> createState() => _BodyProgressScreenState();
}

class _BodyProgressScreenState extends State<BodyProgressScreen> {
  final BodyProgressService _service = BodyProgressService();
  BodyProgressBaseline? _baseline;
  List<BodyProgressCheck> _history = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.loadBaseline(),
        _service.loadHistory(),
      ]);
      if (!mounted) return;
      setState(() {
        _baseline = results[0] as BodyProgressBaseline?;
        _history = results[1] as List<BodyProgressCheck>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCheck() async {
    final baseline = _baseline;
    if (baseline == null) return;
    final cycleState = _service.resolveCycle(
      baseline: baseline,
      history: _history,
    );
    final currentCheck = cycleState.currentCheck;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.card,
      builder: (_) => _CheckSheet(
        service: _service,
        baseline: baseline,
        history: _history,
        currentCheck: currentCheck,
        initial:
            currentCheck?.measurements ??
            (_history.isEmpty
                ? baseline.measurements
                : _history.first.measurements),
      ),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final cycleState = _baseline == null
        ? null
        : _service.resolveCycle(baseline: _baseline!, history: _history);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Body Progress'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _load)
          : _baseline == null
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Complete My Foundation first. Your starting measurements become your Body Progress baseline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _CycleCard(cycle: cycleState!.cycle),
                  const SizedBox(height: 18),
                  _BaselineCard(baseline: _baseline!),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _openCheck,
                    icon: Icon(
                      cycleState.isEditing ? Icons.edit_outlined : Icons.add,
                    ),
                    label: Text(
                      cycleState.isEditing ? 'Edit Check' : 'New Check',
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Body Progress History',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_history.isEmpty)
                    const _EmptyHistory()
                  else
                    ..._history.asMap().entries.map((entry) {
                      final previous = _service.comparisonForCheck(
                        check: entry.value,
                        history: _history,
                        baseline: _baseline!,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _HistoryCard(
                          check: entry.value,
                          previous: previous,
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _CycleCard extends StatelessWidget {
  final BodyProgressCycle cycle;
  const _CycleCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    final (icon, title, detail, color) = switch (cycle.status) {
      BodyProgressCycleStatus.upcoming => (
        Icons.schedule,
        'Next check upcoming',
        'Due ${_date(cycle.dueAt)}',
        AppTheme.primaryGreen,
      ),
      BodyProgressCycleStatus.due => (
        Icons.notifications_active_outlined,
        'Body Progress Check due',
        DateTime.now().isAfter(cycle.windowEndsAt)
            ? 'The completion window ended ${_date(cycle.windowEndsAt)}. You can still check in now.'
            : 'Complete by ${_date(cycle.windowEndsAt)}',
        Colors.orange,
      ),
      BodyProgressCycleStatus.completed => (
        Icons.check_circle_outline,
        'Completed for this cycle',
        'Next check ${_date(cycle.dueAt)}',
        Colors.green,
      ),
    };
    return _Panel(
      child: Row(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: const TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BaselineCard extends StatelessWidget {
  final BodyProgressBaseline baseline;
  const _BaselineCard({required this.baseline});

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Foundation baseline',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text(
          '${_number(baseline.measurements.weightKg)} kg  •  Waist ${_number(baseline.measurements.waistCm)} cm  •  Chest ${_number(baseline.measurements.chestCm)} cm',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        Text(
          'Hips ${_number(baseline.measurements.hipsCm)}  •  Arm ${_number(baseline.measurements.armCm)}  •  Thigh ${_number(baseline.measurements.thighCm)}  •  Neck ${_number(baseline.measurements.neckCm)} cm',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}

class _HistoryCard extends StatelessWidget {
  final BodyProgressCheck check;
  final BodyMeasurements previous;
  const _HistoryCard({required this.check, required this.previous});

  @override
  Widget build(BuildContext context) => _Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _date(check.checkedAt.toLocal()),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${_changeLine('Weight', check.measurements.weightKg, previous.weightKg, 'kg')}\n'
          '${_changeLine('Waist', check.measurements.waistCm, previous.waistCm, 'cm')}  •  '
          '${_changeLine('Chest', check.measurements.chestCm, previous.chestCm, 'cm')}\n'
          '${_changeLine('Hips', check.measurements.hipsCm, previous.hipsCm, 'cm')}  •  '
          '${_changeLine('Arm', check.measurements.armCm, previous.armCm, 'cm')}',
          style: const TextStyle(color: AppTheme.textSecondary, height: 1.5),
        ),
        if (check.note?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Text(
            check.note!,
            style: const TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ],
    ),
  );
}

class _CheckSheet extends StatefulWidget {
  final BodyProgressService service;
  final BodyProgressBaseline baseline;
  final List<BodyProgressCheck> history;
  final BodyProgressCheck? currentCheck;
  final BodyMeasurements initial;
  const _CheckSheet({
    required this.service,
    required this.baseline,
    required this.history,
    required this.currentCheck,
    required this.initial,
  });

  @override
  State<_CheckSheet> createState() => _CheckSheetState();
}

class _CheckSheetState extends State<_CheckSheet> {
  final _formKey = GlobalKey<FormState>();
  late final List<TextEditingController> _controllers;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final m = widget.initial;
    _controllers = [
      m.weightKg,
      m.waistCm,
      m.chestCm,
      m.hipsCm,
      m.armCm,
      m.thighCm,
      m.neckCm,
    ].map((value) => TextEditingController(text: _number(value))).toList();
    _note.text = widget.currentCheck?.note ?? '';
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final v = _controllers.map((item) => double.parse(item.text)).toList();
      await widget.service.saveCheckForCurrentCycle(
        baseline: widget.baseline,
        history: widget.history,
        measurements: BodyMeasurements(
          weightKg: v[0],
          waistCm: v[1],
          chestCm: v[2],
          hipsCm: v[3],
          armCm: v[4],
          thighCm: v[5],
          neckCm: v[6],
        ),
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save check: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Weight (kg)',
      'Waist (cm)',
      'Chest (cm)',
      'Hips (cm)',
      'Arm (cm)',
      'Thigh (cm)',
      'Neck (cm)',
    ];
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.currentCheck == null
                      ? 'New Body Progress Check'
                      : 'Edit Body Progress Check',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your latest measurements are filled in. Update anything that changed.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 18),
                ...List.generate(
                  labels.length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: _controllers[index],
                      decoration: InputDecoration(
                        labelText: labels[index],
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d*\.?\d{0,2}'),
                        ),
                      ],
                      validator: (value) =>
                          (double.tryParse(value ?? '') ?? 0) <= 0
                          ? 'Enter a value greater than zero'
                          : null,
                    ),
                  ),
                ),
                TextField(
                  controller: _note,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Note (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: Text(
                    _saving
                        ? 'Saving…'
                        : widget.currentCheck == null
                        ? 'Save Check'
                        : 'Save Changes',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();
  @override
  Widget build(BuildContext context) => const _Panel(
    child: Text(
      'No checks yet. Your first check will be compared with My Foundation.',
      style: TextStyle(color: AppTheme.textSecondary),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Could not load Body Progress.\n$message',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}

String _date(DateTime value) => '${value.month}/${value.day}/${value.year}';
String _number(double value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toStringAsFixed(1);
String _changeLine(String label, double value, double previous, String unit) {
  final difference = value - previous;
  final change = difference.abs() < 0.005
      ? 'no change'
      : '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)}';
  return '$label ${_number(value)} $unit ($change)';
}
