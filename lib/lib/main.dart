import 'package:flutter/material.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const FutureProjectApp());
}

class FutureProjectApp extends StatelessWidget {
  const FutureProjectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Future Project',
      theme: AppTheme.darkTheme,
      home: const WelcomeScreen(),
    );
  }
}
