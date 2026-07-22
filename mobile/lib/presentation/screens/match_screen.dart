import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/board_point.dart';
import '../../domain/models/card.dart' as domain;
import '../../domain/models/corner_name.dart';
import '../../domain/models/market.dart';
import '../../domain/models/phase.dart';
import '../../domain/models/player.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import '../widgets/action_buttons.dart';
import '../widgets/board_drop_target.dart';
import '../widgets/info_panel.dart';
import '../widgets/market_panel.dart';

/// Side panel width in the landscape 3-column layout. See mobile_patterns.md
/// (agent memory) for the layout rationale.
const double _sidePanelWidth = 200;

/// Below this width, the 3-column layout no longer fits comfortably and the
/// screen stacks its zones vertically instead.
const double _stackBreakpoint = 600;

/// Height reserved for the bottom hand + confirm/cancel action bar.
const double _handBarHeight = 100;

void _noOpPick(Slot slot) {}
void _noOp() {}
void _noOpPlace(CornerName corner, int x, int y) {}

/// A placement dropped on the board but not yet sent to the server. Purely
/// local/ephemeral UI state — see the class doc below for why it lives here
/// instead of a future GameNotifier.
typedef _PendingPlacement = ({
  CornerName corner,
  int x,
  int y,
  List<BoardPoint> previewPoints,
});

/// Main match orchestrator: lays out the 5 zones (market, board, info panel,
/// hand, actions) for landscape play. Mostly presentational — it takes game
/// state as constructor parameters rather than reading from a store, since
/// the real state layer (GameNotifier) is FE-11's job, not this one's. The
/// one piece of local state it owns is the pending placement produced by a
/// drag-and-drop (FE-02/FE-03): that's ephemeral client-only UI state (never
/// sent to the server until Confirm is pressed), so it belongs here rather
/// than in a future GameNotifier.
class MatchScreen extends StatefulWidget {
  final List<BoardPoint> ownBoardPoints;
  final Market market;
  final int deckRemaining;
  final bool canPick;
  final int yourCoins;
  final bool finalRound;
  final domain.Card? heldCard;
  final ValueChanged<Slot> onPick;
  final VoidCallback onRotate;

  /// Called once the player presses Confirm on a pending placement. This is
  /// the only moment a placement actually reaches the server (once FE-11
  /// wires this to GameNotifier.place()) — dragging and dropping alone never
  /// does, and neither does Cancel.
  final void Function(CornerName corner, int x, int y) onPlace;

  final Phase phase;
  final int round;
  final int currentSeat;
  final int startingSeat;
  final List<PlayerState> players;
  final String selfId;
  final Map<String, List<BoardPoint>> boards;
  final Map<String, bool> connected;
  final String? heldBy;

  const MatchScreen({
    super.key,
    this.ownBoardPoints = const [],
    this.market = Market.empty,
    this.deckRemaining = 0,
    this.canPick = false,
    this.yourCoins = 0,
    this.finalRound = false,
    this.heldCard,
    this.onPick = _noOpPick,
    this.onRotate = _noOp,
    this.onPlace = _noOpPlace,
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
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  _PendingPlacement? _pendingPlacement;

  @override
  void didUpdateWidget(covariant MatchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A pending placement only makes sense while still holding the card it
    // was computed from. If the held card changes/clears from underneath us
    // (e.g. the server confirmed the placement and a new turn started, or a
    // reconnect resynced state), drop any stale local preview rather than
    // showing a ghost for a card that no longer matches reality.
    if (widget.heldCard == null && _pendingPlacement != null) {
      _pendingPlacement = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // Wood/parchment identity (see feedback: the plain dark theme lost
        // the game's visual identity) — same background art the web client
        // paints behind .screen-match.
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(BoardArt.boardBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < _stackBreakpoint;
              return Column(
                children: [
                  Expanded(
                    child: stacked ? _buildStackedZones() : _buildRowZones(),
                  ),
                  Container(
                    height: _handBarHeight,
                    color: AppColors.iron.withValues(alpha: 0.85),
                    child: ActionButtons(
                      hasPendingPlacement: _pendingPlacement != null,
                      onConfirm: _confirmPlacement,
                      onCancel: _cancelPlacement,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _confirmPlacement() {
    final p = _pendingPlacement;
    if (p == null) return;
    widget.onPlace(p.corner, p.x, p.y);
    // FE-14: uses Flutter's own HapticFeedback API rather than adding the
    // `vibration` pub package the plan originally proposed — one fewer
    // third-party dependency to trust without being able to run tests
    // against it, for the same haptic effect.
    HapticFeedback.mediumImpact();
    setState(() => _pendingPlacement = null);
  }

  void _cancelPlacement() {
    // Nothing was ever sent to the server for this — the pick is still
    // committed (see WS_CONTRACT.md, no unpick action), only the *position*
    // is undone, and the card visually returns to the hand.
    setState(() => _pendingPlacement = null);
  }

  Widget _buildRowZones() {
    return Row(
      children: [
        SizedBox(width: _sidePanelWidth, child: _marketPanel()),
        VerticalDivider(width: 2, thickness: 2, color: AppColors.woodDark),
        Expanded(child: _boardZone()),
        VerticalDivider(width: 2, thickness: 2, color: AppColors.woodDark),
        SizedBox(width: _sidePanelWidth, child: _infoPanel()),
      ],
    );
  }

  Widget _buildStackedZones() {
    return Column(
      children: [
        SizedBox(height: _sidePanelWidth, child: _marketPanel()),
        Divider(height: 2, thickness: 2, color: AppColors.woodDark),
        Expanded(child: _boardZone()),
        Divider(height: 2, thickness: 2, color: AppColors.woodDark),
        SizedBox(height: _sidePanelWidth, child: _infoPanel()),
      ],
    );
  }

  Widget _marketPanel() {
    return MarketPanel(
      market: widget.market,
      deckRemaining: widget.deckRemaining,
      canPick: widget.canPick,
      yourCoins: widget.yourCoins,
      finalRound: widget.finalRound,
      heldCard: widget.heldCard,
      placementPending: _pendingPlacement != null,
      onPick: widget.onPick,
      onRotate: widget.onRotate,
    );
  }

  Widget _boardZone() {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage(BoardArt.mainBoard),
          fit: BoxFit.fill,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      // No Center wrapper: BoardDropTarget fills this whole area so the entire
      // board zone is droppable (was the bug where only the tiny lattice
      // caught drops).
      child: BoardDropTarget(
        points: widget.ownBoardPoints,
        pendingPreviewPoints: _pendingPlacement?.previewPoints,
        onPlace: (corner, x, y, previewPoints) {
          setState(() {
            _pendingPlacement = (
              corner: corner,
              x: x,
              y: y,
              previewPoints: previewPoints,
            );
          });
        },
      ),
    );
  }

  Widget _infoPanel() {
    return InfoPanel(
      phase: widget.phase,
      round: widget.round,
      currentSeat: widget.currentSeat,
      startingSeat: widget.startingSeat,
      players: widget.players,
      selfId: widget.selfId,
      boards: widget.boards,
      connected: widget.connected,
      heldBy: widget.heldBy,
    );
  }
}
