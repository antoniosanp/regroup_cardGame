import 'package:flutter/material.dart';

import '../../domain/models/phase.dart';
import '../../domain/models/player.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';

const List<String> _ordinals = ['', '1st', '2nd', '3rd', '4th'];

/// Small strip showing every seat's turn order for the current round: a
/// portrait, a placement number (1 = moves first), a highlight on whoever's
/// turn it is right now, and a badge on this round's first mover. Purely
/// presentational, derived from state the caller already tracks. Mirrors the
/// web client's PlayerOrderRow.tsx.
class PlayerOrderRow extends StatelessWidget {
  final List<PlayerState> players;
  final int currentSeat;
  final int startingSeat;
  final Phase phase;
  final String selfId;

  const PlayerOrderRow({
    super.key,
    required this.players,
    required this.currentSeat,
    required this.startingSeat,
    required this.phase,
    required this.selfId,
  });

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty || startingSeat < 0) return const SizedBox.shrink();

    final ordered = [...players]..sort((a, b) => a.seat.compareTo(b.seat));

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: ordered.map((p) {
        final isFirstMover = p.seat == startingSeat;
        final isActive = phase == Phase.turn && p.seat == currentSeat;
        final turnOrder = ((p.seat - startingSeat + 4) % 4) + 1;
        final isSelf = p.playerId == selfId;

        return Tooltip(
          message:
              '${p.name}${isSelf ? ' (you)' : ''} — moves ${_ordinals[turnOrder]} this round',
          child: Opacity(
            opacity: p.alive ? 1 : 0.4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: AssetImage(avatarFor(p.seat)),
                      child: isSelf
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.amber,
                                  width: 2,
                                ),
                              ),
                            )
                          : null,
                    ),
                    if (isFirstMover)
                      const Positioned(
                        top: -4,
                        right: -4,
                        child: Text('💀', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                Text(
                  '$turnOrder',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    color: isActive ? AppColors.accent : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
