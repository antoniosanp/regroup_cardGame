import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { cornerMeta, pointKey, type BoardPoint } from '../online/cards';
import { colors } from '../theme';

interface BoardViewProps {
  points: BoardPoint[];
  /** Cell size in px; small values render read-only thumbnails. */
  cellSize?: number;
  /** True on the acting player's own board while they're holding a card — cells become tap targets. */
  tapEnabled?: boolean;
  /** Ghost cells for the held card anchored at the currently selected point (client-side preview only). */
  previewPoints?: BoardPoint[] | null;
  /** The board point currently chosen as the placement anchor (highlighted). */
  selectedPoint?: { x: number; y: number } | null;
  /** An existing point was tapped; (x, y) becomes the placement anchor. */
  onTapPoint?: (x: number, y: number) => void;
  /** The empty board was tapped (no points placed yet) — first card goes to the origin. */
  onTapEmpty?: () => void;
}

// Renders a player's board as an integer lattice of corner points (x right,
// y up). Cards appear as clusters of adjacent points. This is pure display of
// server-derived positions plus a client-side placement preview — no legality
// is judged here. Unlike the web client's drag-and-drop, placement on mobile
// is tap-driven: tap a cell to anchor, preview, then confirm from the held-card
// panel.
export function BoardView({
  points,
  cellSize = 40,
  tapEnabled,
  previewPoints,
  selectedPoint,
  onTapPoint,
  onTapEmpty,
}: BoardViewProps) {
  if (points.length === 0) {
    return (
      <Pressable
        onPress={tapEnabled ? onTapEmpty : undefined}
        disabled={!tapEnabled}
        style={[styles.empty, tapEnabled && styles.emptyDroppable]}
      >
        <Text style={styles.emptyText}>
          {tapEnabled ? 'Tap here to place your first card' : 'No cards placed yet'}
        </Text>
      </Pressable>
    );
  }

  const byKey = new Map(points.map((p) => [pointKey(p.x, p.y), p]));
  const previewByKey = new Map((previewPoints ?? []).map((p) => [pointKey(p.x, p.y), p]));
  // The preview can extend past the board's current bounds (a new card can
  // grow the lattice in any direction), so fold those points into the rendered
  // bounds too.
  const boundsSource = previewPoints?.length ? [...points, ...previewPoints] : points;
  const xs = boundsSource.map((p) => p.x);
  const ys = boundsSource.map((p) => p.y);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);

  const cellStyle = { width: cellSize, height: cellSize };
  const rows = [];
  for (let y = maxY; y >= minY; y--) {
    const cells = [];
    for (let x = minX; x <= maxX; x++) {
      const key = pointKey(x, y);
      const real = byKey.get(key);
      const preview = previewByKey.get(key);
      const isSelected = selectedPoint?.x === x && selectedPoint?.y === y;

      if (preview) {
        cells.push(
          <View key={key} style={[styles.cell, styles.cellPreview, cellStyle]}>
            <Image
              source={cornerMeta(preview.attribute).icon}
              style={[styles.cellImage, { opacity: 0.55 }]}
              resizeMode="contain"
            />
          </View>,
        );
        continue;
      }

      if (!real) {
        // The filler keeps the same fixed size as a real cell; without it the
        // row collapses and every cell after it slides left, drawing the
        // board's shape wrong.
        cells.push(<View key={key} style={[styles.cell, styles.gap, cellStyle]} />);
        continue;
      }

      cells.push(
        <Pressable
          key={key}
          disabled={!tapEnabled}
          onPress={() => onTapPoint?.(x, y)}
          style={[
            styles.cell,
            cellStyle,
            tapEnabled && styles.cellTappable,
            isSelected && styles.cellSelected,
          ]}
        >
          <Image source={cornerMeta(real.attribute).icon} style={styles.cellImage} resizeMode="contain" />
        </Pressable>,
      );
    }
    rows.push(
      <View key={y} style={styles.row}>
        {cells}
      </View>,
    );
  }

  return <View style={styles.board}>{rows}</View>;
}

const styles = StyleSheet.create({
  board: {
    alignSelf: 'flex-start',
    padding: 4,
    backgroundColor: colors.panel,
    borderRadius: 8,
  },
  row: {
    flexDirection: 'row',
  },
  cell: {
    borderWidth: StyleSheet.hairlineWidth,
    borderColor: colors.border,
    backgroundColor: colors.panelSoft,
    alignItems: 'center',
    justifyContent: 'center',
  },
  cellImage: {
    width: '100%',
    height: '100%',
  },
  cellTappable: {
    borderColor: colors.primaryDark,
  },
  cellSelected: {
    borderWidth: 2,
    borderColor: colors.gold,
  },
  cellPreview: {
    borderWidth: 1,
    borderColor: colors.primary,
    backgroundColor: '#24406b',
  },
  gap: {
    backgroundColor: 'transparent',
    borderColor: 'transparent',
  },
  empty: {
    minHeight: 96,
    borderRadius: 8,
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: colors.border,
    alignItems: 'center',
    justifyContent: 'center',
    padding: 16,
    alignSelf: 'stretch',
  },
  emptyDroppable: {
    borderColor: colors.primary,
    backgroundColor: '#1c2a44',
  },
  emptyText: {
    color: colors.textDim,
  },
});
