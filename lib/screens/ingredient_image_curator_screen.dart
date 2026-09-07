import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/debug/ingredient_image_refresh_key.dart';
import 'package:future_project/models/intelligent_fridge.dart';
import 'package:future_project/services/intelligent_fridge_service.dart';
import 'package:future_project/theme/app_theme.dart';

// TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
class IngredientImageCuratorScreen extends StatefulWidget {
  const IngredientImageCuratorScreen({super.key});

  @override
  State<IngredientImageCuratorScreen> createState() =>
      _IngredientImageCuratorScreenState();
}

// TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
class _IngredientImageCuratorScreenState
    extends State<IngredientImageCuratorScreen> {
  final _supabase = Supabase.instance.client;
  final _statuses = <String, _CuratorIngredientState>{};
  String _search = '';
  String _category = 'All';
  String _queueFilter = 'All unresolved';
  _CuratorStatusFilter _statusFilter = _CuratorStatusFilter.all;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    assert(kDebugMode, 'Ingredient image curator is debug-only.');
    _loadStatuses();
  }

  Future<void> _loadStatuses() async {
    if (_supabase.auth.currentSession == null) {
      setState(() {
        _loading = false;
        _error = 'Sign in before using the ingredient image curator.';
      });
      return;
    }
    try {
      final response = await _supabase.functions.invoke(
        'resolve-food-image',
        body: {
          'action': 'statuses',
          'ingredientKeys': FridgeFoodCatalog.foods
              .map((food) => food.key)
              .toList(),
        },
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final ingredients = map['ingredients'];
      if (ingredients is! List) throw const FormatException();
      final statuses = <String, _CuratorIngredientState>{};
      for (final value in ingredients) {
        if (value is! Map) continue;
        final status = _CuratorIngredientState.fromMap(
          Map<String, dynamic>.from(value),
        );
        statuses[status.ingredientKey] = status;
      }
      if (!mounted) return;
      setState(() {
        _statuses
          ..clear()
          ..addAll(statuses);
        _loading = false;
        _error = null;
      });
    } on FunctionException catch (error) {
      _setError(_functionMessage(error.details));
    } catch (_) {
      _setError('Could not load ingredient curation status.');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = message;
    });
  }

  String _functionMessage(dynamic details) {
    if (details is Map) {
      final message = details['error']?.toString().trim();
      if (message?.isNotEmpty == true) return message!;
    }
    return 'The curator request failed.';
  }

  List<FridgeFoodReference> get _visibleFoods {
    final query = _search.trim().toLowerCase();
    return FridgeFoodCatalog.foods.where((food) {
      final state =
          _statuses[food.key] ?? _CuratorIngredientState.uncurated(food.key);
      return (query.isEmpty ||
              food.name.toLowerCase().contains(query) ||
              food.key.contains(query)) &&
          (_category == 'All' || food.category == _category) &&
          (_statusFilter == _CuratorStatusFilter.all ||
              state.status.name == _statusFilter.name);
    }).toList();
  }

  Future<void> _openIngredient(FridgeFoodReference food) async {
    final state =
        _statuses[food.key] ?? _CuratorIngredientState.uncurated(food.key);
    final updates = await Navigator.of(context)
        .push<Map<String, _CuratorIngredientState>>(
          MaterialPageRoute(
            builder: (_) => _CandidateReviewScreen(
              foods: [food],
              initialStates: {food.key: state},
              initialApprovedCount: _approvedCount,
              totalCount: FridgeFoodCatalog.foods.length,
            ),
          ),
        );
    if (updates != null && mounted) {
      setState(() => _statuses.addAll(updates));
    } else if (mounted) {
      await _loadStatuses();
    }
  }

  int get _approvedCount => FridgeFoodCatalog.foods.where((food) {
    final state =
        _statuses[food.key] ?? _CuratorIngredientState.uncurated(food.key);
    return state.status == _CuratorStatus.approved;
  }).length;

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

  Future<void> _startReview() async {
    final queue = FridgeFoodCatalog.foods.where((food) {
      final state =
          _statuses[food.key] ?? _CuratorIngredientState.uncurated(food.key);
      return state.status != _CuratorStatus.approved &&
          (_queueFilter == 'All unresolved' ||
              _displayCategory(food) == _queueFilter);
    }).toList();
    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No unresolved ingredients match.')),
      );
      return;
    }
    final updates = await Navigator.of(context)
        .push<Map<String, _CuratorIngredientState>>(
          MaterialPageRoute(
            builder: (_) => _CandidateReviewScreen(
              foods: queue,
              initialStates: {
                for (final food in queue)
                  food.key:
                      _statuses[food.key] ??
                      _CuratorIngredientState.uncurated(food.key),
              },
              initialApprovedCount: _approvedCount,
              totalCount: FridgeFoodCatalog.foods.length,
              queueMode: true,
            ),
          ),
        );
    if (updates != null && mounted) {
      setState(() => _statuses.addAll(updates));
    } else if (mounted) {
      await _loadStatuses();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return const SizedBox.shrink();
    final foods = _visibleFoods;
    final states = FridgeFoodCatalog.foods.map(
      (food) =>
          _statuses[food.key] ?? _CuratorIngredientState.uncurated(food.key),
    );
    int count(_CuratorStatus status) =>
        states.where((state) => state.status == status).length;
    final approved = _approvedCount;
    final total = FridgeFoodCatalog.foods.length;
    final categories = <String>{
      'All',
      ...FridgeFoodCatalog.foods.map((food) => food.category),
    }.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Ingredient Image Curator')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _loadStatuses,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadStatuses,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Approved $approved / Total $total',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Missing ${count(_CuratorStatus.missing)}  ·  '
                    'Uncurated ${count(_CuratorStatus.uncurated)}  ·  '
                    'Failed ${count(_CuratorStatus.failed)}',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Review Queue',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      DropdownButton<String>(
                        value: _queueFilter,
                        items: _queueFilters
                            .map(
                              (filter) => DropdownMenuItem(
                                value: filter,
                                child: Text(filter),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _queueFilter = value ?? 'All unresolved',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _startReview,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start Review'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      labelText: 'Search ingredients',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      DropdownButton<String>(
                        value: _category,
                        items: categories
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _category = value ?? 'All'),
                      ),
                      DropdownButton<_CuratorStatusFilter>(
                        value: _statusFilter,
                        items: _CuratorStatusFilter.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () =>
                              _statusFilter = value ?? _CuratorStatusFilter.all,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final food in foods)
                    _IngredientRow(
                      food: food,
                      state:
                          _statuses[food.key] ??
                          _CuratorIngredientState.uncurated(food.key),
                      onTap: () => _openIngredient(food),
                    ),
                  if (foods.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('No ingredients match.')),
                    ),
                ],
              ),
            ),
    );
  }

  static const _queueFilters = [
    'All unresolved',
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
}

// TEMP DEBUG CURATOR - REMOVE AFTER IMAGE LIBRARY IS APPROVED
class _CandidateReviewScreen extends StatefulWidget {
  final List<FridgeFoodReference> foods;
  final Map<String, _CuratorIngredientState> initialStates;
  final int initialApprovedCount;
  final int totalCount;
  final bool queueMode;

  const _CandidateReviewScreen({
    required this.foods,
    required this.initialStates,
    required this.initialApprovedCount,
    required this.totalCount,
    this.queueMode = false,
  });

  @override
  State<_CandidateReviewScreen> createState() => _CandidateReviewScreenState();
}

class _CandidateReviewScreenState extends State<_CandidateReviewScreen> {
  final _supabase = Supabase.instance.client;
  final _updates = <String, _CuratorIngredientState>{};
  final _candidateSessions = <String, _CandidateSession>{};
  late _CuratorIngredientState _current;
  int _index = 0;
  List<_ImageCandidate>? _candidates;
  String? _error;
  String? _approvingId;
  String _shortcutProvider = 'pexels';
  int _candidateLoadGeneration = 0;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _updates.addAll(widget.initialStates);
    _current =
        _updates[_food.key] ?? _CuratorIngredientState.uncurated(_food.key);
    _loadCandidates();
  }

  FridgeFoodReference get _food => widget.foods[_index];

  int get _approvedCount =>
      widget.initialApprovedCount +
      _updates.entries.where((entry) {
        final initial = widget.initialStates[entry.key];
        return initial?.status != _CuratorStatus.approved &&
            entry.value.status == _CuratorStatus.approved;
      }).length;

  Future<void> _loadCandidates({bool more = false}) async {
    final generation = ++_candidateLoadGeneration;
    final ingredientKey = _food.key;
    final session = _candidateSessions.putIfAbsent(
      ingredientKey,
      _CandidateSession.new,
    );
    final pexelsPage = more ? session.pexelsPage + 1 : session.pexelsPage;
    final pixabayPage = more ? session.pixabayPage + 1 : session.pixabayPage;
    setState(() {
      if (more) {
        _loadingMore = true;
      } else {
        _candidates = null;
      }
      _error = null;
    });
    try {
      final response = await _supabase.functions.invoke(
        'resolve-food-image',
        body: {
          'action': 'candidates',
          'ingredientKey': ingredientKey,
          'pexelsPage': pexelsPage,
          'pixabayPage': pixabayPage,
        },
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final values = map['candidates'];
      if (values is! List) throw const FormatException();
      final candidates = values
          .whereType<Map>()
          .map(
            (value) =>
                _ImageCandidate.fromMap(Map<String, dynamic>.from(value)),
          )
          .where((candidate) => session.seen.add(candidate.identity))
          .toList();
      if (!mounted || generation != _candidateLoadGeneration) return;
      session
        ..pexelsPage = pexelsPage
        ..pixabayPage = pixabayPage;
      if (candidates.isNotEmpty || !more) {
        session.candidates = candidates;
      }
      setState(() {
        _loadingMore = false;
        _candidates = session.candidates;
      });
      if (more && candidates.isEmpty) {
        _showMessage('No more suitable images found.');
      }
    } on FunctionException catch (error) {
      if (generation != _candidateLoadGeneration) return;
      if (more) {
        setState(() => _loadingMore = false);
        _showMessage(_functionMessage(error.details));
      } else {
        _setCandidateError(_functionMessage(error.details));
      }
    } catch (_) {
      if (generation != _candidateLoadGeneration) return;
      if (more) {
        setState(() => _loadingMore = false);
        _showMessage('Could not load more image candidates.');
      } else {
        _setCandidateError('Could not load image candidates.');
      }
    }
  }

  String _functionMessage(dynamic details) {
    if (details is Map) {
      final message = details['error']?.toString().trim();
      if (message?.isNotEmpty == true) return message!;
    }
    return 'The curator request failed.';
  }

  void _setCandidateError(String message) {
    if (!mounted) return;
    setState(() {
      _candidates = const [];
      _error = message;
    });
  }

  Future<void> _approve(_ImageCandidate candidate) async {
    if (!IngredientImageRefreshKey.hasRefreshKey) {
      _showMessage(
        'Approval stopped: INGREDIENT_IMAGE_REFRESH_KEY was not supplied.',
      );
      return;
    }
    final refreshKey = IngredientImageRefreshKey.refreshKey;
    if (_supabase.auth.currentSession == null) {
      _showMessage('Approval stopped: no signed-in Supabase session exists.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          _current.status == _CuratorStatus.approved
              ? 'Replace approved image?'
              : 'Approve this image?',
        ),
        content: Text(
          '${_food.name} will use this ${candidate.provider.toUpperCase()} image as its canonical image.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              _current.status == _CuratorStatus.approved
                  ? 'Replace Approved Image'
                  : 'Approve',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _approvingId = candidate.identity);
    try {
      final response = await _supabase.functions.invoke(
        'resolve-food-image',
        headers: {'x-image-refresh-key': refreshKey},
        body: {
          'action': 'approve',
          'ingredientKey': _food.key,
          'provider': candidate.provider,
          'providerId': candidate.providerId,
          'downloadUrl': candidate.downloadUrl,
          'candidateToken': candidate.candidateToken,
        },
      );
      final data = response.data;
      final map = data is Map
          ? Map<String, dynamic>.from(data)
          : const <String, dynamic>{};
      final imageUrl = map['imageUrl']?.toString().trim();
      if (imageUrl?.isNotEmpty != true) throw const FormatException();
      final approved = _CuratorIngredientState(
        ingredientKey: _food.key,
        status: _CuratorStatus.approved,
        imageUrl: imageUrl,
        provider: candidate.provider,
      );
      if (!mounted) return;
      setState(() {
        _current = approved;
        _updates[_food.key] = approved;
        _approvingId = null;
      });
      _showMessage('Approved image saved for ${_food.name}.');
      if (widget.queueMode && _index < widget.foods.length - 1) {
        _move(1);
      } else if (widget.queueMode) {
        _showMessage('Review queue complete.');
      }
    } on FunctionException catch (error) {
      if (!mounted) return;
      setState(() => _approvingId = null);
      _showMessage(_functionMessage(error.details));
    } catch (_) {
      if (!mounted) return;
      setState(() => _approvingId = null);
      _showMessage('Could not approve the selected image.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _move(int delta) {
    if (_approvingId != null) return;
    final target = _index + delta;
    if (target < 0 || target >= widget.foods.length) return;
    _candidateLoadGeneration++;
    setState(() {
      _index = target;
      _current =
          _updates[_food.key] ?? _CuratorIngredientState.uncurated(_food.key);
      _candidates = _candidateSessions[_food.key]?.candidates;
      _loadingMore = false;
      _error = null;
    });
    if (_candidates == null) _loadCandidates();
  }

  void _approveShortcut(int index) {
    if (_approvingId != null) return;
    final candidates = _candidates
        ?.where((candidate) => candidate.provider == _shortcutProvider)
        .toList();
    if (candidates == null || index < 0 || index >= candidates.length) return;
    _approve(candidates[index]);
  }

  void _returnResult() {
    Navigator.pop(context, _updates);
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidates;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _move(-1),
        const SingleActivator(LogicalKeyboardKey.keyS): () => _move(1),
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _approveShortcut(0),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _approveShortcut(1),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _approveShortcut(2),
        const SingleActivator(LogicalKeyboardKey.digit4): () =>
            _approveShortcut(3),
        const SingleActivator(LogicalKeyboardKey.digit5): () =>
            _approveShortcut(4),
        const SingleActivator(LogicalKeyboardKey.digit6): () =>
            _approveShortcut(5),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              widget.queueMode ? 'Review Queue' : 'Ingredient Image Curator',
            ),
            leading: BackButton(onPressed: _returnResult),
          ),
          body: candidates == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (widget.queueMode) ...[
                      Text(
                        'Approved $_approvedCount / Total ${widget.totalCount}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        'Queue item ${_index + 1} of ${widget.foods.length}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Text(
                      _food.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      '${_food.key}  ·  ${_food.category}',
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _index > 0 ? () => _move(-1) : null,
                          child: const Text('Previous'),
                        ),
                        OutlinedButton(
                          onPressed: _index < widget.foods.length - 1
                              ? () => _move(1)
                              : null,
                          child: const Text('Skip'),
                        ),
                        FilledButton.tonal(
                          onPressed: _index < widget.foods.length - 1
                              ? () => _move(1)
                              : null,
                          child: const Text('Next'),
                        ),
                        FilledButton.icon(
                          onPressed: _loadingMore
                              ? null
                              : () => _loadCandidates(more: true),
                          icon: _loadingMore
                              ? const SizedBox.square(
                                  dimension: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.add_photo_alternate_outlined),
                          label: const Text('Get More Images'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CURRENT IMAGE',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_current.imageUrl != null)
                      SizedBox(
                        height: 190,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: _NetworkThumbnail(url: _current.imageUrl!),
                          ),
                        ),
                      )
                    else
                      const Text('No current image.'),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      Text(_error!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _loadCandidates,
                          child: const Text('Retry'),
                        ),
                      ),
                    ] else ...[
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('1–6 shortcut section:'),
                          ChoiceChip(
                            label: const Text('Pexels'),
                            selected: _shortcutProvider == 'pexels',
                            onSelected: (_) =>
                                setState(() => _shortcutProvider = 'pexels'),
                          ),
                          ChoiceChip(
                            label: const Text('Pixabay'),
                            selected: _shortcutProvider == 'pixabay',
                            onSelected: (_) =>
                                setState(() => _shortcutProvider = 'pixabay'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _CandidateSection(
                        provider: 'pexels',
                        candidates: candidates
                            .where((item) => item.provider == 'pexels')
                            .toList(),
                        approvingId: _approvingId,
                        replaceMode: _current.status == _CuratorStatus.approved,
                        shortcutActive: _shortcutProvider == 'pexels',
                        onApprove: _approve,
                      ),
                      const SizedBox(height: 24),
                      _CandidateSection(
                        provider: 'pixabay',
                        candidates: candidates
                            .where((item) => item.provider == 'pixabay')
                            .toList(),
                        approvingId: _approvingId,
                        replaceMode: _current.status == _CuratorStatus.approved,
                        shortcutActive: _shortcutProvider == 'pixabay',
                        onApprove: _approve,
                      ),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  final FridgeFoodReference food;
  final _CuratorIngredientState state;
  final VoidCallback onTap;

  const _IngredientRow({
    required this.food,
    required this.state,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      leading: SizedBox.square(
        dimension: 52,
        child: state.imageUrl == null
            ? const ColoredBox(
                color: Color(0xFFE9ECEA),
                child: Icon(Icons.image_not_supported_outlined),
              )
            : _NetworkThumbnail(url: state.imageUrl!),
      ),
      title: Text(food.name),
      subtitle: Text('${food.key}\n${food.category}'),
      isThreeLine: true,
      trailing: Text(
        state.status.label,
        style: TextStyle(
          color: state.status == _CuratorStatus.approved
              ? AppTheme.primaryGreen
              : AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
  );
}

class _CandidateSection extends StatelessWidget {
  final String provider;
  final List<_ImageCandidate> candidates;
  final String? approvingId;
  final bool replaceMode;
  final bool shortcutActive;
  final ValueChanged<_ImageCandidate> onApprove;

  const _CandidateSection({
    required this.provider,
    required this.candidates,
    required this.approvingId,
    required this.replaceMode,
    required this.shortcutActive,
    required this.onApprove,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '${provider.toUpperCase()}${shortcutActive ? ' (1–6)' : ''}',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 10),
      if (candidates.isEmpty)
        const Text('No candidates returned.')
      else
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1000
                ? 4
                : constraints.maxWidth >= 680
                ? 3
                : constraints.maxWidth >= 430
                ? 2
                : 1;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: candidates.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                mainAxisExtent: 310,
              ),
              itemBuilder: (context, index) {
                final candidate = candidates[index];
                final approving = approvingId == candidate.identity;
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _NetworkThumbnail(url: candidate.previewUrl),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                        child: Text(
                          '${candidate.provider.toUpperCase()}  ·  Score ${candidate.score}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Text(
                          candidate.metadata.isEmpty
                              ? 'No description available'
                              : candidate.metadata,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                        child: FilledButton(
                          onPressed: approvingId == null
                              ? () => onApprove(candidate)
                              : null,
                          child: approving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  replaceMode
                                      ? 'Replace Approved Image'
                                      : 'Approve',
                                ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
    ],
  );
}

class _NetworkThumbnail extends StatelessWidget {
  final String url;

  const _NetworkThumbnail({required this.url});

  @override
  Widget build(BuildContext context) => Image.network(
    url,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => const ColoredBox(
      color: Color(0xFFE9ECEA),
      child: Icon(Icons.broken_image_outlined),
    ),
  );
}

enum _CuratorStatus {
  approved('APPROVED'),
  missing('MISSING'),
  failed('FAILED'),
  uncurated('UNCURATED');

  final String label;
  const _CuratorStatus(this.label);
}

enum _CuratorStatusFilter {
  all('All statuses'),
  approved('APPROVED'),
  missing('MISSING'),
  failed('FAILED'),
  uncurated('UNCURATED');

  final String label;
  const _CuratorStatusFilter(this.label);
}

class _CuratorIngredientState {
  final String ingredientKey;
  final _CuratorStatus status;
  final String? imageUrl;
  final String? provider;

  const _CuratorIngredientState({
    required this.ingredientKey,
    required this.status,
    this.imageUrl,
    this.provider,
  });

  factory _CuratorIngredientState.uncurated(String key) =>
      _CuratorIngredientState(
        ingredientKey: key,
        status: _CuratorStatus.uncurated,
      );

  factory _CuratorIngredientState.fromMap(Map<String, dynamic> map) {
    final statusName = map['status']?.toString() ?? 'uncurated';
    return _CuratorIngredientState(
      ingredientKey: map['ingredientKey']?.toString() ?? '',
      status: _CuratorStatus.values.firstWhere(
        (status) => status.name == statusName,
        orElse: () => _CuratorStatus.uncurated,
      ),
      imageUrl: map['imageUrl']?.toString(),
      provider: map['provider']?.toString(),
    );
  }
}

class _CandidateSession {
  int pexelsPage = 1;
  int pixabayPage = 1;
  final Set<String> seen = {};
  List<_ImageCandidate>? candidates;
}

class _ImageCandidate {
  final String provider;
  final String providerId;
  final String previewUrl;
  final String downloadUrl;
  final String metadata;
  final int score;
  final String candidateToken;

  const _ImageCandidate({
    required this.provider,
    required this.providerId,
    required this.previewUrl,
    required this.downloadUrl,
    required this.metadata,
    required this.score,
    required this.candidateToken,
  });

  String get identity => '$provider:$providerId';

  factory _ImageCandidate.fromMap(Map<String, dynamic> map) => _ImageCandidate(
    provider: map['provider']?.toString() ?? '',
    providerId: map['providerId']?.toString() ?? '',
    previewUrl: map['previewUrl']?.toString() ?? '',
    downloadUrl: map['downloadUrl']?.toString() ?? '',
    metadata: map['metadata']?.toString() ?? '',
    score: (map['score'] as num?)?.round() ?? 0,
    candidateToken: map['candidateToken']?.toString() ?? '',
  );
}
