import 'package:flutter/material.dart';

import '../../domain/models/board_point.dart';
import '../../domain/models/player.dart';
import '../../domain/models/stats.dart';
import '../assets/board_art.dart';
import 'board_view.dart';

/// Opens from the InfoPanel's "Opponent boards" button. Lets you flip
/// between every opponent's board plus an icon-based stat row and their
/// turn/eliminated/offline flags. Mirrors the web client's
/// OpponentsModal.tsx.
Future<void> showOpponentsModal(
  BuildContext context, {
  required List<PlayerState> players,
  required String self,
  required Map<String, List<BoardPoint>> boards,
  required Map<String, bool> connected,
  required int currentSeat,
  required String? heldBy,
}) {
  return showDialog(
    context: context,
    builder: (context) => _OpponentsDialog(
      players: players,
      self: self,
      boards: boards,
      connected: connected,
      currentSeat: currentSeat,
      heldBy: heldBy,
    ),
  );
}

class _OpponentsDialog extends StatefulWidget {
  final List<PlayerState> players;
  final String self;
  final Map<String, List<BoardPoint>> boards;
  final Map<String, bool> connected;
  final int currentSeat;
  final String? heldBy;

  const _OpponentsDialog({
    required this.players,
    required this.self,
    required this.boards,
    required this.connected,
    required this.currentSeat,
    required this.heldBy,
  });

  @override
  State<_OpponentsDialog> createState() => _OpponentsDialogState();
}

class _OpponentsDialogState extends State<_OpponentsDialog> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final opponents =
        widget.players.where((p) => p.playerId != widget.self).toList()
          ..sort((a, b) => a.seat.compareTo(b.seat));
    final selectedId = opponents.any((p) => p.playerId == _selectedId)
        ? _selectedId
        : (opponents.isNotEmpty ? opponents.first.playerId : null);
    final selected = opponents
        .where((p) => p.playerId == selectedId)
        .firstOrNull;

    return Dialog(
      backgroundColor: const Color(0xFF241A0E),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Opponent boards',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ],
              ),
              if (opponents.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No opponents yet.',
                    style: TextStyle(color: Colors.white54),
                  ),
                )
              else ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: opponents.map((p) {
                    final isConnected = widget.connected[p.playerId] != false;
                    final isSelected = p.playerId == selectedId;
                    return ChoiceChip(
                      selected: isSelected,
                      onSelected: (_) =>
                          setState(() => _selectedId = p.playerId),
                      avatar: CircleAvatar(
                        backgroundImage: AssetImage(avatarFor(p.seat)),
                      ),
                      label: Text(_opponentLabel(p, isConnected)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
                if (selected != null)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _OpponentStatRow(stats: selected.stats),
                          const SizedBox(height: 8),
                          BoardView(
                            points:
                                widget.boards[selected.playerId] ?? const [],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _opponentLabel(PlayerState p, bool isConnected) {
    final flags = <String>[];
    if (p.seat == widget.currentSeat && p.alive) flags.add('turn');
    if (widget.heldBy == p.playerId) flags.add('holding');
    if (!p.alive) flags.add('out');
    if (!isConnected) flags.add('offline');
    return flags.isEmpty ? p.name : '${p.name} (${flags.join(', ')})';
  }
}

class _OpponentStatRow extends StatelessWidget {
  final Stats stats;

  const _OpponentStatRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = <(StatKey, int)>[
      (StatKey.hp, stats.hp),
      (StatKey.pa, stats.pa),
      (StatKey.pd, stats.pd),
      (StatKey.ma, stats.ma),
      (StatKey.md, stats.md),
      (StatKey.cn, stats.cn),
      (StatKey.hpp, stats.hpp),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      children: entries.map((e) {
        return Tooltip(
          message: e.$1.name,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(statIcon[e.$1]!, width: 16, height: 16),
              const SizedBox(width: 3),
              Text('${e.$2}', style: const TextStyle(color: Colors.white)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
