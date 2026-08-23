import 'package:flutter/material.dart';
import 'package:future_project/models/smart_supplement.dart';
import 'package:future_project/screens/supplement_detail_screen.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/supplement_presentation.dart';

class SmartSupplementSection extends StatelessWidget {
  final List<SmartSupplementRecommendation> items;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;

  const SmartSupplementSection({
    super.key,
    required this.items,
    required this.isLoading,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Smart Supplement',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Personalized for your training & goals',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const _ListSurface(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else if (error != null)
          _ListSurface(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (items.isEmpty)
          const _ListSurface(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No supplement is a clear priority for your current training context.',
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.4, color: AppTheme.textSecondary),
              ),
            ),
          )
        else
          _ListSurface(
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _SupplementRow(
                    item: items[index],
                    onTap: () => _openDetails(context, items[index]),
                  ),
                  if (index != items.length - 1)
                    const Divider(height: 1, indent: 66),
                ],
              ],
            ),
          ),
      ],
    );
  }

  void _openDetails(BuildContext context, SmartSupplementRecommendation item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SupplementDetailScreen(recommendation: item),
      ),
    );
  }
}

class _SupplementRow extends StatelessWidget {
  final SmartSupplementRecommendation item;
  final VoidCallback onTap;

  const _SupplementRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View ${item.name} guidance',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.visionCard,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  supplementIcon(item.id),
                  size: 21,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StatusBadge(item: item),
                    const SizedBox(height: 4),
                    Text(
                      supplementCompactSummary(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.primaryGreen,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final SmartSupplementRecommendation item;
  const _StatusBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: AppTheme.visionCard,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          supplementStatusLabel(item),
          style: const TextStyle(
            fontSize: 9,
            letterSpacing: 0.25,
            fontWeight: FontWeight.w900,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}

class _ListSurface extends StatelessWidget {
  final Widget child;
  const _ListSurface({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
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
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
