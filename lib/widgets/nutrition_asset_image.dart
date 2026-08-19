import 'package:flutter/material.dart';

import 'package:future_project/theme/app_theme.dart';

class NutritionAssetImage extends StatelessWidget {
  final String assetPath;
  final BoxFit fit;
  final BorderRadius borderRadius;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final double? aspectRatio;

  const NutritionAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fallbackIcon = Icons.restaurant_outlined,
    this.width,
    this.height,
    this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = ClipRRect(
      borderRadius: borderRadius,
      child: Image.asset(
        assetPath,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => _Fallback(
          icon: fallbackIcon,
          width: width,
          height: height,
          borderRadius: borderRadius,
        ),
      ),
    );

    if (aspectRatio != null) {
      image = AspectRatio(aspectRatio: aspectRatio!, child: image);
    }

    return image;
  }
}

class _Fallback extends StatelessWidget {
  final IconData icon;
  final double? width;
  final double? height;
  final BorderRadius borderRadius;

  const _Fallback({
    required this.icon,
    required this.width,
    required this.height,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.visionCard,
        borderRadius: borderRadius,
        border: Border.all(color: AppTheme.border),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: AppTheme.primaryGreen, size: 24),
    );
  }
}
