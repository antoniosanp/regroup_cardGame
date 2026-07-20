// Typed WS_CONTRACT.md messages + defensive parsing. Regroup has no hidden
// information, so (unlike the reference project) there is nothing to strip for
// secrecy — parsing here is purely about tolerating malformed/partial frames
// and giving the store well-shaped values.

import type { Card, CornerAttribute, CornerName, Rotation, BoardPoint } from './cards';

export type Phase = 'TURN' | 'BATTLE' | 'MATCH_OVER';
export type Slot = 'A' | 'B' | 'C' | 'DECK';

export interface Stats {
  hp: number;
  pa: number;
  pd: number;
  ma: number;
  md: number;
  cn: number;
  hpp: number;
}

export interface PlayerRef {
  playerId: string;
  name: string;
  seat: number;
}

export interface PlayerState extends PlayerRef {
  alive: boolean;
  stats: Stats;
}

// A pure damage instance from the all-vs-all battle resolution (WS_CONTRACT.md's
// documented ruling): every attacker->defender pair, computed from one shared
// pre-battle stat snapshot. Per-player results (who actually ended up at what hp,
// who healed, who died) are NOT here - they're in Outcome, since a defender can be
// hit by several attackers and healedHp is a once-per-player value.
export interface Attack {
  attackerId: string;
  defenderId: string;
  physicalDamage: number;
  magicDamage: number;
  totalDamage: number;
}

// One row per player who was alive at the start of the battle: their hp before,
// total damage taken from every attacker, how much they healed (0 if eliminated),
// and their authoritative final hp. Derive post-battle hp from here, not by
// summing Attack.totalDamage client-side.
export interface Outcome {
  playerId: string;
  hpBefore: number;
  damageTaken: number;
  healedHp: number;
  hpAfter: number;
  eliminated: boolean;
}

export type PrivateMessage =
  | {
      type: 'MATCH_FOUND';
      matchId: string;
      players: PlayerRef[];
      yourSeat: number;
    }
  | {
      type: 'RESUME_STATE';
      matchId: string;
      phase: Phase;
      round: number;
      currentSeat: number;
      finalRound: boolean;
      players: PlayerState[];
      boards: Record<string, BoardPoint[]>;
      market: { A: Card | null; B: Card | null; C: Card | null };
      deckRemaining: number;
      heldCard: Card | null;
    }
  | { type: 'ERROR'; code: string; message: string };

export type TopicMessage =
  | { type: 'ROUND_START'; round: number; startingSeat: number; finalRound: boolean }
  | { type: 'TURN_START'; playerId: string; seat: number }
  | {
      type: 'CARD_PICKED';
      playerId: string;
      slot: Slot;
      card: Card;
      market: { A: Card | null; B: Card | null; C: Card | null };
      deckRemaining: number;
    }
  | { type: 'CARD_ROTATED'; playerId: string; rotation: Rotation }
  | { type: 'CARD_PLACED'; playerId: string; corner: CornerName; x: number; y: number; card: Card }
  | { type: 'STATS_UPDATED'; playerId: string; stats: Stats }
  | { type: 'BATTLE_RESULT'; round: number; attacks: Attack[]; outcomes: Outcome[] }
  | { type: 'PLAYER_ELIMINATED'; playerId: string; finalHp: number }
  | { type: 'MATCH_RESULT'; winners: string[]; reason: string }
  | { type: 'PLAYER_DISCONNECTED'; playerId: string }
  | { type: 'PLAYER_RECONNECTED'; playerId: string };

function isObject(v: unknown): v is Record<string, unknown> {
  return typeof v === 'object' && v !== null;
}

function str(v: unknown): string {
  return typeof v === 'string' ? v : '';
}

function num(v: unknown): number {
  return typeof v === 'number' && Number.isFinite(v) ? v : 0;
}

function bool(v: unknown): boolean {
  return v === true;
}

const ROTATIONS: Rotation[] = ['DEG_0', 'DEG_90', 'DEG_180', 'DEG_270'];
function rotation(v: unknown): Rotation {
  return ROTATIONS.includes(v as Rotation) ? (v as Rotation) : 'DEG_0';
}

const CORNERS: CornerName[] = ['TOP_LEFT', 'TOP_RIGHT', 'BOTTOM_LEFT', 'BOTTOM_RIGHT'];
function corner(v: unknown): CornerName {
  return CORNERS.includes(v as CornerName) ? (v as CornerName) : 'TOP_LEFT';
}

const ATTRS: CornerAttribute[] = [
  'EMPTY',
  'HP_POTION_COIN',
  'COINS_2',
  'PA_1',
  'PA_2',
  'PD_1',
  'PD_2',
  'MA_1',
  'MA_2',
  'MD_1',
  'MD_2',
];
function attribute(v: unknown): CornerAttribute {
  return ATTRS.includes(v as CornerAttribute) ? (v as CornerAttribute) : 'EMPTY';
}

function stats(v: unknown): Stats {
  const o = isObject(v) ? v : {};
  return {
    hp: num(o.hp),
    pa: num(o.pa),
    pd: num(o.pd),
    ma: num(o.ma),
    md: num(o.md),
    cn: num(o.cn),
    hpp: num(o.hpp),
  };
}

function card(v: unknown): Card | null {
  if (!isObject(v)) return null;
  return {
    topLeft: attribute(v.topLeft),
    topRight: attribute(v.topRight),
    bottomLeft: attribute(v.bottomLeft),
    bottomRight: attribute(v.bottomRight),
    rotation: rotation(v.rotation),
  };
}

function playerRefs(v: unknown): PlayerRef[] {
  if (!Array.isArray(v)) return [];
  return v
    .filter(isObject)
    .map((p) => ({ playerId: str(p.playerId), name: str(p.name), seat: num(p.seat) }));
}

function playerStates(v: unknown): PlayerState[] {
  if (!Array.isArray(v)) return [];
  return v.filter(isObject).map((p) => ({
    playerId: str(p.playerId),
    name: str(p.name),
    seat: num(p.seat),
    alive: p.alive !== false,
    stats: stats(p.stats),
  }));
}

function boards(v: unknown): Record<string, BoardPoint[]> {
  const out: Record<string, BoardPoint[]> = {};
  if (!isObject(v)) return out;
  for (const [playerId, cells] of Object.entries(v)) {
    if (!Array.isArray(cells)) continue;
    out[playerId] = cells
      .filter(isObject)
      .map((c) => ({ x: num(c.x), y: num(c.y), attribute: attribute(c.attribute) }));
  }
  return out;
}

function market(v: unknown): { A: Card | null; B: Card | null; C: Card | null } {
  const o = isObject(v) ? v : {};
  return { A: card(o.A), B: card(o.B), C: card(o.C) };
}

function attacks(v: unknown): Attack[] {
  if (!Array.isArray(v)) return [];
  return v.filter(isObject).map((a) => ({
    attackerId: str(a.attackerId),
    defenderId: str(a.defenderId),
    physicalDamage: num(a.physicalDamage),
    magicDamage: num(a.magicDamage),
    totalDamage: num(a.totalDamage),
  }));
}

function outcomes(v: unknown): Outcome[] {
  if (!Array.isArray(v)) return [];
  return v.filter(isObject).map((o) => ({
    playerId: str(o.playerId),
    hpBefore: num(o.hpBefore),
    damageTaken: num(o.damageTaken),
    healedHp: num(o.healedHp),
    hpAfter: num(o.hpAfter),
    eliminated: bool(o.eliminated),
  }));
}

function phase(v: unknown): Phase {
  return v === 'BATTLE' || v === 'MATCH_OVER' ? v : 'TURN';
}

function stringArray(v: unknown): string[] {
  return Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : [];
}

export function parsePrivateMessage(raw: unknown): PrivateMessage | null {
  if (!isObject(raw)) return null;
  switch (raw.type) {
    case 'MATCH_FOUND':
      return {
        type: 'MATCH_FOUND',
        matchId: str(raw.matchId),
        players: playerRefs(raw.players),
        yourSeat: num(raw.yourSeat),
      };
    case 'RESUME_STATE':
      return {
        type: 'RESUME_STATE',
        matchId: str(raw.matchId),
        phase: phase(raw.phase),
        round: num(raw.round),
        currentSeat: num(raw.currentSeat),
        finalRound: bool(raw.finalRound),
        players: playerStates(raw.players),
        boards: boards(raw.boards),
        market: market(raw.market),
        deckRemaining: num(raw.deckRemaining),
        heldCard: card(raw.heldCard),
      };
    case 'ERROR':
      return { type: 'ERROR', code: str(raw.code), message: str(raw.message) };
    default:
      return null;
  }
}

export function parseTopicMessage(raw: unknown): TopicMessage | null {
  if (!isObject(raw)) return null;
  switch (raw.type) {
    case 'ROUND_START':
      return {
        type: 'ROUND_START',
        round: num(raw.round),
        startingSeat: num(raw.startingSeat),
        finalRound: bool(raw.finalRound),
      };
    case 'TURN_START':
      return { type: 'TURN_START', playerId: str(raw.playerId), seat: num(raw.seat) };
    case 'CARD_PICKED': {
      const c = card(raw.card);
      if (!c) return null;
      return {
        type: 'CARD_PICKED',
        playerId: str(raw.playerId),
        slot: slot(raw.slot),
        card: c,
        market: market(raw.market),
        deckRemaining: num(raw.deckRemaining),
      };
    }
    case 'CARD_ROTATED':
      return { type: 'CARD_ROTATED', playerId: str(raw.playerId), rotation: rotation(raw.rotation) };
    case 'CARD_PLACED': {
      const c = card(raw.card);
      if (!c) return null;
      return {
        type: 'CARD_PLACED',
        playerId: str(raw.playerId),
        corner: corner(raw.corner),
        x: num(raw.x),
        y: num(raw.y),
        card: c,
      };
    }
    case 'STATS_UPDATED':
      return { type: 'STATS_UPDATED', playerId: str(raw.playerId), stats: stats(raw.stats) };
    case 'BATTLE_RESULT':
      return {
        type: 'BATTLE_RESULT',
        round: num(raw.round),
        attacks: attacks(raw.attacks),
        outcomes: outcomes(raw.outcomes),
      };
    case 'PLAYER_ELIMINATED':
      return { type: 'PLAYER_ELIMINATED', playerId: str(raw.playerId), finalHp: num(raw.finalHp) };
    case 'MATCH_RESULT':
      return { type: 'MATCH_RESULT', winners: stringArray(raw.winners), reason: str(raw.reason) };
    case 'PLAYER_DISCONNECTED':
      return { type: 'PLAYER_DISCONNECTED', playerId: str(raw.playerId) };
    case 'PLAYER_RECONNECTED':
      return { type: 'PLAYER_RECONNECTED', playerId: str(raw.playerId) };
    default:
      return null;
  }
}

const SLOTS: Slot[] = ['A', 'B', 'C', 'DECK'];
function slot(v: unknown): Slot {
  return SLOTS.includes(v as Slot) ? (v as Slot) : 'DECK';
}
