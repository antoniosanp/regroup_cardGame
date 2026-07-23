import 'package:flutter/material.dart';

import '../../domain/models/board_point.dart';
import '../assets/corner_art.dart';

/// Size of one lattice cell, in logical pixels. Bumped toward the web's 56px
/// look; BoardDropTarget shares this same constant for hit-testing, so
/// changing it keeps placement coordinates correct.
const double boardCellSize = 40;

class BoardBounds {
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;

  const BoardBounds({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
  });
}

/// Bounding box of a list of board points, or null if the list is empty.
/// Shared by [BoardView] (to know which cells to render) and
/// [BoardDropTarget] (FE-03 — to convert a drop position into lattice
/// coordinates), so the two never drift out of sync on what "the board's
/// bounds" means.
BoardBounds? computeBoardBounds(List<BoardPoint> points) {
  if (points.isEmpty) return null;
  var minX = points.first.x, maxX = points.first.x;
  var minY = points.first.y, maxY = points.first.y;
  for (final p in points) {
    if (p.x < minX) minX = p.x;
    if (p.x > maxX) maxX = p.x;
    if (p.y < minY) minY = p.y;
    if (p.y > maxY) maxY = p.y;
  }
  return BoardBounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY);
}

/// Renders a player's board as an integer lattice of corner points (x right,
/// y up). Cards appear as clusters of adjacent points. This is pure display
/// of server-derived positions plus an optional client-side drag preview —
/// no legality is judged here (see [BoardDropTarget] for that). Mirrors the
/// web client's BoardView.tsx.
///
/// Note: unlike the web version, this does not scroll — large boards are
/// sized to their full content. Culling/virtualization for very large boards
/// is deferred to FE-13 (performance pass), not needed for correctness here.
class BoardView extends StatelessWidget {
  final List<BoardPoint> points;

  /// Ghost cells for the held card as currently dragged over this board
  /// (client-side preview only, computed by [BoardDropTarget]).
  final List<BoardPoint>? previewPoints;

  /// Attached to the root lattice element so [BoardDropTarget] can convert a
  /// global drag position into a position local to the lattice's own origin
  /// (which is always the top-left cell, i.e. board point (minX, maxY)).
  final Key? latticeKey;

  const BoardView({
    super.key,
    required this.points,
    this.previewPoints,
    this.latticeKey,
  });

  @override
  Widget build(BuildContext context) {
    final preview = previewPoints ?? const <BoardPoint>[];
    if (points.isEmpty && preview.isEmpty) {
      return const _EmptyBoard();
    }

    final byKey = {for (final p in points) p.key: p};
    final previewByKey = {for (final p in preview) p.key: p};
    // While dragging, the preview can extend past the board's current bounds
    // (a new card can grow the lattice in any direction), so fold those
    // points into the rendered bounds too.
    final boundsSource = preview.isNotEmpty ? [...points, ...preview] : points;
    final bounds = computeBoardBounds(boundsSource)!;

    final rows = <Widget>[];
    for (var y = bounds.maxY; y >= bounds.minY; y--) {
      final cells = <Widget>[];
      for (var x = bounds.minX; x <= bounds.maxX; x++) {
        final key = pointKey(x, y);
        final previewPoint = previewByKey[key];
        if (previewPoint != null) {
          cells.add(_PreviewCell(point: previewPoint));
          continue;
        }
        final real = byKey[key];
        if (real == null) {
          cells.add(const _BoardGap());
          continue;
        }
        // Keyed by board position (FE-14): a point appearing for the first
        // time mounts a fresh element and plays its pop-in entrance
        // animation; a point that already existed keeps its element (no
        // key change) and skips straight to the new attribute, no replay.
        cells.add(_BoardCell(key: ValueKey(key), point: real));
      }
      rows.add(Row(mainAxisSize: MainAxisSize.min, children: cells));
    }

    // Isolates the (potentially large) lattice's repaints from the rest of
    // the screen — FE-13.
    return RepaintBoundary(
      child: Column(
        key: latticeKey,
        mainAxisSize: MainAxisSize.min,
        children: rows,
      ),
    );
  }
}

class _BoardCell extends StatelessWidget {
  final BoardPoint point;

  const _BoardCell({super.key, required this.point});

  @override
  Widget build(BuildContext context) {
    // FE-14: a freshly-placed card cell "pops" in rather than just appearing.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.55, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Tooltip(
        message: '(${point.x}, ${point.y}) ${point.attribute.label}',
        child: Semantics(
          label: '${point.attribute.label} at ${point.x}, ${point.y}',
          child: Image.asset(
            iconFor(point.attribute),
            width: boardCellSize,
            height: boardCellSize,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  final BoardPoint point;

  const _PreviewCell({required this.point});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boardCellSize,
      height: boardCellSize,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.greenAccent, width: 2),
      ),
      child: Opacity(
        opacity: 0.7,
        child: Image.asset(iconFor(point.attribute), fit: BoxFit.contain),
      ),
    );
  }
}

/// Keeps the lattice's shape correct: an unoccupied cell in the middle of a
/// board's bounding box must still take up its slot, or every cell after it
/// in the row would slide over and draw the wrong shape.
class _BoardGap extends StatelessWidget {
  const _BoardGap();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(width: boardCellSize, height: boardCellSize);
  }
}

class _EmptyBoard extends StatelessWidget {
  const _EmptyBoard();

  @override
  Widget build(BuildContext context) {
    // A visible, generously-sized "drop here" hint. The actual droppable area
    // is the whole board zone (BoardDropTarget fills it) — an empty board
    // accepts the first card at the origin no matter where it lands — but a
    // clear target box tells the player they can just drop it in.
    return Container(
      width: 220,
      height: 150,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.white38,
          width: 2,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Drop your first card\nanywhere on the board',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
      ),
    );
  }
}
