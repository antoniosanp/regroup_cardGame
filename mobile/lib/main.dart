import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/api_client.dart' as api;
import 'presentation/app_messenger.dart';
import 'presentation/screens/app_root.dart';
import 'presentation/theme/app_colors.dart';
import 'sfx/sfx.dart';

Future<void> main() async {
  // Some audioplayers/ExoPlayer decode failures (seen on real devices as
  // `PlatformException(AndroidAudioError, MEDIA_ERROR_UNKNOWN, ...)`) are
  // reported by the native side well after `player.play()`'s own Future has
  // already resolved, on a platform-channel callback with no Dart await
  // frame to catch it — so `sfx.dart`'s own try/catch around the `play()`
  // call never sees it, and it surfaces as an app-wide "Unhandled Exception"
  // instead. A sound failing to play should never be able to destabilize
  // anything else in the game, so `runZonedGuarded` is the outer safety net:
  // catch anything that gets this far, log it, and keep going.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      // Landscape-only per the migration plan (docs/PLAN_MIGRACION_FLUTTER.md,
      // section 1.3): this is a horizontal-first mobile redesign, not a
      // portrait adaptation of the web layout.
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await Sfx.instance.init();
      await api.loadBackendOverride();
      runApp(const ProviderScope(child: RegroupApp()));
    },
    (error, stack) {
      debugPrint('Uncaught async error (ignored, app keeps running): $error');
    },
  );
}

class RegroupApp extends StatelessWidget {
  const RegroupApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Wood/parchment identity, matching the web client's styles.css palette
    // (see app_colors.dart) instead of a generic Material dark theme.
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.wood,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      secondary: AppColors.accent,
      surface: AppColors.iron,
      error: AppColors.error,
    );
    return MaterialApp(
      title: 'Regroup',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: AppColors.woodDark,
        // Closest built-in match to the web app's Georgia/Iowan Old Style
        // serif — no bundled TTF needed, Android/iOS both map "serif" to
        // their platform serif typeface.
        fontFamily: 'serif',
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'serif',
          bodyColor: AppColors.textLight,
          displayColor: AppColors.textLight,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.wood,
            foregroundColor: AppColors.textLight,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textLight,
            side: const BorderSide(color: AppColors.woodLight),
          ),
        ),
      ),
      home: const AppRoot(),
    );
  }
}
