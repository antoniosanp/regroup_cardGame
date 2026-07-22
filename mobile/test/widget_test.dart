// Smoke tests for MatchScreen (FE-04..FE-07 layout/widgets) and the app's
// entry point (FE-11's AppRoot). Per project rule (see
// docs/PLAN_MIGRACION_FLUTTER.md section 11), this file is written but never
// executed — `flutter test` is off-limits, only `flutter analyze`/`flutter
// build` verify it compiles.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:regroup_mobile/main.dart';
import 'package:regroup_mobile/presentation/screens/match_screen.dart';
import 'package:regroup_mobile/presentation/widgets/info_panel.dart';
import 'package:regroup_mobile/presentation/widgets/market_panel.dart';

void main() {
  testWidgets('MatchScreen renders its three landscape zones', (WidgetTester tester) async {
    // MatchScreen itself needs no ProviderScope — it's still presentational
    // (constructor params only, see FE-04's scope decision); AppRoot is the
    // piece that reads from GameNotifier via Riverpod.
    await tester.pumpWidget(const MaterialApp(home: MatchScreen()));

    expect(find.byType(MatchScreen), findsOneWidget);
    expect(find.byType(MarketPanel), findsOneWidget);
    expect(find.byType(InfoPanel), findsOneWidget);
    expect(find.text('Draw · Free'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);
    expect(find.text('No cards placed yet'), findsOneWidget);
  });

  testWidgets('RegroupApp builds under a ProviderScope without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: RegroupApp()));
    // AppRoot starts on its connecting/status view (no live backend in this
    // test environment) — this just verifies the app tree constructs.
  });
}
