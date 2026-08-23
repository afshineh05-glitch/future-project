import 'package:flutter/material.dart';
import 'package:future_project/models/smart_supplement.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/supplement_presentation.dart';

class SupplementDetailScreen extends StatelessWidget {
  final SmartSupplementRecommendation recommendation;

  const SupplementDetailScreen({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final amount = supplementAmountGuidance(recommendation);
    final timing = supplementTimingGuidance(recommendation);
    return Scaffold(
      appBar: AppBar(title: const Text('Supplement Guidance')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: AppTheme.visionCard,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          supplementIcon(recommendation.id),
                          size: 28,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              recommendation.name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 7),
                            _DetailStatus(item: recommendation),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  _DetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('WHY FOR YOU'),
                        const SizedBox(height: 8),
                        Text(
                          recommendation.whyForYou,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _SectionLabel('BENEFITS'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 7,
                          runSpacing: 7,
                          children: [
                            for (final benefit in recommendation.benefits)
                              _BenefitChip(benefit),
                          ],
                        ),
                        if (amount != null) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel('HOW MUCH'),
                          const SizedBox(height: 6),
                          Text(amount, style: _guidanceStyle),
                        ],
                        if (timing != null) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel('WHEN'),
                          const SizedBox(height: 6),
                          Text(timing, style: _guidanceStyle),
                        ],
                        if (recommendation.coachTip != null) ...[
                          const SizedBox(height: 20),
                          const _SectionLabel('COACH TIP'),
                          const SizedBox(height: 7),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.visionCard,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              recommendation.coachTip!,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SafetyAndMore(item: recommendation),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SafetyAndMore extends StatelessWidget {
  final SmartSupplementRecommendation item;
  const _SafetyAndMore({required this.item});

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Safety & more information',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        children: [
          _ReferenceBlock(title: 'What it is', text: item.guidance.what),
          _ReferenceBlock(title: 'Why it works', text: item.guidance.why),
          _ReferenceBlock(
            title: 'Optional nutrition background',
            text: item.guidance.foodFirst,
          ),
          if (item.guidance.caution != null)
            _ReferenceBlock(
              title: 'Safety & cautions',
              text: item.guidance.caution!,
              last: true,
            ),
        ],
      ),
    );
  }
}

class _ReferenceBlock extends StatelessWidget {
  final String title;
  final String text;
  final bool last;

  const _ReferenceBlock({
    required this.title,
    required this.text,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title, style: _referenceTitleStyle),
          ),
          const SizedBox(height: 4),
          Text(text, style: _referenceBodyStyle),
        ],
      ),
    );
  }
}

class _DetailStatus extends StatelessWidget {
  final SmartSupplementRecommendation item;
  const _DetailStatus({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.visionCard,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        supplementStatusLabel(item, detailed: true),
        style: const TextStyle(
          fontSize: 10,
          letterSpacing: 0.35,
          fontWeight: FontWeight.w900,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String text;
  const _BenefitChip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.visionCard,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppTheme.primaryGreen,
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _DetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(text, style: _labelStyle);
}

const _labelStyle = TextStyle(
  fontSize: 10,
  letterSpacing: 0.5,
  fontWeight: FontWeight.w900,
  color: AppTheme.primaryGreen,
);
const _guidanceStyle = TextStyle(
  fontSize: 15,
  height: 1.4,
  fontWeight: FontWeight.w800,
  color: AppTheme.textPrimary,
);
const _referenceTitleStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w900,
  color: AppTheme.textPrimary,
);
const _referenceBodyStyle = TextStyle(
  fontSize: 12,
  height: 1.45,
  color: AppTheme.textSecondary,
);
