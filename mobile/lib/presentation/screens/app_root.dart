import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/phase.dart';
import '../../state/game_notifier.dart';
import '../../state/game_state.dart';
import '../app_messenger.dart';
import '../widgets/battle_stage.dart';
import 'match_screen.dart';
import 'menu_screen.dart';
import 'result_screen.dart';

/// Top-level router: shows the pre-match [MenuScreen] (name entry / lobby /
/// queue) until a match starts, then [MatchScreen] with the battle overlay.
/// Mirrors the web client's OnlineScreen.tsx, which switches on the same
/// stages. No auto-connect: the player enters their name and chooses an
/// option, exactly like the web lobby.
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
  Widget build(BuildContext context) {
    ref.listen<GameState>(gameNotifierProvider, (previous, next) {
      // FE-09: surface every server-rejected action as a visible toast while
      // in a match — never a silent no-op. The menu renders errors inline for
      // the pre-match stages, so this only fires once actually in a match
      // (NOT_YOUR_TURN, INVALID_PLACEMENT, CARD_ALREADY_HELD, etc.).
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

      // Leaving a match (e.g. Leave pressed mid-battle) must clear any pending
      // battle overlay so it can't reappear stale over the next match.
      if (previous?.stage == Stage.match &&
          next.stage != Stage.match &&
          _overlayBattle != null) {
        setState(() {
          _overlayBattle = null;
          _overlayDone = false;
        });
      }
    });

    final state = ref.watch(gameNotifierProvider);

    if (state.stage != Stage.match) {
      return const MenuScreen();
    }

    final notifier = ref.read(gameNotifierProvider.notifier);

    // Match over: once the last battle animation has cleared, show the result
    // screen (winner + standings + back-to-menu) instead of a frozen board.
    // Mirrors Match.tsx's `phase === MATCH_OVER && (!overlayBattle || overlayDone)`.
    if (state.phase == Phase.matchOver && _overlayBattle == null) {
      return ResultScreen(
        players: state.players,
        winners: state.winners,
        reason: state.reason,
        selfId: state.identity?.playerId ?? '',
        onExit: notifier.leave,
      );
    }
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
      onLeave: notifier.leave,
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
          // Dismiss the overlay shortly after the animation finishes rather
          // than waiting for the server's ROUND_START (its battle-phase pause
          // can be several seconds longer than the animation — that was the
          // "takes too long after the battle" complaint). The board underneath
          // already has the post-battle HP from BATTLE_RESULT, so showing it
          // early is fine; the next ROUND_START just resets the held card.
          onFinished: () {
            if (_overlayDone) return;
            setState(() => _overlayDone = true);
            Future.delayed(const Duration(milliseconds: 700), () {
              if (mounted) setState(() => _overlayBattle = null);
            });
          },
        ),
      ],
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
