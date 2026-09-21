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
  final List<WeeklyFoodRequirement> requestedItems;
  final UserShoppingArea? shoppingArea;
  final GroceryDealsOutcome? outcome;
  final bool isLoading;
  final Object? error;
  final int searchedItemCount;
  final int totalItemCount;

  const GroceryItemDealsState({
    this.selectedItem,
    this.requestedItems = const [],
    this.shoppingArea,
    this.outcome,
    this.isLoading = false,
    this.error,
    this.searchedItemCount = 0,
    this.totalItemCount = 0,
  });

  bool get isBatch => requestedItems.length > 1;
  bool get hasMore => searchedItemCount < totalItemCount;

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
  static const maxItemsPerBatch = 5;
  static const cacheDuration = Duration(minutes: 10);

  final DealsLocationService locationService;
  final GroceryDealsEngine engine;
  final String expectedUserId;

  GroceryItemDealsState _state = const GroceryItemDealsState();
  Future<void>? _active;
  String? _activeKey;
  int _generation = 0;
  List<WeeklyFoodRequirement> _lastRequested = const [];
  final Map<String, _CachedOutcome> _cache = {};

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
    _lastRequested = [item];
    _state = GroceryItemDealsState(
      selectedItem: item,
      requestedItems: [item],
      isLoading: true,
      totalItemCount: 1,
    );
    notifyListeners();
    final operation = _run(item, key, generation);
    _active = operation;
    return operation;
  }

  Future<void> retry() {
    if (_lastRequested.length > 1) {
      return searchAll(_lastRequested, forceRefresh: true);
    }
    final item = _state.selectedItem;
    if (item == null) return Future<void>.value();
    _state = GroceryItemDealsState(
      selectedItem: item,
      requestedItems: [item],
      isLoading: true,
      totalItemCount: 1,
    );
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
    _lastRequested = const [];
    _cache.clear();
    _state = const GroceryItemDealsState();
    notifyListeners();
  }

  Future<void> searchAll(
    List<WeeklyFoodRequirement> items, {
    bool forceRefresh = false,
  }) {
    final unique = _deduplicate(items);
    if (unique.isEmpty) {
      _lastRequested = const [];
      _state = const GroceryItemDealsState(
        outcome: GroceryDealsOutcome(status: DealsResultStatus.noReliablePrice),
      );
      notifyListeners();
      return Future<void>.value();
    }
    final key = 'batch:${unique.map(_key).join('|')}';
    if (!forceRefresh &&
        _activeKey == key &&
        (_active != null || _state.outcome != null)) {
      return _active ?? Future<void>.value();
    }
    final generation = ++_generation;
    _activeKey = key;
    _lastRequested = unique;
    _state = GroceryItemDealsState(
      requestedItems: unique,
      isLoading: true,
      totalItemCount: unique.length,
    );
    notifyListeners();
    final operation = _runBatch(
      unique,
      start: 0,
      generation: generation,
      key: key,
      forceRefresh: forceRefresh,
    );
    _active = operation;
    return operation;
  }

  Future<void> loadMore() {
    if (_active != null || !_state.hasMore || _lastRequested.isEmpty) {
      return _active ?? Future<void>.value();
    }
    final generation = ++_generation;
    final key = 'batch:${_lastRequested.map(_key).join('|')}';
    _activeKey = key;
    _state = GroceryItemDealsState(
      requestedItems: _lastRequested,
      shoppingArea: _state.shoppingArea,
      outcome: _state.outcome,
      isLoading: true,
      searchedItemCount: _state.searchedItemCount,
      totalItemCount: _lastRequested.length,
    );
    notifyListeners();
    final operation = _runBatch(
      _lastRequested,
      start: _state.searchedItemCount,
      generation: generation,
      key: key,
    );
    _active = operation;
    return operation;
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
            requestedItems: [item],
            shoppingArea: area,
            outcome: const GroceryDealsOutcome(
              status: DealsResultStatus.shoppingAreaRequired,
            ),
            totalItemCount: 1,
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
            requestedItems: [item],
            shoppingArea: area,
            error: StateError('Nearby prices could not be loaded.'),
            searchedItemCount: 1,
            totalItemCount: 1,
          ),
        );
        return;
      }
      _finish(
        generation,
        key,
        GroceryItemDealsState(
          selectedItem: item,
          requestedItems: [item],
          shoppingArea: area,
          outcome: outcome,
          searchedItemCount: 1,
          totalItemCount: 1,
        ),
      );
    } catch (error) {
      if (_current(generation, key, locationService.authenticatedUserId)) {
        _finish(
          generation,
          key,
          GroceryItemDealsState(
            selectedItem: item,
            requestedItems: [item],
            error: error,
            searchedItemCount: 1,
            totalItemCount: 1,
          ),
        );
      }
    }
  }

  Future<void> _runBatch(
    List<WeeklyFoodRequirement> items, {
    required int start,
    required int generation,
    required String key,
    bool forceRefresh = false,
  }) async {
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
            requestedItems: items,
            shoppingArea: area,
            outcome: const GroceryDealsOutcome(
              status: DealsResultStatus.shoppingAreaRequired,
            ),
            totalItemCount: items.length,
          ),
        );
        return;
      }

      final previous = start == 0 ? null : _state.outcome;
      final nearby = <GroceryRecommendation>[
        ...?previous?.nearbyRecommendations,
      ];
      final online = <GroceryRecommendation>[
        ...?previous?.onlineRecommendations,
      ];
      var providerFailed = previous?.providerFailed ?? false;
      final end = (start + maxItemsPerBatch).clamp(0, items.length);
      for (var index = start; index < end; index++) {
        if (!_current(generation, key, userId)) return;
        final item = items[index];
        try {
          final outcome = await _outcomeFor(
            item,
            area,
            userId,
            forceRefresh: forceRefresh,
          );
          nearby.addAll(outcome.nearbyRecommendations);
          online.addAll(outcome.onlineRecommendations);
          providerFailed = providerFailed || outcome.providerFailed;
        } catch (_) {
          providerFailed = true;
        }
      }
      if (!_current(generation, key, userId)) return;
      final outcome = GroceryDealsOutcome(
        status: nearby.isNotEmpty
            ? DealsResultStatus.dealsFound
            : online.isNotEmpty
            ? DealsResultStatus.regularPricesFound
            : DealsResultStatus.noReliablePrice,
        providerFailed: providerFailed,
        nearbyRecommendations: nearby,
        onlineRecommendations: online,
      );
      _finish(
        generation,
        key,
        GroceryItemDealsState(
          requestedItems: items,
          shoppingArea: area,
          outcome: outcome,
          error: providerFailed && outcome.recommendations.isEmpty
              ? StateError('Prices could not be loaded.')
              : null,
          searchedItemCount: end,
          totalItemCount: items.length,
        ),
      );
    } catch (error) {
      if (_current(generation, key, locationService.authenticatedUserId)) {
        _finish(
          generation,
          key,
          GroceryItemDealsState(
            requestedItems: items,
            error: error,
            searchedItemCount: start,
            totalItemCount: items.length,
          ),
        );
      }
    }
  }

  Future<GroceryDealsOutcome> _outcomeFor(
    WeeklyFoodRequirement item,
    UserShoppingArea area,
    String userId, {
    required bool forceRefresh,
  }) async {
    final cacheKey = [
      userId,
      area.postalCode,
      area.latitude,
      area.longitude,
      area.radiusKm,
      _key(item),
    ].join('|');
    final cached = _cache[cacheKey];
    if (!forceRefresh &&
        cached != null &&
        DateTime.now().difference(cached.storedAt) <= cacheDuration) {
      return cached.outcome;
    }
    final outcome = await engine.findPrices([item]);
    if (!(outcome.providerFailed && outcome.recommendations.isEmpty)) {
      _cache[cacheKey] = _CachedOutcome(DateTime.now(), outcome);
    }
    return outcome;
  }

  List<WeeklyFoodRequirement> _deduplicate(List<WeeklyFoodRequirement> items) {
    final unique = <String, WeeklyFoodRequirement>{};
    for (final item in items.where((item) => item.purchaseGrams >= 1)) {
      final existing = unique[item.food.key];
      if (existing == null || item.purchaseGrams > existing.purchaseGrams) {
        unique[item.food.key] = item;
      }
    }
    return unique.values.toList(growable: false);
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

class _CachedOutcome {
  final DateTime storedAt;
  final GroceryDealsOutcome outcome;
  const _CachedOutcome(this.storedAt, this.outcome);
}
