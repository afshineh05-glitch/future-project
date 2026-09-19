import 'package:flutter/foundation.dart';

import 'package:future_project/models/grocery_deals.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/deals_location_service.dart';
import 'package:future_project/services/grocery_deals_engine.dart';

enum GroceryItemDealsViewStatus {
  idle,
  loading,
  shoppingAreaRequired,
  results,
  empty,
  error,
}

class GroceryItemDealsState {
  final WeeklyFoodRequirement? selectedItem;
  final UserShoppingArea? shoppingArea;
  final GroceryDealsOutcome? outcome;
  final bool isLoading;
  final Object? error;

  const GroceryItemDealsState({
    this.selectedItem,
    this.shoppingArea,
    this.outcome,
    this.isLoading = false,
    this.error,
  });

  GroceryItemDealsViewStatus get status {
    if (isLoading) return GroceryItemDealsViewStatus.loading;
    if (error != null) return GroceryItemDealsViewStatus.error;
    final result = outcome;
    if (result == null) return GroceryItemDealsViewStatus.idle;
    if (result.status == DealsResultStatus.shoppingAreaRequired) {
      return GroceryItemDealsViewStatus.shoppingAreaRequired;
    }
    if (result.recommendations.isEmpty) return GroceryItemDealsViewStatus.empty;
    return GroceryItemDealsViewStatus.results;
  }
}

/// Coordinates one canonical grocery item search without changing its need.
/// Results from an older selection or account are ignored.
class GroceryItemDealsController extends ChangeNotifier {
  final DealsLocationService locationService;
  final GroceryDealsEngine engine;
  final String expectedUserId;

  GroceryItemDealsState _state = const GroceryItemDealsState();
  Future<void>? _active;
  String? _activeKey;
  int _generation = 0;

  GroceryItemDealsController({
    required this.locationService,
    required this.engine,
    required this.expectedUserId,
  });

  GroceryItemDealsState get state => _state;

  Future<void> select(WeeklyFoodRequirement item) {
    final key = _key(item);
    if (_activeKey == key && (_active != null || _state.outcome != null)) {
      return _active ?? Future<void>.value();
    }

    final generation = ++_generation;
    _activeKey = key;
    _state = GroceryItemDealsState(selectedItem: item, isLoading: true);
    notifyListeners();
    final operation = _run(item, key, generation);
    _active = operation;
    return operation;
  }

  Future<void> retry() {
    final item = _state.selectedItem;
    if (item == null) return Future<void>.value();
    _state = GroceryItemDealsState(selectedItem: item, isLoading: true);
    notifyListeners();
    final generation = ++_generation;
    final key = _key(item);
    _activeKey = key;
    final operation = _run(item, key, generation);
    _active = operation;
    return operation;
  }

  void invalidate() {
    ++_generation;
    _active = null;
    _activeKey = null;
    _state = const GroceryItemDealsState();
    notifyListeners();
  }

  Future<void> _run(
    WeeklyFoodRequirement item,
    String key,
    int generation,
  ) async {
    try {
      final userId = locationService.authenticatedUserId;
      final area = userId == null || userId != expectedUserId
          ? null
          : await locationService.currentShoppingArea();
      if (!_current(generation, key, userId)) return;
      if (userId == null ||
          userId != expectedUserId ||
          area == null ||
          !area.isUsable) {
        _finish(
          generation,
          key,
          GroceryItemDealsState(
            selectedItem: item,
            shoppingArea: area,
            outcome: const GroceryDealsOutcome(
              status: DealsResultStatus.shoppingAreaRequired,
            ),
          ),
        );
        return;
      }

      final outcome = await engine.findPrices([item]);
      if (!_current(generation, key, userId)) return;
      if (outcome.providerFailed && outcome.recommendations.isEmpty) {
        _finish(
          generation,
          key,
          GroceryItemDealsState(
            selectedItem: item,
            shoppingArea: area,
            error: StateError('Nearby prices could not be loaded.'),
          ),
        );
        return;
      }
      _finish(
        generation,
        key,
        GroceryItemDealsState(
          selectedItem: item,
          shoppingArea: area,
          outcome: outcome,
        ),
      );
    } catch (error) {
      if (_current(generation, key, locationService.authenticatedUserId)) {
        _finish(
          generation,
          key,
          GroceryItemDealsState(selectedItem: item, error: error),
        );
      }
    }
  }

  bool _current(int generation, String key, String? userId) =>
      generation == _generation &&
      key == _activeKey &&
      userId == expectedUserId &&
      userId == locationService.authenticatedUserId;

  void _finish(int generation, String key, GroceryItemDealsState state) {
    if (generation != _generation || key != _activeKey) return;
    _active = null;
    _state = state;
    notifyListeners();
  }

  String _key(WeeklyFoodRequirement item) =>
      '${item.food.key}:${item.purchaseGrams}';
}
