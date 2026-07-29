import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vitanet_frontend/screens/type_selection.dart';
import 'package:vitanet_frontend/screens/welcome_screen.dart';
import 'package:vitanet_frontend/themes/app_theme.dart';

import 'providers/theme_provider.dart';


void main() {
  runApp(const ProviderScope(child: VitaNetApp()));
}

class VitaNetApp extends ConsumerWidget {
  const VitaNetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'VitaNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      home: const WelcomeScreen(),
    );
  }
}