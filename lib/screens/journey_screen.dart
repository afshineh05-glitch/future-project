import 'dart:async';

import 'package:flutter/material.dart';

import 'package:future_project/models/journey.dart';
import 'package:future_project/services/journey_access_service.dart';
import 'package:future_project/services/journey_service.dart';
import 'package:future_project/theme/app_theme.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, this.accessService, this.journeyService});
  final JourneyAccessService? accessService;
  final JourneyService? journeyService;
  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  late final JourneyAccessService _access;
  late final JourneyService _journey;
  JourneyTimeline? _timeline;
  Object? _error;
  bool _loading = true;
  bool _authorized = false;
  bool _redirectScheduled = false;

  @override
  void initState() {
    super.initState();
    _access = widget.accessService ?? JourneyAccessService();
    _journey = widget.journeyService ?? JourneyService();
    unawaited(_load());
  }

  Future<void> _load() async {
    final userId = _access.currentUserId;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final authorized = await _access.canAccess();
    if (!mounted || _access.currentUserId != userId) return;
    if (!authorized) {
      setState(() {
        _loading = false;
        _authorized = false;
      });
      _redirectUnauthorized();
      return;
    }
    try {
      final timeline = await _journey.load();
      if (!mounted || _access.currentUserId != userId) return;
      setState(() {
        _timeline = timeline;
        _authorized = true;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || _access.currentUserId != userId) return;
      setState(() {
        _error = error;
        _authorized = true;
        _loading = false;
      });
    }
  }

  void _redirectUnauthorized() {
    if (_redirectScheduled) return;
    _redirectScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _JourneyLoading();
    if (!_authorized) return const SizedBox.shrink();
    if (_error != null || _timeline == null) return const _JourneyError();
    final timeline = _timeline!;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Your Journey'),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            _ChapterHeader(stage: timeline.stage),
            if (timeline.nextChapterTitle != null) ...[
              const SizedBox(height: 20),
              _NextChapter(timeline: timeline),
            ],
            const SizedBox(height: 28),
            if (timeline.events.isEmpty)
              const _EmptyJourney()
            else
              ...timeline.events.map((event) => _TimelineEvent(event: event)),
            if (timeline.partial && timeline.events.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'Some optional history is temporarily unavailable. Your verified events remain here.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChapterHeader extends StatelessWidget {
  final dynamic stage;
  const _ChapterHeader({required this.stage});
  @override
  Widget build(BuildContext context) {
    final title = switch (stage.toString().split('.').last) {
      'starting' => 'The beginning',
      'building' => 'Building the foundation',
      'becoming' => 'Becoming consistent',
      _ => 'Living the change',
    };
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.visionCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT CHAPTER',
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.2,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your story is built from the progress you actually record.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _NextChapter extends StatelessWidget {
  final JourneyTimeline timeline;
  const _NextChapter({required this.timeline});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppTheme.journeyCard,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: AppTheme.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT CHAPTER',
          style: TextStyle(
            fontSize: 12,
            letterSpacing: 1.1,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          timeline.nextChapterTitle!,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (timeline.nextChapterMeaning?.isNotEmpty == true) ...[
          const SizedBox(height: 5),
          Text(
            timeline.nextChapterMeaning!,
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
        ],
      ],
    ),
  );
}

class _TimelineEvent extends StatelessWidget {
  final JourneyEvent event;
  const _TimelineEvent({required this.event});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 5, right: 14),
          decoration: const BoxDecoration(
            color: AppTheme.primaryGreen,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatJourneyDate(event.occurredAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                event.meaning,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Verified from ${event.verifiedSource}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _EmptyJourney extends StatelessWidget {
  const _EmptyJourney();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        Icon(Icons.route_outlined, size: 42, color: AppTheme.textSecondary),
        SizedBox(height: 14),
        Text(
          'Your Journey will grow automatically',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Verified progress will appear here as you record it.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      ],
    ),
  );
}

String _formatJourneyDate(DateTime value) =>
    '${_journeyMonth(value.month)} ${value.day}, ${value.year}';

String _journeyMonth(int value) =>
    const <String>[
      '',
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
    ][value < 1
        ? 1
        : value > 12
        ? 12
        : value];

class _JourneyLoading extends StatelessWidget {
  const _JourneyLoading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _JourneyError extends StatelessWidget {
  const _JourneyError();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Journey is temporarily unavailable.')),
  );
}
