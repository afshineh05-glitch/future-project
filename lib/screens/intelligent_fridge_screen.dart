import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/debug/ingredient_image_refresh_key.dart';
import 'package:future_project/models/cook_for_goal_recipe.dart';
import 'package:future_project/models/food_visual.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/models/nutrition_profile.dart';
import 'package:future_project/models/performance_fuel.dart';
import 'package:future_project/screens/ingredient_image_curator_screen.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';
import 'package:future_project/services/ingredient_image_service.dart';
import 'package:future_project/theme/app_theme.dart';

class IntelligentFridgeScreen extends StatefulWidget {
  final PerformanceFuel fuel;
  final NutritionProfile profile;
  final int trainingDays;
  final List<RankedCookForGoalRecipe> recipes;

  const IntelligentFridgeScreen({
    super.key,
    required this.fuel,
    required this.profile,
    required this.trainingDays,
    required this.recipes,
  });

  @override
  State<IntelligentFridgeScreen> createState() =>
      _IntelligentFridgeScreenState();
}

class _IntelligentFridgeScreenState extends State<IntelligentFridgeScreen> {
  late final FridgeInventoryRepository _repository;
  late final IntelligentFridgeService _service;
  late final IngredientImageService _imageService;
  final Map<String, Future<FoodVisual>> _ingredientImages = {};
  IntelligentFridgeState? _state;
  String _search = '';
  String _selectedCategory = 'All';
  Set<String> _selectedKeys = {};
  String? _error;
  bool _isRefreshingTestImages = false;

  // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
  static const _testImageKeys = <String>[
    'chicken_breast',
    'fish',
    'tuna',
    'shrimp',
    'banana',
    'apple',
    'grapes',
    'almonds',
  ];

  static const _categories = [
    'All',
    'Protein',
    'Seafood',
    'Dairy',
    'Carbs & Grains',
    'Vegetables',
    'Fruits',
    'Legumes',
    'Nuts & Seeds',
    'Fats & Oils',
    'Pantry',
    'Herbs & Spices',
  ];

  @override
  void initState() {
    super.initState();
    _repository = SupabaseFridgeInventoryRepository();
    _service = IntelligentFridgeService(repository: _repository);
    _imageService = IngredientImageService();
    _load();
  }

  Future<void> _load() async {
    try {
      final value = await _service.load(
        fuel: widget.fuel,
        profile: widget.profile,
        trainingDays: widget.trainingDays,
        recipes: widget.recipes,
      );
      if (mounted) {
        setState(() {
          _state = value;
          _selectedKeys = value.inventory
              .where((item) => item.isAvailable)
              .map((item) => item.ingredientKey)
              .toSet();
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  Future<void> _toggleFood(FridgeFoodReference food, bool selected) async {
    setState(() {
      selected ? _selectedKeys.add(food.key) : _selectedKeys.remove(food.key);
    });
    try {
      if (selected) {
        await _repository.saveItem(
          FridgeItem(
            userId: widget.profile.userId,
            ingredientKey: food.key,
            ingredientName: food.name,
            category: food.category,
            quantityUnit: 'g',
          ),
        );
      } else {
        await _repository.removeItem(food.key);
      }
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          selected
              ? _selectedKeys.remove(food.key)
              : _selectedKeys.add(food.key);
        });
      }
      rethrow;
    }
  }

  Future<void> _editQuantity(FridgeFoodReference food, FridgeItem item) async {
    final controller = TextEditingController(
      text: item.quantity?.toStringAsFixed(0) ?? '',
    );
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${food.name} quantity'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Approximate grams'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = double.tryParse(controller.text.trim());
              if (quantity == null || quantity < 0 || quantity > 100000) {
                return;
              }
              Navigator.pop(context, quantity);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null) return;
    await _repository.saveItem(
      FridgeItem(
        id: item.id,
        userId: item.userId,
        ingredientKey: item.ingredientKey,
        ingredientName: item.ingredientName,
        category: item.category,
        quantity: value,
        quantityUnit: 'g',
      ),
    );
    await _load();
  }

  Future<void> _togglePreference(String key, bool selected) async {
    final updated = {...?_state?.preferredFoodKeys};
    selected ? updated.add(key) : updated.remove(key);
    await _repository.savePreferredFoodKeys(updated);
    await _load();
  }

  // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
  Future<void> _refreshTestImages() async {
    if (_isRefreshingTestImages) return;

    if (!IngredientImageRefreshKey.hasRefreshKey) {
      _showDebugMessage(
        'Image refresh stopped: INGREDIENT_IMAGE_REFRESH_KEY was not supplied.',
      );
      return;
    }
    final refreshKey = IngredientImageRefreshKey.refreshKey;

    final supabase = Supabase.instance.client;
    var session = supabase.auth.currentSession;
    if (session == null) {
      _showDebugMessage(
        'Image refresh stopped: no signed-in Supabase session exists.',
      );
      return;
    }

    if (session.isExpired) {
      try {
        session = (await supabase.auth.refreshSession()).session;
      } catch (_) {
        _showDebugMessage(
          'Image refresh stopped: the signed-in Supabase session could not be refreshed.',
        );
        return;
      }
    }
    if (session == null || session.isExpired) {
      _showDebugMessage(
        'Image refresh stopped: no valid Supabase session is available.',
      );
      return;
    }

    setState(() => _isRefreshingTestImages = true);
    final results = <_DebugImageRefreshResult>[];
    var authenticationBlocked = false;

    for (final key in _testImageKeys) {
      try {
        final response = await supabase.functions.invoke(
          'resolve-food-image',
          headers: {'x-image-refresh-key': refreshKey},
          body: {'ingredientKey': key, 'forceRefresh': true},
        );
        final data = response.data;
        final map = data is Map
            ? Map<String, dynamic>.from(data)
            : const <String, dynamic>{};
        final visual = FoodVisual.fromMap(map);
        if (visual.isReady) {
          _ingredientImages[key] = Future.value(visual);
          results.add(
            _DebugImageRefreshResult(
              key: key,
              success: true,
              provider: visual.source,
              imageUrl: visual.imageUrl,
            ),
          );
        } else {
          results.add(
            _DebugImageRefreshResult(
              key: key,
              success: false,
              message: visual.message ?? 'No cached image URL was returned.',
            ),
          );
        }
      } on FunctionException catch (error) {
        final message = _functionErrorMessage(error.details);
        results.add(
          _DebugImageRefreshResult(key: key, success: false, message: message),
        );
        if (error.status == 401 || error.status == 403) {
          authenticationBlocked = true;
          break;
        }
      } catch (_) {
        results.add(
          _DebugImageRefreshResult(
            key: key,
            success: false,
            message: 'The refresh request could not be completed.',
          ),
        );
      }
    }

    if (!mounted) return;
    setState(() => _isRefreshingTestImages = false);
    await _showRefreshSummary(results, authenticationBlocked);
  }

  // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
  String _functionErrorMessage(dynamic details) {
    if (details is! Map) return 'The Edge Function rejected the request.';
    final map = Map<String, dynamic>.from(details);
    final error = map['error'];
    if (error is Map) {
      final message = error['message']?.toString().trim();
      if (message?.isNotEmpty == true) return message!;
    }
    final message = map['message']?.toString().trim();
    return message?.isNotEmpty == true
        ? message!
        : 'The Edge Function rejected the request.';
  }

  // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
  void _showDebugMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
  Future<void> _showRefreshSummary(
    List<_DebugImageRefreshResult> results,
    bool authenticationBlocked,
  ) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Test image refresh'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (authenticationBlocked)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Stopped because authorization was rejected. No remaining requests were sent.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              for (final result in results)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(result.summary),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intelligent Fridge'),
        actions: [
          // TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
          if (kDebugMode)
            TextButton.icon(
              onPressed: _isRefreshingTestImages ? null : _refreshTestImages,
              icon: _isRefreshingTestImages
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Refresh Test Images'),
            ),
          // TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
          if (kDebugMode)
            IconButton(
              tooltip: 'Curate Ingredient Images',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const IngredientImageCuratorScreen(),
                ),
              ),
              icon: const Icon(Icons.collections_outlined),
            ),
        ],
      ),
      body: _error != null
          ? _ErrorState(message: _error!, retry: _load)
          : _state == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  const Text(
                    'Select what you have in your fridge and pantry',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  _section('In Your Fridge'),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search ingredients...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 6,
                    children: _categories
                        .map(
                          (category) => FilterChip(
                            label: Text(category),
                            selected: _selectedCategory == category,
                            onSelected: (_) =>
                                setState(() => _selectedCategory = category),
                            visualDensity: VisualDensity.compact,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_selectedKeys.length} selected',
                    style: const TextStyle(
                      color: AppTheme.primaryGreen,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ..._inventoryGroups(),
                  const SizedBox(height: 22),
                  _section(
                    'Preferred protein sources',
                    'Choose several. Weekly protein is shared across your choices.',
                  ),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 4, children: _preferenceChips()),
                  const SizedBox(height: 24),
                  _section(
                    'Recommended This Week',
                    'Approximate practical quantities based on your current targets and training week.',
                  ),
                  const SizedBox(height: 10),
                  ..._state!.recommendations.map(_recommendationTile),
                  const SizedBox(height: 24),
                  _section('Meals You Can Make'),
                  const SizedBox(height: 10),
                  ..._state!.recipeMatches.map(_recipeTile),
                  const SizedBox(height: 24),
                  _section('Your Grocery List'),
                  const SizedBox(height: 10),
                  if (_state!.groceryList.isEmpty)
                    const _EmptyCard('You have this week’s recommended foods.')
                  else
                    ..._state!.groceryList.map(_groceryTile),
                  const SizedBox(height: 16),
                  const _EmptyCard(
                    'Partner-store purchasing is unavailable until a supported partner is configured for your region.',
                  ),
                ],
              ),
            ),
    );
  }

  Widget _section(String title, [String? subtitle]) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.titleLarge),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary)),
      ],
    ],
  );

  List<Widget> _inventoryGroups() {
    final inventory = {
      for (final item in _state!.inventory) item.ingredientKey: item,
    };
    final query = _search.trim().toLowerCase();
    final foods = FridgeFoodCatalog.allowedFor(widget.profile).where((food) {
      final matchesSearch = food.name.toLowerCase().contains(query);
      final matchesCategory =
          _selectedCategory == 'All' ||
          _displayCategory(food) == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
    final categories = <String, List<FridgeFoodReference>>{};
    for (final food in foods) {
      categories.putIfAbsent(_displayCategory(food), () => []).add(food);
    }
    return categories.entries
        .map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4, bottom: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: .7,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.length} items',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  clipBehavior: Clip.antiAlias,
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth >= 960
                          ? 4
                          : constraints.maxWidth >= 640
                          ? 3
                          : constraints.maxWidth >= 300
                          ? 2
                          : 1;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entry.value.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 7,
                          mainAxisSpacing: 7,
                          mainAxisExtent: 72,
                        ),
                        itemBuilder: (context, index) {
                          final food = entry.value[index];
                          final item = inventory[food.key];
                          return _InventoryTile(
                            food: food,
                            image: _ingredientImage(food),
                            item: item,
                            selected: _selectedKeys.contains(food.key),
                            amountLabel: item?.quantity == null
                                ? 'Add amount'
                                : _amount(item!.quantity!),
                            onToggle: () => _toggleFood(
                              food,
                              !_selectedKeys.contains(food.key),
                            ),
                            onEditQuantity: item == null
                                ? null
                                : () => _editQuantity(food, item),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  String _displayCategory(FridgeFoodReference food) {
    if (food.category == 'Fish & Seafood') return 'Seafood';
    if (food.category == 'Fats & Nuts') {
      return food.key == 'olive_oil' ? 'Fats & Oils' : 'Nuts & Seeds';
    }
    if (food.category == 'Pantry / Condiments') {
      return const {'black_pepper', 'garlic'}.contains(food.key)
          ? 'Herbs & Spices'
          : 'Pantry';
    }
    return food.category;
  }

  Future<FoodVisual> _ingredientImage(FridgeFoodReference food) =>
      _ingredientImages.putIfAbsent(
        food.key,
        () => _imageService.resolve(
          ingredientKey: food.key,
          displayName: food.name,
        ),
      );

  List<Widget> _preferenceChips() =>
      FridgeFoodCatalog.allowedFor(widget.profile)
          .where((food) => food.macroFocus == 'protein')
          .map(
            (food) => FilterChip(
              label: Text(food.name),
              selected: _state!.preferredFoodKeys.contains(food.key),
              onSelected: (selected) => _togglePreference(food.key, selected),
            ),
          )
          .toList();

  Widget _recommendationTile(WeeklyFoodRequirement item) => _Surface(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.food.name),
      subtitle: Text(
        'Suggested: ${_amount(item.suggestedGrams)}\n'
        'In fridge: ${_amount(item.inFridgeGrams)}',
      ),
      trailing: Text(
        'Need\nabout ${_amount(item.purchaseGrams)}',
        textAlign: TextAlign.right,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
  );

  Widget _recipeTile(FridgeRecipeMatch match) => _Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                match.rankedRecipe.recipe.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text('${match.rankedRecipe.recipe.nutrition.calories} kcal'),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${match.rankedRecipe.recipe.nutrition.proteinG} g protein · '
          'You have ${match.availableCount} of ${match.totalCount} ingredients',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 7),
        Text(match.status, style: const TextStyle(fontWeight: FontWeight.w700)),
        if (match.missingIngredients.isNotEmpty)
          Text(
            'Missing: ${match.missingIngredients.map((item) => item.name).join(', ')}',
            style: const TextStyle(color: AppTheme.textSecondary),
          ),
      ],
    ),
  );

  Widget _groceryTile(WeeklyFoodRequirement item) => _Surface(
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.shopping_basket_outlined),
      title: Text(item.food.name),
      trailing: Text('Need about ${_amount(item.purchaseGrams)}'),
    ),
  );

  String _amount(double grams) => grams >= 1000
      ? '${(grams / 1000).toStringAsFixed(1)} kg'
      : '${grams.round()} g';
}

// TEMP DEBUG TOOL - REMOVE AFTER IMAGE REFRESH
class _DebugImageRefreshResult {
  final String key;
  final bool success;
  final String? provider;
  final String? imageUrl;
  final String? message;

  const _DebugImageRefreshResult({
    required this.key,
    required this.success,
    this.provider,
    this.imageUrl,
    this.message,
  });

  String get summary {
    if (!success) return '❌ $key: ${message ?? 'Failed'}';
    return '✅ $key · ${provider ?? 'Unknown provider'}\n${imageUrl ?? ''}';
  }
}

class _Surface extends StatelessWidget {
  final Widget child;
  const _Surface({required this.child});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppTheme.border),
    ),
    child: child,
  );
}

class _InventoryTile extends StatelessWidget {
  final FridgeFoodReference food;
  final Future<FoodVisual> image;
  final FridgeItem? item;
  final bool selected;
  final String amountLabel;
  final VoidCallback onToggle;
  final VoidCallback? onEditQuantity;

  const _InventoryTile({
    required this.food,
    required this.image,
    required this.item,
    required this.selected,
    required this.amountLabel,
    required this.onToggle,
    required this.onEditQuantity,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primaryGreen.withValues(alpha: .055)
          : AppTheme.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9),
        side: BorderSide(
          color: selected
              ? AppTheme.primaryGreen.withValues(alpha: .28)
              : AppTheme.border,
        ),
      ),
      child: InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(9),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 7, 6),
          child: Row(
            children: [
              _IngredientImage(image: image),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.1,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: selected
                            ? AppTheme.primaryGreen
                            : AppTheme.textPrimary,
                      ),
                    ),
                    if (selected)
                      Text(
                        amountLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 19,
                    height: 19,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppTheme.primaryGreen : Colors.white,
                      border: Border.all(
                        color: selected
                            ? AppTheme.primaryGreen
                            : AppTheme.textSecondary.withValues(alpha: .55),
                      ),
                    ),
                    child: selected
                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                        : null,
                  ),
                  if (selected && item != null)
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: IconButton(
                        tooltip: 'Edit amount',
                        onPressed: onEditQuantity,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IngredientImage extends StatelessWidget {
  final Future<FoodVisual> image;

  const _IngredientImage({required this.image});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 56,
        height: 56,
        child: FutureBuilder<FoodVisual>(
          future: image,
          builder: (context, snapshot) {
            final visual = snapshot.data;
            if (visual?.isReady == true) {
              return Image.network(
                visual!.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const _IngredientImagePlaceholder(),
              );
            }
            return const _IngredientImagePlaceholder();
          },
        ),
      ),
    );
  }
}

class _IngredientImagePlaceholder extends StatelessWidget {
  const _IngredientImagePlaceholder();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Color(0xFFEAF3EE),
    child: Icon(
      Icons.restaurant_outlined,
      size: 21,
      color: AppTheme.primaryGreen,
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  final String message;
  const _EmptyCard(this.message);

  @override
  Widget build(BuildContext context) => _Surface(
    child: Text(message, style: const TextStyle(color: AppTheme.textSecondary)),
  );
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback retry;
  const _ErrorState({required this.message, required this.retry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
