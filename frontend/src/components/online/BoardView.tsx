import type { DragEvent } from 'react';
import { cornerMeta, pointKey, type BoardPoint } from '../../online/cards';

interface BoardViewProps {
  points: BoardPoint[];
  /** True on the acting player's own board while they're holding a card — makes it a drop target. */
  dropEnabled?: boolean;
  /** Ghost cells for the held card as currently dragged over this board (client-side preview only). */
  previewPoints?: BoardPoint[] | null;
  /** An existing point was dragged over; (x, y) becomes the placement anchor if dropped. */
  onDragOverPoint?: (x: number, y: number) => void;
  /**
   * The held card was dropped anywhere on the board. Deliberately parameterless: native drag-and-drop
   * commits to whatever tiny DOM element happens to be under the cursor at release, which can silently
   * differ from the last cell the preview was tracking (a couple of pixels off a 32px target is enough).
   * The whole board is one drop target, and the caller places at whatever point it was last hovering
   * (via onDragOverPoint) — so what the preview shows is always exactly what gets placed.
   */
  onDrop?: () => void;
  /** The held card was dropped on an empty board (no points placed yet). */
  onDropEmpty?: () => void;
}

// Renders a player's board as an integer lattice of corner points (x right,
// y up). Cards appear as clusters of adjacent points. This is pure display of
// server-derived positions plus a client-side drag preview — no legality is
// judged here.
export function BoardView({
  points,
  dropEnabled,
  previewPoints,
  onDragOverPoint,
  onDrop,
  onDropEmpty,
}: BoardViewProps) {
  if (points.length === 0) {
    return (
      <div
        className={`board board-empty${dropEnabled ? ' board-empty-droppable' : ''}`}
        onDragOver={dropEnabled ? (e: DragEvent<HTMLDivElement>) => e.preventDefault() : undefined}
        onDrop={
          dropEnabled
            ? (e: DragEvent<HTMLDivElement>) => {
                e.preventDefault();
                onDropEmpty?.();
              }
            : undefined
        }
      >
        {dropEnabled ? 'Drop your card here to start your board' : 'No cards placed yet'}
      </div>
    );
  }

  const byKey = new Map(points.map((p) => [pointKey(p.x, p.y), p]));
  const previewByKey = new Map((previewPoints ?? []).map((p) => [pointKey(p.x, p.y), p]));
  // While dragging, the preview can extend past the board's current bounds
  // (a new card can grow the lattice in any direction), so fold those points
  // into the rendered bounds too.
  const boundsSource = previewPoints?.length ? [...points, ...previewPoints] : points;
  const xs = boundsSource.map((p) => p.x);
  const ys = boundsSource.map((p) => p.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);

  const rows = [];
  for (let y = maxY; y >= minY; y--) {
    const cells = [];
    for (let x = minX; x <= maxX; x++) {
      const key = pointKey(x, y);
      const real = byKey.get(key);
      const preview = previewByKey.get(key);
      const hoverHandler =
        dropEnabled && real
          ? (e: DragEvent<HTMLDivElement>) => {
              e.preventDefault();
              onDragOverPoint?.(x, y);
            }
          : undefined;

      if (preview) {
        const meta = cornerMeta(preview.attribute);
        cells.push(
          <div
            key={key}
            className="board-cell board-cell-preview"
            style={{ backgroundImage: `url(${meta.icon})` }}
            title={`(${x}, ${y}) ${meta.label} — preview`}
            onDragOver={hoverHandler}
          />,
        );
        continue;
      }

      if (!real) {
        // board-cell keeps the filler the same fixed size as a real cell; without
        // it the div collapses to zero width and every cell after it in the row
        // slides left, drawing the board's shape wrong.
        cells.push(<div key={key} className="board-cell board-gap" />);
        continue;
      }

      const meta = cornerMeta(real.attribute);
      cells.push(
        <div
          key={key}
          className={`board-cell${dropEnabled ? ' board-cell-droppable' : ''}`}
          style={{ backgroundImage: `url(${meta.icon})` }}
          title={`(${x}, ${y}) ${meta.label}`}
          onDragOver={hoverHandler}
        />,
      );
    }
    rows.push(
      <div key={y} className="board-row">
        {cells}
      </div>,
    );
  }

  return (
    <div
      className="board"
      onDragOver={dropEnabled ? (e: DragEvent<HTMLDivElement>) => e.preventDefault() : undefined}
      onDrop={
        dropEnabled
          ? (e: DragEvent<HTMLDivElement>) => {
              e.preventDefault();
              onDrop?.();
            }
          : undefined
      }
    >
      {rows}
    </div>
  );
}
