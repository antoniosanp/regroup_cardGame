// Card model + rendering metadata, per gameRules.md's CornerAttribute table
// and WS_CONTRACT.md's Card shape.

import empty from '../img/attributesImg/empty.png';
import hpPotionCoin from '../img/attributesImg/hp_potion_coin.png';
import coins2 from '../img/attributesImg/coins_2.png';
import pa1 from '../img/attributesImg/pa_1.png';
import pa2 from '../img/attributesImg/pa_2.png';
import pd1 from '../img/attributesImg/pd_1.png';
import pd2 from '../img/attributesImg/pd_2.png';
import ma1 from '../img/attributesImg/ma_1.png';
import ma2 from '../img/attributesImg/ma_2.png';
import md1 from '../img/attributesImg/md_1.png';
import md2 from '../img/attributesImg/md_2.png';

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
  icon: string;
  /** Full human name, used as a hover tooltip. */
  label: string;
}

export const CORNER_META: Record<CornerAttribute, CornerMeta> = {
  EMPTY: { icon: empty, label: 'Empty' },
  HP_POTION_COIN: { icon: hpPotionCoin, label: '1 HP potion + 1 coin' },
  COINS_2: { icon: coins2, label: '2 coins' },
  PA_1: { icon: pa1, label: '1 physical attack' },
  PA_2: { icon: pa2, label: '2 physical attack' },
  PD_1: { icon: pd1, label: '1 physical defense' },
  PD_2: { icon: pd2, label: '2 physical defense' },
  MA_1: { icon: ma1, label: '1 magic attack' },
  MA_2: { icon: ma2, label: '2 magic attack' },
  MD_1: { icon: md1, label: '1 magic defense' },
  MD_2: { icon: md2, label: '2 magic defense' },
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
