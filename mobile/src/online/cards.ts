// Card model + rendering metadata, per gameRules.md's CornerAttribute table
// and WS_CONTRACT.md's Card shape. Identical to the web client's module except
// that corner art is a React Native ImageSourcePropType (static require) instead
// of an imported URL.

import type { ImageSourcePropType } from 'react-native';

export type CornerAttribute =
  | 'EMPTY'
  | 'HP_POTION_COIN'
  | 'COINS_2'
  | 'PA_1'
  | 'PA_2'
  | 'PD_1'
  | 'PD_2'
  | 'MA_1'
  | 'MA_2'
  | 'MD_1'
  | 'MD_2';

export type Rotation = 'DEG_0' | 'DEG_90' | 'DEG_180' | 'DEG_270';

export type CornerName = 'TOP_LEFT' | 'TOP_RIGHT' | 'BOTTOM_LEFT' | 'BOTTOM_RIGHT';

// The server bakes rotation into the corner fields themselves, so a Card's
// topLeft/topRight/bottomLeft/bottomRight are ALWAYS already final/current on
// the wire (`rotation` is bookkeeping for the art transform, never a pending
// re-orientation). Corners must be rendered and placed exactly as received —
// re-applying `rotation` to them shows an arrangement the server doesn't have,
// and every placement made from that display lands "impossibly". The one
// message that doesn't carry corners is CARD_ROTATED; the store handles it by
// rotating the stored corners one clockwise step, mirroring the server's own
// Card.rotate() mutation (see rotateCornersOnce below).
export interface Card {
  topLeft: CornerAttribute;
  topRight: CornerAttribute;
  bottomLeft: CornerAttribute;
  bottomRight: CornerAttribute;
  rotation: Rotation;
}

export interface Corners {
  topLeft: CornerAttribute;
  topRight: CornerAttribute;
  bottomLeft: CornerAttribute;
  bottomRight: CornerAttribute;
}

export interface CornerMeta {
  /** Corner artwork. */
  icon: ImageSourcePropType;
  /** Full human name (used for accessibility labels). */
  label: string;
}

export const CORNER_META: Record<CornerAttribute, CornerMeta> = {
  EMPTY: { icon: require('../../assets/attributes/empty.png'), label: 'Empty' },
  HP_POTION_COIN: {
    icon: require('../../assets/attributes/hp_potion_coin.png'),
    label: '1 HP potion + 1 coin',
  },
  COINS_2: { icon: require('../../assets/attributes/coins_2.png'), label: '2 coins' },
  PA_1: { icon: require('../../assets/attributes/pa_1.png'), label: '1 physical attack' },
  PA_2: { icon: require('../../assets/attributes/pa_2.png'), label: '2 physical attack' },
  PD_1: { icon: require('../../assets/attributes/pd_1.png'), label: '1 physical defense' },
  PD_2: { icon: require('../../assets/attributes/pd_2.png'), label: '2 physical defense' },
  MA_1: { icon: require('../../assets/attributes/ma_1.png'), label: '1 magic attack' },
  MA_2: { icon: require('../../assets/attributes/ma_2.png'), label: '2 magic attack' },
  MD_1: { icon: require('../../assets/attributes/md_1.png'), label: '1 magic defense' },
  MD_2: { icon: require('../../assets/attributes/md_2.png'), label: '2 magic defense' },
};

export function cornerMeta(attr: CornerAttribute): CornerMeta {
  return CORNER_META[attr] ?? CORNER_META.EMPTY;
}

/**
 * One clockwise quarter-turn of a corner arrangement — the exact client mirror of the backend's
 * Card.rotate(). Used only when CARD_ROTATED arrives, since that broadcast carries the new rotation
 * but not the re-oriented corners.
 */
export function rotateCornersOnce(c: Corners): Corners {
  return {
    topLeft: c.bottomLeft,
    topRight: c.topLeft,
    bottomRight: c.topRight,
    bottomLeft: c.bottomRight,
  };
}

export interface BoardPoint {
  x: number;
  y: number;
  attribute: CornerAttribute;
}

// Spatial layout only (NOT a game rule): lattice with x increasing right, y
// increasing up. A card's bottom-left corner sits at cell (bx, by); its other
// corners fill (bx+1,by), (bx,by+1), (bx+1,by+1). Given the placement anchor
// (which corner lands on board point (x,y)) we solve for (bx,by) and emit the
// four resulting points. Callers pass corners exactly as stored — they are
// always the current arrangement (see the Card comment above), so no rotation
// is ever applied here. The server is authoritative for legality; this only
// positions cells for display.
export function cardToPoints(c: Corners, corner: CornerName, x: number, y: number): BoardPoint[] {
  let bx = x;
  let by = y;
  switch (corner) {
    case 'TOP_LEFT':
      bx = x;
      by = y - 1;
      break;
    case 'TOP_RIGHT':
      bx = x - 1;
      by = y - 1;
      break;
    case 'BOTTOM_LEFT':
      bx = x;
      by = y;
      break;
    case 'BOTTOM_RIGHT':
      bx = x - 1;
      by = y;
      break;
  }
  return [
    { x: bx, y: by, attribute: c.bottomLeft },
    { x: bx + 1, y: by, attribute: c.bottomRight },
    { x: bx, y: by + 1, attribute: c.topLeft },
    { x: bx + 1, y: by + 1, attribute: c.topRight },
  ];
}

export function pointKey(x: number, y: number): string {
  return `${x},${y}`;
}
