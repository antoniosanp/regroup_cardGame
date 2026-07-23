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
///  2. Find the nearest currently-occupied point to (fx, fy). A candidate is
///     only returned within [_snapRadius] cells of that point — feedback:
///     predicting a landing spot from anywhere on the board made dragging
///     feel like it was "grabbing" cells nowhere near the finger, which
///     hurt positioning more than it helped. An earlier attempt at exactly
///     this kind of gate is what caused "I can't place the next card" on a
///     real device, but that was before the bounds-mirroring fix below
///     existed — with the coordinate math now exact and cells a comfortable
///     56px, a generous gate is safe again.
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
/// How close (in board-cell units) a drag needs to be to an existing point
/// before a placement preview appears and a drop is accepted there — see the
/// class doc's point 2. 1.5 is a bit more than one cell's diagonal (~1.41),
/// so aiming at a cell adjacent to the target (not just the target itself)
/// still snaps, while dragging from well across the board does not.
const double _snapRadius = 1.5;

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
        //
        // FittedBox(scaleDown) is the overflow guard for boards whose played
        // cards outgrow the available board-zone space (the fixed-height top
        // market band + bottom HUD bar leave a variable amount of room): it
        // only shrinks the lattice (never enlarges it, never distorts it —
        // BoxFit.scaleDown always preserves aspect ratio), so a small board
        // still renders at native boardCellSize while a big one is scaled
        // uniformly to fit instead of overflowing. This does NOT break drag
        // coordinate math in [_computeCandidate]: RenderBox.globalToLocal
        // walks the full transform chain (including FittedBox's scale
        // matrix), so `local` below still comes back in the lattice's own
        // pre-scale (boardCellSize-per-cell) coordinate space.
        // The Padding below is what leaves room to build a "tower": once a
        // tall stack has grown enough that FittedBox scales it to nearly
        // fill this whole box, there's no space *inside this widget* left to
        // drop a card "one row higher" — a drag past that point would have
        // to cross into the market widget above, which has its own hit
        // testing and never sees it, so the drop silently fails (reported:
        // "no puedo colocar más arriba, ya está a la altura del market").
        // Reserving a fixed margin here means the rendered (already
        // scaled-down) lattice can never touch this container's own edges,
        // so there's always genuine room, inside the SAME DragTarget, to
        // aim a drag above the current top row.
        return SizedBox.expand(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 16,
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: BoardView(
                  latticeKey: _latticeKey,
                  points: widget.points,
                  previewPoints:
                      widget.pendingPreviewPoints ?? _candidate?.previewPoints,
                ),
              ),
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
    // Must mirror BoardView's own bounds computation exactly (real points
    // *plus* whatever preview is currently rendered), not just the real
    // points. BoardView lays its lattice out from `bounds.maxY` down to
    // `bounds.minY` — the moment a drag's preview extends past the real
    // points (e.g. dragging a new card up against the topmost row), BoardView
    // re-renders one or more rows taller/wider and [_latticeKey]'s local
    // (0,0) origin shifts with it. Using real-points-only bounds here would
    // then read `local` in the *old*, narrower coordinate system every
    // subsequent pointer move of the same drag, silently offsetting fx/fy —
    // worse the more rows a drag has already added on top of an existing
    // stack. That mismatch was reported as "can't place cards further up
    // once the board has grown a couple of cards toward the market."
    final previewSoFar =
        widget.pendingPreviewPoints ?? _candidate?.previewPoints;
    final boundsSource = (previewSoFar != null && previewSoFar.isNotEmpty)
        ? [...widget.points, ...previewSoFar]
        : widget.points;
    final bounds = computeBoardBounds(boundsSource);

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
    // Gated: no candidate at all (no preview, no valid drop) unless the drag
    // is actually near a real point — see the class doc's point 2.
    if (nearest == null || nearestDistSq > _snapRadius * _snapRadius) {
      return null;
    }

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
