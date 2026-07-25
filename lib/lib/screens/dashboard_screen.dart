import 'package:flutter/material.dart';
import '../widgets/dashboard_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Future Project'),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: const ListView(
        padding: EdgeInsets.all(24),
        children: [
          DashboardCard(
            icon: Icons.visibility_outlined,
            title: 'My Vision',
          ),
          SizedBox(height: 18),
          DashboardCard(
            icon: Icons.route_outlined,
            title: 'Our Journey',
          ),
          SizedBox(height: 18),
          DashboardCard(
            icon: Icons.restaurant_outlined,
            title: 'AI Calorie Magnifier',
          ),
        ],
      ),
    );
  }
}
