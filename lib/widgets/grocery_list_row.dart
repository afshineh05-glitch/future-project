import 'package:flutter/material.dart';

import 'package:future_project/theme/app_theme.dart';

class GroceryListRow extends StatelessWidget {
  final String title;
  final String quantityLabel;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const GroceryListRow({
    super.key,
    required this.title,
    required this.quantityLabel,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? AppTheme.primaryGreen.withValues(alpha: .07) : null,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              selected ? Icons.shopping_basket : Icons.shopping_basket_outlined,
              color: AppTheme.primaryGreen,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(
              quantityLabel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                selected ? Icons.chevron_right : Icons.chevron_right_outlined,
                color: AppTheme.textSecondary,
              ),
          ],
        ),
      ),
    ),
  );
}
