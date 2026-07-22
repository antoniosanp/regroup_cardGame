import 'package:flutter/material.dart';

import '../../domain/models/board_point.dart';
import '../../domain/models/phase.dart';
import '../../domain/models/player.dart';
import '../theme/app_colors.dart';
import 'opponents_modal.dart';
import 'player_hud.dart';
import 'player_order_row.dart';
import 'turn_timer.dart';

/// Right-side panel: turn timer, turn order, a button to open the opponent
/// boards modal, and this player's own stats HUD. Purely presentational —
/// same pattern as MarketPanel/MatchScreen (FE-04/FE-05): takes match state
/// via constructor, not yet wired to a real store (that's FE-11).
class InfoPanel extends StatelessWidget {
  final Phase phase;
  final int round;
  final int currentSeat;
  final int startingSeat;
  final List<PlayerState> players;
  final String selfId;
  final Map<String, List<BoardPoint>> boards;
  final Map<String, bool> connected;
  final String? heldBy;

  const InfoPanel({
    super.key,
    this.phase = Phase.turn,
    this.round = 0,
    this.currentSeat = -1,
    this.startingSeat = -1,
    this.players = const [],
    this.selfId = '',
    this.boards = const {},
    this.connected = const {},
    this.heldBy,
  });

  @override
  Widget build(BuildContext context) {
    final self = players.where((p) => p.playerId == selfId).firstOrNull;
    final current = players.where((p) => p.seat == currentSeat).firstOrNull;
    final isYourTurn = self != null && self.seat == currentSeat;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.parchmentDark,
        border: Border(left: BorderSide(color: AppColors.woodDark, width: 2)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            TurnTimer(
              phase: phase,
              round: round,
              currentSeat: currentSeat,
              currentName: current?.name,
              isYourTurn: isYourTurn,
            ),
            const SizedBox(height: 10),
            PlayerOrderRow(
              players: players,
              currentSeat: currentSeat,
              startingSeat: startingSeat,
              phase: phase,
              selfId: selfId,
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.text,
                side: const BorderSide(color: AppColors.woodDark),
              ),
              onPressed: players.length <= 1
                  ? null
                  : () => showOpponentsModal(
                      context,
                      players: players,
                      self: selfId,
                      boards: boards,
                      connected: connected,
                      currentSeat: currentSeat,
                      heldBy: heldBy,
                    ),
              child: const Text('Opponent boards'),
            ),
            const SizedBox(height: 14),
            if (self != null)
              PlayerHud(seat: self.seat, name: self.name, stats: self.stats),
          ],
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
