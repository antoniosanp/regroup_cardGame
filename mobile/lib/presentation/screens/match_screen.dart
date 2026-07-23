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
/// short phone-landscape height.
const double _topBox = 66;

/// Market band height — a bit taller than the corner squares so the market
/// cards are more visible (per feedback), while the corner squares stay small.
const double _marketHeight = 92;

/// Fixed height of the bottom HUD bar (web: 176px), scaled for phone.
const double _bottomBarHeight = 96;

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
              Expanded(child: _boardZone()),
              const SizedBox(height: 2),
              _statusLine(currentName, isYourTurn),
              // Bottom HUD flush to the bottom (feedback) — no trailing gap.
              SizedBox(height: _bottomBarHeight, child: _matchBottom(self)),
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
            SizedBox(
              width: _topBox + 24,
              child: PlayerOrderRow(
                players: widget.players,
                currentSeat: widget.currentSeat,
                startingSeat: widget.startingSeat,
                phase: widget.phase,
                selfId: widget.selfId,
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

  // ---- board-zone: pole | board (mainBoard bg) | pole ----
  Widget _boardZone() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _BorderPole(asset: BoardArt.borderPole1),
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
        const _BorderPole(asset: BoardArt.borderPole2),
      ],
    );
  }

  // ---- thin status line ----
  Widget _statusLine(String? currentName, bool isYourTurn) {
    final held = widget.heldBy == widget.selfId && widget.heldCard != null;
    final indicator = widget.phase == Phase.battle
        ? 'Resolving battle…'
        : isYourTurn
        ? (held
              ? 'Rotate, then drag your card onto the board'
              : 'Your turn — pick a card')
        : 'Waiting for ${currentName ?? 'the current player'}…';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0x8C3C2614),
        border: Border.all(color: AppColors.wood),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(
            'Round ${widget.round} · ${widget.phase == Phase.battle ? 'Battle' : 'Turn'}'
            '${widget.finalRound ? ' · Final round' : ''}',
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              indicator,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.gold,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const MuteButton(size: 18),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () {
              playSfx(SfxName.uiClick);
              widget.onLeave();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textLight,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Leave', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ---- match-bottom: player HUD | hand slot ----
  Widget _matchBottom(PlayerState? self) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (self != null)
          PlayerHud(seat: self.seat, name: self.name, stats: self.stats),
        const SizedBox(width: 8),
        Expanded(child: _handSlot()),
      ],
    );
  }

  Widget _handSlot() {
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

/// The held card in the hand slot: draggable card + Rotate button + hint,
/// laid out in a row so it fits the fixed-height bottom bar. Mirrors the
/// web's `.held-card`.
class _HeldCard extends StatelessWidget {
  final domain.Card card;
  final VoidCallback onRotate;

  const _HeldCard({required this.card, required this.onRotate});

  @override
  Widget build(BuildContext context) {
    // A finite card size is required: DraggableHeldCard's drag feedback is an
    // unconstrained overlay, so it can't take an infinite size. Sized to fit
    // the fixed-height bottom bar.
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardSize = (constraints.maxHeight - 16).clamp(40.0, 84.0);
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DraggableHeldCard(card: card, size: cardSize),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  playSfx(SfxName.cardRotate);
                  onRotate();
                },
                icon: const Icon(Icons.rotate_right, size: 18),
                label: const Text('Rotate'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Flexible(
                child: Text(
                  'Drag the card onto your board to place it.',
                  style: TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyHand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          const Center(
            child: Image(
              image: AssetImage(BoardArt.cardBack),
              fit: BoxFit.fitHeight,
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(6),
            child: Text(
              'Empty hand',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
