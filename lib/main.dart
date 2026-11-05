import 'dart:ui' show PointerDeviceKind;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:vitanet/firebase_options.dart';
import 'package:vitanet/app/router.dart';
import 'package:vitanet/app/theme.dart';
import 'package:vitanet/data/providers/providers.dart';
import 'package:vitanet/data/services/daily_med_service.dart';
import 'package:vitanet/features/settings/settings_providers.dart';
import 'package:vitanet/shared/widgets/vn_kit.dart';

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // High-capacity image cache to prevent image re-loading and GC stutters
  PaintingBinding.instance.imageCache.maximumSize = 600;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 120 * 1024 * 1024; // 120 MB cap

  // Initialize persistent DailyMed image cache
  DailyMedService.instance.init().catchError((_) {});

  // Only preserve native window splash on mobile platforms (Android/iOS).
  // On Web, remove it immediately so the HTML splash logo never covers the screen.
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  } else {
    FlutterNativeSplash.remove();
  }


  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences initialization failed: $e');
  }

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null) sharedPreferencesProvider.overrideWith((ref) => prefs),
      ],
      child: const VitaNetApp(),
    ),
  );
}

class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    switch (getPlatform(context)) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return const BouncingScrollPhysics();
      default:
        return const VnScrollPhysics();
    }
  }
}

class VitaNetApp extends ConsumerWidget {
  const VitaNetApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final textScale = ref.watch(textScaleProvider);

    return MaterialApp.router(
      title: 'VitaNet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      scrollBehavior: const AppScrollBehavior(),
      routerConfig: ref.watch(goRouterProvider),
      builder: (context, child) {
        if (textScale == 1.0 || child == null) return child ?? const SizedBox.shrink();
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            textScaler: TextScaler.linear(mq.textScaler.scale(1) * textScale),
          ),
          child: child,
        );
      },
    );
  }
}
