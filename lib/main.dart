import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:future_project/config/supabase_config.dart';
import 'package:future_project/screens/welcome_screen.dart';
import 'package:future_project/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );

  runApp(const FutureProjectApp());
}

class FutureProjectApp extends StatelessWidget {
  const FutureProjectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Future Project',
      theme: AppTheme.lightTheme,
      home: const WelcomeScreen(),
    );
  }
}