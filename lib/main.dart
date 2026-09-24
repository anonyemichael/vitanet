import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:vitanet/app/router.dart';
import 'package:vitanet/app/theme.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'firebase_options.dart';

import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Failed to load .env file: $e');
  }

  // Try to initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint(
      'Firebase initialization failed. Did you run `flutterfire configure`? Error: $e',
    );
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const VitaNetApp(),
    ),
  );
}

class VitaNetApp extends ConsumerStatefulWidget {
  const VitaNetApp({super.key});

  @override
  ConsumerState<VitaNetApp> createState() => _VitaNetAppState();
}

class _VitaNetAppState extends ConsumerState<VitaNetApp> {
  @override
  void initState() {
    super.initState();
    // Defer permission requests to after the first frame so the UI
    // renders immediately instead of blocking on GPS/Health authorization.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestPermissions();
    });
  }

  Future<void> _requestPermissions() async {
    try {
      await Geolocator.requestPermission();
      if (!kIsWeb) {
        await ref.read(healthServiceProvider).requestPermissions();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'VitaNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      routerConfig: ref.watch(goRouterProvider),
    );
  }
}
