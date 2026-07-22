import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/api_client.dart' as api;
import '../../domain/models/phase.dart';
import '../../state/game_notifier.dart';
import '../../state/game_state.dart';
import '../app_messenger.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import '../widgets/battle_stage.dart';
import 'match_screen.dart';

/// Connects to the backend and hands off to [MatchScreen] once a match is
/// underway. There is no lobby/name-entry UI in this migration's scope (the
/// 14 HUs in docs/PLAN_MIGRACION_FLUTTER.md are entirely about the match
/// screen) — so this generates a throwaway guest name on first launch,
/// persists it (see api_client.dart), and starts an offline match against 3
/// bots automatically (`queue.joinOffline`, WS_CONTRACT.md — no queue wait).
/// A minimal status view covers connecting/reconnecting/error states so the
/// app isn't blank while that happens; wiring this up to a real
/// online-queue/lobby flow is future work outside this plan.
class AppRoot extends ConsumerStatefulWidget {
  const AppRoot({super.key});

  @override
  ConsumerState<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends ConsumerState<AppRoot> {
  // The server's battle-phase pause is only a best-effort estimate of the
  // client animation's real length. Capturing the battle here (instead of
  // rendering straight off the store's lastBattle) lets the overlay outlive
  // a ROUND_START or MATCH_RESULT that arrives before BattleStage says it's
  // actually finished — same "outlive the phase" pattern the web client's
  // Match.tsx uses for the identical reason.
  BattleVm? _overlayBattle;
  bool _overlayDone = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoConnect());
  }

  Future<void> _autoConnect() async {
    final notifier = ref.read(gameNotifierProvider.notifier);
    final stored = await api.loadIdentity();
    if (!mounted) return;
    if (stored != null) {
      notifier.startWithIdentity(stored);
    } else {
      final guestName = 'Player${Random().nextInt(9000) + 1000}';
      await notifier.start(guestName);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameNotifierProvider, (previous, next) {
      // FE-09: surface every server-rejected action as a visible toast while
      // in a match — never a silent no-op. `_StatusScreen` already renders
      // errors inline for the pre-match connecting/lobby states, so this
      // only fires once actually in a match (NOT_YOUR_TURN,
      // INVALID_PLACEMENT, CARD_ALREADY_HELD, etc.).
      final error = next.error;
      if (error != null && next.stage == Stage.match) {
        rootScaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.red.shade900,
          ),
        );
        ref.read(gameNotifierProvider.notifier).dismissError();
      }

      // A genuinely new BATTLE_RESULT arrived — capture it for BattleStage,
      // regardless of what phase/round messages follow it.
      if (next.lastBattle != null &&
          !identical(next.lastBattle, previous?.lastBattle)) {
        setState(() {
          _overlayBattle = next.lastBattle;
          _overlayDone = false;
        });
      }
    });

    final state = ref.watch(gameNotifierProvider);

    if (_overlayDone && state.phase != Phase.battle && _overlayBattle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _overlayBattle = null);
      });
    }

    if (state.stage == Stage.match) {
      final notifier = ref.read(gameNotifierProvider.notifier);
      final matchScreen = MatchScreen(
        ownBoardPoints: state.boards[state.identity?.playerId] ?? const [],
        market: state.market,
        deckRemaining: state.deckRemaining,
        canPick:
            state.phase == Phase.turn &&
            state.currentSeat == state.yourSeat &&
            state.heldBy == null &&
            !state.busy,
        yourCoins:
            state.players
                .where((p) => p.playerId == state.identity?.playerId)
                .map((p) => p.stats.cn)
                .firstOrNull ??
            0,
        finalRound: state.finalRound,
        heldCard: state.heldBy == state.identity?.playerId
            ? state.heldCard
            : null,
        onPick: notifier.pick,
        onRotate: notifier.rotate,
        onPlace: notifier.place,
        phase: state.phase,
        round: state.round,
        currentSeat: state.currentSeat,
        startingSeat: state.startingSeat,
        players: state.players,
        selfId: state.identity?.playerId ?? '',
        boards: state.boards,
        connected: state.connected,
        heldBy: state.heldBy,
      );

      final overlayBattle = _overlayBattle;
      if (overlayBattle == null) return matchScreen;
      return Stack(
        children: [
          matchScreen,
          BattleStage(
            battle: overlayBattle,
            players: state.players,
            selfId: state.identity?.playerId ?? '',
            onFinished: () => setState(() => _overlayDone = true),
          ),
        ],
      );
    }

    return _StatusScreen(state: state);
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _StatusScreen extends ConsumerWidget {
  final GameState state;

  const _StatusScreen({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gameNotifierProvider.notifier);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(BoardArt.boardBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.error != null) ...[
                  Text(
                    state.error!.message,
                    style: const TextStyle(color: AppColors.textLight),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      notifier.dismissError();
                      final identity = state.identity;
                      if (identity != null) {
                        notifier.startWithIdentity(identity);
                      }
                    },
                    child: const Text('Retry'),
                  ),
                ] else if (state.conn == ConnStatus.connected &&
                    state.stage == Stage.lobby) ...[
                  const Text(
                    'Connected',
                    style: TextStyle(color: AppColors.textLight),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: notifier.playOffline,
                    child: const Text('Play vs Bots'),
                  ),
                ] else ...[
                  const CircularProgressIndicator(color: AppColors.gold),
                  const SizedBox(height: 16),
                  Text(
                    _statusLabel(state.conn),
                    style: const TextStyle(color: AppColors.textLight),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _statusLabel(ConnStatus conn) => switch (conn) {
    ConnStatus.idle => 'Starting…',
    ConnStatus.connecting => 'Connecting…',
    ConnStatus.connected => 'Connected',
    ConnStatus.reconnecting => 'Reconnecting…',
    ConnStatus.failed => 'Connection failed',
  };
}
