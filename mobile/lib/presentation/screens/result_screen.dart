import 'package:flutter/material.dart';

import '../../domain/models/player.dart';
import '../../sfx/sfx.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';

const Map<String, String> _reasonText = {
  'LAST_STANDING': 'Last player standing',
  'DECK_EXHAUSTED': 'Deck exhausted — highest HP wins',
};

/// Shown when a match ends (phase MATCH_OVER). Mirrors the web client's
/// ResultScreen.tsx: winner portrait(s), the end reason, a standings table
/// sorted by HP, and a button back to the menu. Plays victory/defeat once on
/// mount (like the web), so that sound is NOT also fired from GameNotifier.
class ResultScreen extends StatefulWidget {
  final List<PlayerState> players;
  final List<String>? winners;
  final String? reason;
  final String selfId;
  final VoidCallback onExit;

  const ResultScreen({
    super.key,
    required this.players,
    required this.winners,
    required this.reason,
    required this.selfId,
    required this.onExit,
  });

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  @override
  void initState() {
    super.initState();
    final youWon = widget.winners?.contains(widget.selfId) ?? false;
    playSfx(youWon ? SfxName.victory : SfxName.defeat);
  }

  @override
  Widget build(BuildContext context) {
    final winnerSet = widget.winners?.toSet() ?? const <String>{};
    final winningPlayers = widget.players
        .where((p) => winnerSet.contains(p.playerId))
        .toList();
    final standings = [...widget.players]
      ..sort((a, b) => b.stats.hp.compareTo(a.stats.hp));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(BoardArt.boardBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Match over',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (winningPlayers.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final p in winningPlayers)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: CircleAvatar(
                              radius: 26,
                              backgroundImage: AssetImage(avatarFor(p.seat)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${winningPlayers.length > 1 ? 'Winners' : 'Winner'}: '
                      '${winningPlayers.map((p) => p.name).join(', ')}',
                      style: const TextStyle(
                        color: AppColors.gold,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ] else
                    const Text(
                      'Awaiting final result…',
                      style: TextStyle(color: AppColors.textLight),
                    ),
                  if (widget.reason != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _reasonText[widget.reason] ?? widget.reason!,
                        style: const TextStyle(
                          color: AppColors.textLight,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  _StandingsTable(standings: standings, winnerSet: winnerSet),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      playSfx(SfxName.uiClick);
                      widget.onExit();
                    },
                    child: const Text('Back to menu'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StandingsTable extends StatelessWidget {
  final List<PlayerState> standings;
  final Set<String> winnerSet;

  const _StandingsTable({required this.standings, required this.winnerSet});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: const Color(0x663C2614),
        border: Border.all(color: AppColors.wood),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          for (final p in standings)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: winnerSet.contains(p.playerId)
                    ? AppColors.gold.withValues(alpha: 0.25)
                    : null,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundImage: AssetImage(avatarFor(p.seat)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Image.asset(BoardArt.hp, width: 16, height: 16),
                      const SizedBox(width: 3),
                      Text(
                        '${p.stats.hp}',
                        style: const TextStyle(color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: Text(
                      p.alive ? 'alive' : 'eliminated',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: p.alive ? AppColors.good : AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
