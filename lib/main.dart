import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/config/supabase_config.dart';
import 'package:future_project/screens/dashboard_screen.dart';
import 'package:future_project/screens/welcome_screen.dart';
import 'package:future_project/theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  unawaited(_setSplashSystemUi());
  runApp(const MuscleUpStartup());
}

Future<void> _initializeApp() async {
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
}

Future<void> _setSplashSystemUi() async {
  try {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: const <SystemUiOverlay>[],
    );
  } on PlatformException {
    // Some desktop embedders do not expose system UI controls.
  }
}

Future<void> _restoreSystemUi() async {
  try {
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  } on PlatformException {
    // Some desktop embedders do not expose system UI controls.
  }
}

class MuscleUpStartup extends StatefulWidget {
  const MuscleUpStartup({
    super.key,
    this.initialize = _initializeApp,
    this.destination = const FutureProjectApp(),
  });

  static const Duration splashDuration = Duration(milliseconds: 1800);

  final Future<void> Function() initialize;
  final Widget destination;

  @override
  State<MuscleUpStartup> createState() => _MuscleUpStartupState();
}

class _MuscleUpStartupState extends State<MuscleUpStartup> {
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _completeStartup();
  }

  Future<void> _completeStartup() async {
    await Future.wait<void>(<Future<void>>[
      widget.initialize(),
      Future<void>.delayed(MuscleUpStartup.splashDuration),
    ]);
    if (!mounted) return;

    unawaited(_restoreSystemUi());
    setState(() => _isReady = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isReady) return widget.destination;

    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SizedBox.expand(
        child: Image(
          image: AssetImage('assets/images/muscleup_splash.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}

class FutureProjectApp extends StatelessWidget {
  const FutureProjectApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Session? session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Future Project',
      theme: AppTheme.lightTheme,
      home: session != null ? const DashboardScreen() : const WelcomeScreen(),
    );
  }
}
