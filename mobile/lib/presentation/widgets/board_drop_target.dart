import 'package:flutter/material.dart';

import '../../domain/models/board_point.dart';
import '../../domain/models/card.dart' as domain;
import '../../domain/models/corner_name.dart';
import '../../sfx/sfx.dart';
import 'board_view.dart';

/// Wraps [BoardView] as a drop target for a dragged [domain.Card] and
/// auto-selects the best legal (corner, anchor) placement near wherever the
/// pointer currently is — this is FE-03, the actual UX fix for the original
/// complaint that placing a card required grabbing an exact corner and
/// dropping on an exact pixel.
///
/// Algorithm (see BE-01's design note in the plan doc / agent memory
/// architecture_decisions.md for why this lives entirely client-side): the
/// board has no hidden information, so every occupied point on this board is
/// already known here. On every pointer move / on drop:
///  1. Convert the global pointer position into floating-point board lattice
///     coordinates (fx, fy), via the rendered lattice's own RenderBox — its
///     local origin (0,0) is always board point (minX, maxY) by construction
///     (see [BoardView]/[computeBoardBounds]).
///  2. Find the nearest currently-occupied point to (fx, fy) — always, with
///     NO distance gate. BoardEngine only allows anchoring on an
///     already-occupied point, so the nearest such point is the only sensible
///     target no matter where over the board the card is dropped; refusing to
///     place unless the finger was within some radius is exactly what made
///     "I can't place the next card" happen on a real device.
///  3. The quadrant of (fx, fy) relative to that anchor point decides which
///     of the new card's own corners gets anchored there (so the card visually
///     grows toward wherever the pointer/drag currently is): up-right of
///     anchor -> the new card's BOTTOM_LEFT is anchored there; up-left ->
///     BOTTOM_RIGHT; down-right -> TOP_LEFT; down-left -> TOP_RIGHT. This is
///     the exact inverse of backend/CornerPosition's lattice offsets (see
///     corner_name.dart) — cross-check against BoardEngineTest.java's
///     staircase example before ever changing it.
///  4. An empty board has no existing point to anchor against; per
///     BoardEngine.isValidPlacement, any point is legal there, so the first
///     placement always defaults to the origin (0,0) — the player can drop it
///     anywhere on the (now full-size) board area.
///
/// The whole board zone is the drop target (the DragTarget fills its parent
/// via [SizedBox.expand]); the lattice itself is just centered inside it for
/// display. Dropping anywhere over that area places the card.
///
/// Once dropped, the ghost preview must keep showing exactly where the card
/// will land until the player explicitly confirms or cancels (FE-07) — that
/// is [pendingPreviewPoints], supplied by the caller (MatchScreen), which
/// takes priority over whatever this widget is computing internally during
/// an active drag.
class BoardDropTarget extends StatefulWidget {
  final List<BoardPoint> points;
  final List<BoardPoint>? pendingPreviewPoints;
  final void Function(
    CornerName corner,
    int x,
    int y,
    List<BoardPoint> previewPoints,
  )
  onPlace;

  const BoardDropTarget({
    super.key,
    required this.points,
    required this.onPlace,
    this.pendingPreviewPoints,
  });

  @override
  State<BoardDropTarget> createState() => _BoardDropTargetState();
}

class _BoardDropTargetState extends State<BoardDropTarget> {
  final GlobalKey _latticeKey = GlobalKey();
  _Candidate? _candidate;

  @override
  Widget build(BuildContext context) {
    return DragTarget<domain.Card>(
      onWillAcceptWithDetails: (details) => widget.pendingPreviewPoints == null,
      onMove: (details) => _updateCandidate(details.offset, details.data),
      onLeave: (_) => setState(() => _candidate = null),
      onAcceptWithDetails: (details) {
        final candidate =
            _candidate ?? _computeCandidate(details.offset, details.data);
        setState(() => _candidate = null);
        if (candidate != null) {
          widget.onPlace(
            candidate.corner,
            candidate.anchorX,
            candidate.anchorY,
            candidate.previewPoints,
          );
        }
      },
      builder: (context, candidateData, rejectedData) {
        // Fill the whole board zone so the drop target covers all of it — not
        // just the small centered lattice. The lattice is centered inside for
        // display; hit-testing still uses its own RenderBox for coordinates.
        return SizedBox.expand(
          child: Center(
            child: BoardView(
              latticeKey: _latticeKey,
              points: widget.points,
              previewPoints:
                  widget.pendingPreviewPoints ?? _candidate?.previewPoints,
            ),
          ),
        );
      },
    );
  }

  void _updateCandidate(Offset globalPosition, domain.Card card) {
    final next = _computeCandidate(globalPosition, card);
    // Barely-audible tick when the preview lands on a NEW anchor point, same
    // as the web's card-hover-cell on onDragOverPoint changes.
    final prev = _candidate;
    final movedAnchor =
        next != null &&
        (prev == null ||
            prev.anchorX != next.anchorX ||
            prev.anchorY != next.anchorY);
    if (movedAnchor) playSfx(SfxName.cardHoverCell);
    setState(() => _candidate = next);
  }

  _Candidate? _computeCandidate(Offset globalPosition, domain.Card card) {
    final bounds = computeBoardBounds(widget.points);

    if (bounds == null) {
      // Empty board: BoardEngine.isValidPlacement allows any point here —
      // there is nothing to align the drop against yet, so default to the
      // origin regardless of where over the board the pointer actually is.
      const corner = CornerName.bottomLeft;
      return _Candidate(
        corner: corner,
        anchorX: 0,
        anchorY: 0,
        previewPoints: domain.cardToPoints(card, corner, 0, 0),
      );
    }

    final renderObject = _latticeKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.attached) return null;
    final local = renderObject.globalToLocal(globalPosition);
    final col = local.dx / boardCellSize;
    final row = local.dy / boardCellSize;
    final fx = bounds.minX + col;
    // Screen y grows downward; board y grows upward. Row 0 of the rendered
    // lattice is board row maxY, so each row down subtracts one from y.
    final fy = bounds.maxY - row;

    BoardPoint? nearest;
    var nearestDistSq = double.infinity;
    for (final p in widget.points) {
      final dx = p.x - fx;
      final dy = p.y - fy;
      final distSq = dx * dx + dy * dy;
      if (distSq < nearestDistSq) {
        nearestDistSq = distSq;
        nearest = p;
      }
    }
    // No distance gate: the nearest occupied point is always the target (see
    // the class doc — a gated radius is what blocked placing later cards).
    if (nearest == null) return null;

    final dx = fx - nearest.x;
    final dy = fy - nearest.y;
    final corner = dx >= 0
        ? (dy >= 0 ? CornerName.bottomLeft : CornerName.topLeft)
        : (dy >= 0 ? CornerName.bottomRight : CornerName.topRight);

    return _Candidate(
      corner: corner,
      anchorX: nearest.x,
      anchorY: nearest.y,
      previewPoints: domain.cardToPoints(card, corner, nearest.x, nearest.y),
    );
  }
}

class _Candidate {
  final CornerName corner;
  final int anchorX;
  final int anchorY;
  final List<BoardPoint> previewPoints;

  const _Candidate({
    required this.corner,
    required this.anchorX,
    required this.anchorY,
    required this.previewPoints,
  });
}
