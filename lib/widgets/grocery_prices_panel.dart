import 'package:flutter/material.dart';

import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/services/grocery_item_deals_controller.dart';
import 'package:future_project/theme/app_theme.dart';

class GroceryPricesPanel extends StatelessWidget {
  final GroceryItemDealsState state;
  final VoidCallback onChangeArea;
  final VoidCallback onRetry;
  final ValueChanged<Uri> onOpenSource;

  const GroceryPricesPanel({
    super.key,
    required this.state,
    required this.onChangeArea,
    required this.onRetry,
    required this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final selectedName = state.selectedItem?.food.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedName == null
                    ? 'Grocery Prices'
                    : 'Grocery Prices · $selectedName',
                key: const Key('grocery-prices-header'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: onChangeArea,
              icon: const Icon(Icons.location_on_outlined),
              label: Text(state.shoppingArea == null ? 'Set area' : 'Change'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _content(),
      ],
    );
  }

  Widget _content() {
    switch (state.status) {
      case GroceryItemDealsViewStatus.idle:
        return const _MessageCard('Select a grocery item to find prices.');
      case GroceryItemDealsViewStatus.loading:
        return const _MessageCard(
          'Finding prices...',
          leading: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      case GroceryItemDealsViewStatus.error:
        return _MessageCard(
          'Prices are temporarily unavailable.',
          action: TextButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        );
      case GroceryItemDealsViewStatus.shoppingAreaRequired:
        return _MessageCard(
          'Set your shopping area to find prices.',
          action: TextButton(
            onPressed: onChangeArea,
            child: const Text('Set area'),
          ),
        );
      case GroceryItemDealsViewStatus.empty:
        return const _MessageCard('No store prices found yet.');
      case GroceryItemDealsViewStatus.results:
        break;
    }

    final outcome = state.outcome!;
    final nearby = outcome.nearbyRecommendations
        .where(
          (item) =>
              item.result.dealVerified &&
              item.result.locationVerified &&
              item.isDeal,
        )
        .toList(growable: false);
    final online = outcome.onlineRecommendations;
    if (nearby.isEmpty && online.isEmpty) {
      return const _MessageCard('No store prices found yet.');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (nearby.isNotEmpty) ...[
          const _SectionTitle('Deals Near You'),
          const SizedBox(height: 8),
          ...nearby.map(
            (item) => _PriceCard(
              recommendation: item,
              deal: true,
              onOpenSource: onOpenSource,
            ),
          ),
        ],
        if (online.isNotEmpty) ...[
          if (nearby.isNotEmpty) const SizedBox(height: 12),
          const _SectionTitle('Online Store Prices'),
          const SizedBox(height: 8),
          ...online.map(
            (item) => _PriceCard(
              recommendation: item,
              deal: false,
              onOpenSource: onOpenSource,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
  );
}

class _PriceCard extends StatelessWidget {
  final GroceryRecommendation recommendation;
  final bool deal;
  final ValueChanged<Uri> onOpenSource;

  const _PriceCard({
    required this.recommendation,
    required this.deal,
    required this.onOpenSource,
  });

  @override
  Widget build(BuildContext context) {
    final result = recommendation.result;
    final source = result.sourceUri;
    final reference =
        deal &&
            result.regularPrice != null &&
            result.regularPrice! > result.price
        ? result.regularPrice
        : null;
    final savings = reference == null ? null : reference - result.price;
    final package =
        result.packageQuantity != null && result.packageUnitType != null
        ? _packageLabel(result.packageQuantity!, result.packageUnitType!)
        : null;
    return Container(
      key: ValueKey('grocery-price-${result.id}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.storeName,
            style: const TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            result.productName,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (package != null) ...[
            const SizedBox(height: 2),
            Text(
              package,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            '\$${result.price.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          if (!deal)
            const Text(
              'Regular Price',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          if (deal && reference != null)
            Text(
              'Regular \$${reference.toStringAsFixed(2)} · '
              'Save \$${savings!.toStringAsFixed(2)}'
              '${recommendation.discountPercent == null ? '' : ' · ${recommendation.discountPercent!.toStringAsFixed(0)}% off'}',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          if (deal && recommendation.distanceKm != null) ...[
            const SizedBox(height: 6),
            Text(
              '${recommendation.distanceKm!.toStringAsFixed(1)} km away',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ],
          if (source != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: ValueKey('grocery-price-link-${result.id}'),
                onPressed: () => onOpenSource(source),
                icon: const Icon(Icons.open_in_new, size: 16),
                iconAlignment: IconAlignment.end,
                label: Text(deal ? 'View Deal' : 'View at ${result.storeName}'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _packageLabel(double quantity, FoodUnitType type) => switch (type) {
    FoodUnitType.mass =>
      quantity >= 1000
          ? '${(quantity / 1000).toStringAsFixed(quantity % 1000 == 0 ? 0 : 2)} kg'
          : '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} g',
    FoodUnitType.volume =>
      quantity >= 1000
          ? '${(quantity / 1000).toStringAsFixed(quantity % 1000 == 0 ? 0 : 2)} L'
          : '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} mL',
    FoodUnitType.count =>
      '${quantity.toStringAsFixed(quantity % 1 == 0 ? 0 : 1)} count',
  };
}

class _MessageCard extends StatelessWidget {
  final String message;
  final Widget? leading;
  final Widget? action;

  const _MessageCard(this.message, {this.leading, this.action});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: AppTheme.border),
    ),
    child: Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(child: Text(message)),
        ?action,
      ],
    ),
  );
}
