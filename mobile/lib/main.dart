import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'presentation/app_messenger.dart';
import 'presentation/screens/app_root.dart';
import 'presentation/theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Landscape-only per the migration plan (docs/PLAN_MIGRACION_FLUTTER.md,
  // section 1.3): this is a horizontal-first mobile redesign, not a portrait
  // adaptation of the web layout.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const ProviderScope(child: RegroupApp()));
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
