import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/screens/calorie_scanner_screen.dart';
import 'package:future_project/screens/intelligent_coach_screen.dart';
import 'package:future_project/screens/vision_screen.dart';
import 'package:future_project/screens/wearables_hub_screen.dart';
import 'package:future_project/screens/welcome_screen.dart';
import 'package:future_project/theme/app_theme.dart';
import 'package:future_project/widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  void _push(BuildContext context, Widget destination) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
  }

  Future<void> _signOut(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (!context.mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (route) => false,
      );
    } on AuthException catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign out. Please try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DashboardPresentation(
      onCoach: () => _push(context, const IntelligentCoachScreen()),
      onWearables: () => _push(context, const WearablesHubScreen()),
      onVision: () => _push(context, const VisionScreen()),
      onCalorieMagnifier: () => _push(context, const CalorieScannerScreen()),
      onSignOut: () => _signOut(context),
    );
  }
}

class DashboardPresentation extends StatelessWidget {
  static const double desktopSidebarWidth = 150;
  static const double preferredCardWidth = 420;
  static const double minimumCardWidth = 390;

  // Source-of-truth order from stable commit 790bf723. My Vision uses the
  // wide bottom treatment, but retains its original third position here.
  static const List<String> stableHomeDestinationOrder = [
    'Intelligent Coach',
    'Wearables',
    'My Vision',
    'AI Calorie Magnifier',
  ];

  final VoidCallback onCoach;
  final VoidCallback onWearables;
  final VoidCallback onVision;
  final VoidCallback onCalorieMagnifier;
  final VoidCallback onSignOut;

  const DashboardPresentation({
    super.key,
    required this.onCoach,
    required this.onWearables,
    required this.onVision,
    required this.onCalorieMagnifier,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.charcoal,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 980;
          final sidebarWidth = compact ? 116.0 : desktopSidebarWidth;
          return Row(
            children: [
              SizedBox(
                key: const Key('dashboard-sidebar'),
                width: sidebarWidth,
                child: _DashboardSidebar(
                  compact: compact,
                  onCoach: onCoach,
                  onWearables: onWearables,
                  onVision: onVision,
                  onCalorieMagnifier: onCalorieMagnifier,
                  onSignOut: onSignOut,
                ),
              ),
              Expanded(
                child: _DashboardHero(
                  compact: compact,
                  onCoach: onCoach,
                  onWearables: onWearables,
                  onVision: onVision,
                  onCalorieMagnifier: onCalorieMagnifier,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final bool compact;
  final VoidCallback onCoach;
  final VoidCallback onWearables;
  final VoidCallback onVision;
  final VoidCallback onCalorieMagnifier;

  const _DashboardHero({
    required this.compact,
    required this.onCoach,
    required this.onWearables,
    required this.onVision,
    required this.onCalorieMagnifier,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalInset = compact ? 24.0 : 40.0;
        final availableCardWidth = constraints.maxWidth - horizontalInset * 2;
        final cardWidth =
            availableCardWidth >= DashboardPresentation.preferredCardWidth
            ? DashboardPresentation.preferredCardWidth
            : availableCardWidth.clamp(
                280.0,
                DashboardPresentation.minimumCardWidth,
              );
        final artworkAlignment = constraints.maxWidth >= 1250 ? 0.72 : 0.52;

        return ClipRect(
          child: Stack(
            key: const Key('dashboard-hero'),
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/images/muscleup_splash.png',
                key: const Key('dashboard-splash-background'),
                fit: BoxFit.cover,
                alignment: Alignment(artworkAlignment, -0.08),
                filterQuality: FilterQuality.high,
              ),
              const DecoratedBox(
                key: Key('dashboard-asymmetric-overlay'),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xEB000000),
                      Color(0xC9000000),
                      Color(0x70000000),
                      Color(0x26000000),
                    ],
                    stops: [0.0, 0.34, 0.68, 1.0],
                  ),
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0x30000000),
                      Colors.transparent,
                      Color(0x6B000000),
                    ],
                    stops: [0.0, 0.58, 1.0],
                  ),
                ),
              ),
              Positioned(
                top: compact ? 30 : 48,
                left: horizontalInset,
                right: horizontalInset,
                bottom: compact ? 116 : 124,
                child: SingleChildScrollView(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      key: const Key('dashboard-card-column'),
                      width: cardWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _DashboardHeader(),
                          SizedBox(height: compact ? 22 : 30),
                          DashboardCard(
                            key: const Key('dashboard-card-coach'),
                            icon: Icons.psychology_outlined,
                            title: 'Intelligent Coach',
                            subtitle: 'Your daily health guidance',
                            backgroundColor: AppTheme.dashboardCardStrong,
                            iconColor: AppTheme.metallicGold,
                            isHighlighted: true,
                            onTap: onCoach,
                          ),
                          const SizedBox(height: 12),
                          DashboardCard(
                            key: const Key('dashboard-card-wearables'),
                            icon: Icons.watch_outlined,
                            title: 'Wearables',
                            subtitle: 'Health data in personal context',
                            backgroundColor: AppTheme.dashboardCard,
                            iconColor: AppTheme.metallicGold,
                            onTap: onWearables,
                          ),
                          const SizedBox(height: 12),
                          DashboardCard(
                            key: const Key('dashboard-card-vision'),
                            icon: Icons.visibility_outlined,
                            title: 'My Vision',
                            subtitle: 'Visualize your future self',
                            backgroundColor: AppTheme.dashboardCard,
                            iconColor: AppTheme.metallicGold,
                            onTap: onVision,
                          ),
                          const SizedBox(height: 12),
                          DashboardCard(
                            key: const Key('dashboard-card-calorie'),
                            icon: Icons.restaurant_outlined,
                            title: 'AI Calorie Magnifier',
                            subtitle: 'Scan your meal with AI',
                            backgroundColor: AppTheme.dashboardCard,
                            iconColor: AppTheme.metallicGold,
                            onTap: onCalorieMagnifier,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                key: const Key('dashboard-vision-position'),
                left: horizontalInset,
                right: horizontalInset,
                bottom: compact ? 20 : 28,
                child: const _VisionQuoteCard(),
              ),
              Positioned(
                top: compact ? 18 : 28,
                right: compact ? 18 : 30,
                child: const Row(
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: AppTheme.textOnDark,
                      size: 24,
                    ),
                    SizedBox(width: 16),
                    CircleAvatar(
                      radius: 19,
                      backgroundColor: AppTheme.metallicGold,
                      child: Icon(
                        Icons.person_outline,
                        size: 22,
                        color: AppTheme.charcoal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRAIN  ·  IMPROVE  ·  EVOLVE',
          style: TextStyle(
            color: AppTheme.metallicGold,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 2.1,
          ),
        ),
        SizedBox(height: 12),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: 'Welcome Back, '),
              TextSpan(
                text: 'Afshin',
                style: TextStyle(color: AppTheme.metallicGold),
              ),
            ],
          ),
          style: TextStyle(
            color: AppTheme.textOnDark,
            fontSize: 30,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Stronger habits. A better you.',
          style: TextStyle(color: AppTheme.dashboardMutedText, fontSize: 15),
        ),
      ],
    );
  }
}

class _DashboardSidebar extends StatelessWidget {
  final bool compact;
  final VoidCallback onCoach;
  final VoidCallback onWearables;
  final VoidCallback onVision;
  final VoidCallback onCalorieMagnifier;
  final VoidCallback onSignOut;

  const _DashboardSidebar({
    required this.compact,
    required this.onCoach,
    required this.onWearables,
    required this.onVision,
    required this.onCalorieMagnifier,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String label, VoidCallback? onTap})>[
      (icon: Icons.home_rounded, label: 'Home', onTap: null),
      (
        icon: Icons.psychology_outlined,
        label: 'Intelligent Coach',
        onTap: onCoach,
      ),
      (icon: Icons.watch_outlined, label: 'Wearables', onTap: onWearables),
      (icon: Icons.visibility_outlined, label: 'My Vision', onTap: onVision),
      (
        icon: Icons.restaurant_outlined,
        label: 'Calorie Scanner',
        onTap: onCalorieMagnifier,
      ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.charcoal.withValues(alpha: 0.97),
        border: const Border(
          right: BorderSide(color: Color(0x33FFD45A), width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 10 : 14,
            20,
            compact ? 10 : 14,
            18,
          ),
          child: Column(
            children: [
              const _SidebarBrand(),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _SidebarItem(
                      icon: item.icon,
                      label: item.label,
                      active: index == 0,
                      onTap: item.onTap,
                    );
                  },
                ),
              ),
              const _SidebarMotto(),
              const SizedBox(height: 12),
              IconButton(
                tooltip: 'Sign Out',
                onPressed: onSignOut,
                icon: const Icon(
                  Icons.logout_outlined,
                  color: AppTheme.dashboardMutedText,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Text(
          'MU',
          style: TextStyle(
            color: AppTheme.metallicGold,
            fontSize: 34,
            height: 1,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -3,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'MUSCLE UP',
          style: TextStyle(
            color: AppTheme.textOnDark,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.3,
          ),
        ),
      ],
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.metallicGold : AppTheme.textOnDark;
    return Material(
      color: active
          ? AppTheme.deepGold.withValues(alpha: 0.16)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: active
                ? const Border(
                    left: BorderSide(color: AppTheme.metallicGold, width: 3),
                  )
                : null,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SidebarMotto extends StatelessWidget {
  const _SidebarMotto();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 34,
          child: Divider(color: AppTheme.metallicGold, thickness: 2),
        ),
        SizedBox(height: 5),
        Text(
          'TRAIN\nIMPROVE\nEVOLVE',
          style: TextStyle(
            color: AppTheme.textOnDark,
            fontSize: 10,
            height: 1.55,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.8,
          ),
        ),
      ],
    );
  }
}

class _VisionQuoteCard extends StatelessWidget {
  const _VisionQuoteCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dashboard-vision-quote'),
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: AppTheme.dashboardCardStrong.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppTheme.metallicGold.withValues(alpha: 0.9),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brightGold.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.format_quote_rounded,
            color: AppTheme.metallicGold,
            size: 30,
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Trust your belief, let your actions bring it to life.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppTheme.textOnDark,
                fontSize: 16,
                height: 1.25,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 20),
          Container(
            width: 1,
            height: 38,
            color: AppTheme.metallicGold.withValues(alpha: 0.75),
          ),
          const SizedBox(width: 20),
          const Text(
            'MAKE IT\nHAPPEN',
            style: TextStyle(
              color: AppTheme.metallicGold,
              fontSize: 10,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 18),
          const Icon(
            Icons.arrow_forward_ios,
            color: AppTheme.metallicGold,
            size: 18,
          ),
        ],
      ),
    );
  }
}
