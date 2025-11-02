// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'pages/dashboard_page.dart';

void main() {
  runApp(const ProviderScope(child: NolaKitchenSightsApp()));
}

class NolaKitchenSightsApp extends StatelessWidget {
  const NolaKitchenSightsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nola KitchenSights',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const DashboardPage(),
    );
  }
}
