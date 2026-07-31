import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:future_project/screens/meal_analysis_result_screen.dart';
import 'package:future_project/services/ai_service.dart';
import 'package:future_project/services/meal_service.dart';
import 'package:future_project/theme/app_theme.dart';

class CalorieScannerScreen extends StatefulWidget {
  const CalorieScannerScreen({super.key});

  @override
  State<CalorieScannerScreen> createState() =>
      _CalorieScannerScreenState();
}

class _CalorieScannerScreenState extends State<CalorieScannerScreen> {
  final ImagePicker _picker = ImagePicker();
  final AIService _aiService = const AIService();
  final MealService _mealService = MealService();

  XFile? _selectedImage;
  bool _isAnalyzing = false;

  late Future<List<Map<String, dynamic>>> _recentMealsFuture;

  @override
  void initState() {
    super.initState();
    _refreshRecentMeals();
  }

  void _refreshRecentMeals() {
    _recentMealsFuture = _mealService.getRecentMeals();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (image == null || !mounted) return;

      setState(() {
        _selectedImage = image;
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not select image: $error',
          ),
        ),
      );
    }
  }

  Future<void> _openAnalysisResult() async {
    final XFile? selectedImage = _selectedImage;

    if (selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a meal photo first.',
          ),
        ),
      );
      return;
    }

    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
    });

    try {
      final File imageFile = File(selectedImage.path);

      final result = await _aiService.analyzeMeal(
        imageFile,
      );

final String imageUrl =
    await _mealService.uploadMealImage(imageFile);

await _mealService.saveMeal(
  result: result,
  imagePath: imageUrl,
);

      if (!mounted) return;

      setState(() {
        _refreshRecentMeals();
      });

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MealAnalysisResultScreen(
            imageFile: imageFile,
            result: result,
          ),
        ),
      );

      if (!mounted) return;

      setState(() {
        _refreshRecentMeals();
      });
    } on AIServiceException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Meal analysis failed: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  void _removeSelectedImage() {
    if (_isAnalyzing) return;

    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _deleteMeal(String id) async {
    try {
      await _mealService.deleteMeal(id);

      if (!mounted) return;

      setState(() {
        _refreshRecentMeals();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Meal scan deleted.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not delete meal: $error',
          ),
        ),
      );
    }
  }

  Widget _buildRecentScans() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _recentMealsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState ==
            ConnectionState.waiting) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 42,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Could not load recent scans',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _refreshRecentMeals();
                    });
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          );
        }

        final List<Map<String, dynamic>> meals =
            snapshot.data ?? [];

        if (meals.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.border,
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.restaurant_menu_outlined,
                  size: 42,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'No scans yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Your scanned meals will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: meals.map((meal) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: 12,
              ),
              child: _RecentMealCard(
                meal: meal,
                onDelete: () {
                  final String? id =
                      meal['id']?.toString();

                  if (id == null || id.isEmpty) {
                    return;
                  }

                  _deleteMeal(id);
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'AI Calorie Magnifier',
        ),
        backgroundColor: AppTheme.background,
        foregroundColor: AppTheme.textPrimary,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh scans',
            onPressed: () {
              setState(() {
                _refreshRecentMeals();
              });
            },
            icon: const Icon(
              Icons.refresh,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _refreshRecentMeals();
          });

          await _recentMealsFuture;
        },
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Scan your meal',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Take a photo and let Future estimate calories and protein.',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 28),

            _ActionCard(
              icon: Icons.camera_alt_outlined,
              title: 'Take a photo',
              subtitle:
                  'Use your camera to scan a meal',
              onTap: _isAnalyzing
                  ? null
                  : () => _pickImage(
                        ImageSource.camera,
                      ),
            ),

            const SizedBox(height: 16),

            _ActionCard(
              icon: Icons.photo_library_outlined,
              title: 'Choose from gallery',
              subtitle:
                  'Select an existing food photo',
              onTap: _isAnalyzing
                  ? null
                  : () => _pickImage(
                        ImageSource.gallery,
                      ),
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 30),

              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Selected Meal',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove photo',
                    onPressed: _isAnalyzing
                        ? null
                        : _removeSelectedImage,
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              ClipRRect(
                borderRadius:
                    BorderRadius.circular(20),
                child: Image.file(
                  File(_selectedImage!.path),
                  width: double.infinity,
                  height: 280,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    context,
                    error,
                    stackTrace,
                  ) {
                    return Container(
                      width: double.infinity,
                      height: 280,
                      alignment: Alignment.center,
                      color: AppTheme.card,
                      child: const Text(
                        'Could not display this image.',
                        style: TextStyle(
                          color:
                              AppTheme.textSecondary,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed: _isAnalyzing
                    ? null
                    : _openAnalysisResult,
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                      ),
                label: Text(
                  _isAnalyzing
                      ? 'Analyzing meal...'
                      : 'Analyze Meal',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      AppTheme.primaryGreen,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppTheme.primaryGreen
                          .withValues(alpha: 0.65),
                  disabledForegroundColor:
                      Colors.white,
                  minimumSize:
                      const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(18),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 30),

            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Recent Scans',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () {
                    setState(() {
                      _refreshRecentMeals();
                    });
                  },
                  icon: const Icon(
                    Icons.refresh,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _buildRecentScans(),
          ],
        ),
      ),
    );
  }
}

 class _RecentMealCard extends StatelessWidget {
  final Map<String, dynamic> meal;
  final VoidCallback onDelete;

  const _RecentMealCard({
    required this.meal,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String mealName =
        meal['meal_name']?.toString() ?? 'Unknown meal';

    final int calories =
        (meal['calories'] as num? ?? 0).round();

    final double protein =
        (meal['protein'] as num? ?? 0).toDouble();

    final double carbs =
        (meal['carbs'] as num? ?? 0).toDouble();

    final double fat =
        (meal['fat'] as num? ?? 0).toDouble();

    final String dateText = _formatDate(
      meal['created_at']?.toString(),
    );

    final String imageUrl =
        meal['image_path']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.border,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl.startsWith('http')
                ? Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildFallbackImage();
                    },
                  )
                : _buildFallbackImage(),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  mealName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  '$calories kcal • ${_formatNumber(protein)} g protein',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  '${_formatNumber(carbs)} g carbs • ${_formatNumber(fat)} g fat',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  dateText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          PopupMenuButton<String>(
            tooltip: 'Meal options',
            onSelected: (value) {
              if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (context) {
              return const [
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 10),
                      Text('Delete'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackImage() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.calorieCard,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_outlined,
        color: AppTheme.primaryGreen,
        size: 28,
      ),
    );
  }

  static String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }

    return value.toStringAsFixed(1);
  }

  static String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'Unknown date';
    }

    final DateTime? date =
        DateTime.tryParse(value)?.toLocal();

    if (date == null) {
      return 'Unknown date';
    }

    const months = [
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
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.calorieCard,
            borderRadius:
                BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.border,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppTheme.gold,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color:
                            AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 18,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}