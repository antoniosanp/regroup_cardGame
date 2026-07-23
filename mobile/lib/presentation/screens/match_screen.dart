import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/board_point.dart';
import '../../domain/models/card.dart' as domain;
import '../../domain/models/corner_name.dart';
import '../../domain/models/market.dart';
import '../../domain/models/phase.dart';
import '../../domain/models/player.dart';
import '../../sfx/sfx.dart';
import '../assets/board_art.dart';
import '../theme/app_colors.dart';
import '../widgets/action_buttons.dart';
import '../widgets/board_drop_target.dart';
import '../widgets/draggable_card.dart';
import '../widgets/market_panel.dart';
import '../widgets/mute_button.dart';
import '../widgets/opponents_modal.dart';
import '../widgets/player_hud.dart';
import '../widgets/player_order_row.dart';
import '../widgets/turn_timer.dart';

/// Square size of the two top-corner boxes (turn timer, opponent button).
/// The web uses 180px; scaled well down here so the board keeps most of a
/// short phone-landscape height. Fixed and never stretched by a sibling, so
/// the timer is always exactly this size regardless of player count/market
/// content.
const double _topBox = 66;

/// Market band height — taller than the corner squares so the market cards
/// can be as big as possible (per feedback), while the corner squares stay
/// small.
const double _marketHeight = 104;

/// Fixed cap on the player-order strip below the opponent-board button. A
/// FittedBox inside this band scales the strip down if it doesn't fit,
/// instead of letting it silently grow the whole top row taller — with 3-4
/// players the row used to wrap onto two lines here (only ~90px of width was
/// given to up to 4 avatars, which need ~150px on one line) and that alone
/// was inflating the entire top band well past _marketHeight, stealing most
/// of the board's vertical space. Widening the row below fixes the common
/// case (avatars fit on one line); this cap is the guard rail for anything
/// that still doesn't fit.
const double _orderRowHeight = 34;

/// Width of the player-HUD and hand-panel columns flanking the board (same
/// value for both, so they read as symmetric) — the old bottom bar is gone
/// (feedback: freeing up the whole bottom bar for just the board gives it
/// noticeably more room than sharing that bar with the hand ever did).
const double _handColumnWidth = 132;

void _noOpPick(Slot slot) {}
void _noOp() {}
void _noOpPlace(CornerName corner, int x, int y) {}

/// A placement dropped on the board but not yet sent to the server. Purely
/// local/ephemeral UI state (never sent until Confirm), so it lives here.
typedef _PendingPlacement = ({
  CornerName corner,
  int x,
  int y,
  List<BoardPoint> previewPoints,
});

/// Main match layout — a faithful port of the web client's Match.tsx: a
/// vertical stack of match-top (timer | market | opponent+order),
/// board-zone (poles + board), a thin status line, and match-bottom
/// (player HUD + hand slot). Mostly presentational; the one piece of local
/// state it owns is the pending placement produced by drag-and-drop.
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
  final void Function(CornerName corner, int x, int y) onPlace;
  final VoidCallback onLeave;

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
    this.onLeave = _noOp,
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
    // A pending placement only makes sense while still holding the card it was
    // computed from. If the held card clears from underneath us (server
    // confirmed the placement, a new turn started, or a reconnect resynced),
    // drop the stale local preview.
    if (widget.heldCard == null && _pendingPlacement != null) {
      _pendingPlacement = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.players
        .where((p) => p.playerId == widget.selfId)
        .firstOrNull;
    final currentName = widget.players
        .where((p) => p.seat == widget.currentSeat)
        .map((p) => p.name)
        .firstOrNull;
    final isYourTurn = self != null && self.seat == widget.currentSeat;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(BoardArt.boardBackground),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Market band flush to the top (feedback).
              _matchTop(context, currentName, isYourTurn),
              const SizedBox(height: 2),
              // The status line ("Round X · Turn phase · Waiting for...")
              // was removed entirely (feedback: it was oversized, centered,
              // and redundant — the timer box already shows whose turn it
              // is). Its mute/leave controls now live under the timer in
              // _matchTop. The player HUD and hand panel also no longer get
              // their own bottom bar (feedback: that bar was stealing height
              // from the board, which was wider than tall as a result) —
              // both now live *inside* the board zone's own row, left and
              // right of the board, so the board's height is whatever's left
              // after the top band, full stop.
              Expanded(child: _boardZone(self)),
            ],
          ),
        ),
      ),
    );
  }

  // ---- match-top: timer | market | (opponent button + order row) ----
  // Height is natural (driven by the opponent column = button + order row),
  // NOT a fixed box — the timer and market top-align to the square height.
  Widget _matchTop(BuildContext context, String? currentName, bool isYourTurn) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _topBox,
              height: _topBox,
              child: TurnTimer(
                phase: widget.phase,
                round: widget.round,
                currentSeat: widget.currentSeat,
                currentName: currentName,
                isYourTurn: isYourTurn,
              ),
            ),
            const SizedBox(height: 3),
            // Mute + Leave now live under the timer (feedback) — they used
            // to sit in the hand panel, which has since moved to the side of
            // the board and no longer has a natural corner for them.
            SizedBox(
              width: _topBox,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const MuteButton(size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        playSfx(SfxName.uiClick);
                        widget.onLeave();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textLight,
                        backgroundColor: const Color(0x8C140A05),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Leave', style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 6),
        Expanded(
          child: SizedBox(
            height: _marketHeight,
            child: MarketPanel(
              market: widget.market,
              deckRemaining: widget.deckRemaining,
              canPick: widget.canPick,
              yourCoins: widget.yourCoins,
              finalRound: widget.finalRound,
              onPick: widget.onPick,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: _topBox,
              height: _topBox,
              child: _opponentButton(context),
            ),
            const SizedBox(height: 3),
            // Wide enough for 4 avatars (32px each + 6px spacing) on a
            // single line, with a fixed height cap so a longer line still
            // can't grow the whole top band — see _orderRowHeight's doc.
            SizedBox(
              width: _topBox + 90,
              height: _orderRowHeight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: PlayerOrderRow(
                  players: widget.players,
                  currentSeat: widget.currentSeat,
                  startingSeat: widget.startingSeat,
                  phase: widget.phase,
                  selfId: widget.selfId,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _opponentButton(BuildContext context) {
    final enabled = widget.players.length > 1;
    return Semantics(
      button: true,
      label: 'Opponent boards',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  playSfx(SfxName.uiModalOpen);
                  showOpponentsModal(
                    context,
                    players: widget.players,
                    self: widget.selfId,
                    boards: widget.boards,
                    connected: widget.connected,
                    currentSeat: widget.currentSeat,
                    heldBy: widget.heldBy,
                  );
                }
              : null,
          child: const Image(
            image: AssetImage(BoardArt.opponentBoardButton),
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }

  // ---- board-zone: pole | player HUD | board (mainBoard bg) | hand panel |
  // pole ----
  // The player HUD and hand panel are symmetric side columns (same
  // _handColumnWidth) inside this same Expanded row, not a separate bottom
  // bar — feedback: a separate bar for them left the board wider than tall,
  // when giving the board this whole zone's height (not just its width)
  // was the point of moving the hand panel over in the first place.
  Widget _boardZone(PlayerState? self) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BorderPole(asset: BoardArt.borderPole1),
        if (self != null)
          SizedBox(
            width: _handColumnWidth,
            child: Center(
              child: PlayerHud(
                seat: self.seat,
                name: self.name,
                stats: self.stats,
              ),
            ),
          ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              image: const DecorationImage(
                image: AssetImage(BoardArt.mainBoard),
                fit: BoxFit.fill,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
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
          ),
        ),
        SizedBox(width: _handColumnWidth, child: _handPanel()),
        const _BorderPole(asset: BoardArt.borderPole2),
      ],
    );
  }

  Widget _handPanel() {
    final held = widget.heldBy == widget.selfId ? widget.heldCard : null;
    Widget content;
    if (_pendingPlacement != null) {
      content = ActionButtons(
        hasPendingPlacement: true,
        onConfirm: _confirmPlacement,
        onCancel: _cancelPlacement,
      );
    } else if (held != null) {
      content = _HeldCard(card: held, onRotate: widget.onRotate);
    } else {
      content = _EmptyHand();
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0x663C2614),
        border: Border.all(color: AppColors.wood, width: 2),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );
  }

  void _confirmPlacement() {
    final p = _pendingPlacement;
    if (p == null) return;
    widget.onPlace(p.corner, p.x, p.y);
    HapticFeedback.mediumImpact();
    setState(() => _pendingPlacement = null);
  }

  void _cancelPlacement() {
    // Nothing was sent to the server — the pick stays committed (WS_CONTRACT.md
    // has no unpick), only the *position* is undone; the card returns to hand.
    setState(() => _pendingPlacement = null);
  }
}

/// Extension helper kept private to this file for `.firstOrNull`.
extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _BorderPole extends StatelessWidget {
  final String asset;

  const _BorderPole({required this.asset});

  @override
  Widget build(BuildContext context) {
    return Image(image: AssetImage(asset), width: 16, fit: BoxFit.fill);
  }
}

/// The held card in the hand panel: draggable card + Rotate button + hint,
/// stacked in a column now that the panel lives beside the board (narrow but
/// tall) rather than in a wide, short bottom bar. Mirrors the web's
/// `.held-card` in spirit, not literal layout.
class _HeldCard extends StatelessWidget {
  final domain.Card card;
  final VoidCallback onRotate;

  const _HeldCard({required this.card, required this.onRotate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A finite card size is required: DraggableHeldCard's drag
          // feedback is an unconstrained overlay, so it can't take an
          // infinite size. The panel's own width is the limiting dimension
          // here (not height, since it's now generous).
          LayoutBuilder(
            builder: (context, constraints) {
              final cardSize = constraints.maxWidth.clamp(40.0, 96.0);
              return DraggableHeldCard(card: card, size: cardSize);
            },
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () {
              playSfx(SfxName.cardRotate);
              onRotate();
            },
            icon: const Icon(Icons.rotate_right, size: 16),
            label: const Text('Rotate'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Drag onto your board to place it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textLight, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _EmptyHand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Image(
              image: AssetImage(BoardArt.cardBack),
              width: 72,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            const Text(
              'Empty hand',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
