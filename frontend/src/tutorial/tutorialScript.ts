// The scripted world and step list for the guided tutorial. Pure data + types:
// no React, no DOM, no randomness. Every card, stat and payload here is fixed so
// the lesson plays identically every time.
//
// The framing is round 5 of a duel already in progress: Brak and Mira are out,
// and only Gorn is left, on 3 hp. That buys three things a fresh match can't —
// your board already holds a card (so the overlap rule is teachable instead of a
// degenerate first drop), round 5 makes startingSeat (5-1)%4 = 0 so you move
// first, and killing Gorn genuinely ends the match, so the closing MATCH_RESULT
// is truthful and lands on the real ResultScreen.

import type { Identity } from '../online/api';
import type { BoardPoint, Card, CornerName } from '../online/cards';
import type { PlayerRef, PlayerState, PrivateMessage, Slot, TopicMessage } from '../online/messages';

export const YOU = 'tut-you';
export const BRAK = 'tut-brak';
export const MIRA = 'tut-mira';
export const GORN = 'tut-gorn';

export const TUTORIAL_IDENTITY: Identity = { playerId: YOU, token: 'tutorial', name: 'You' };

/**
 * Every CSS selector the tutorial uses to reach into Match's markup, kept together so a
 * future markup change has a single fix site. This is the one place the tutorial couples
 * to the match UI's internals.
 */
export const SEL = {
  marketSlotA: '.market-slot:nth-child(1) button',
  marketSlotB: '.market-slot:nth-child(2) button',
  rotateButton: '.held-card button',
  heldCard: '.held-card-drag',
  board: '.board',
  // BoardView renders title="(x, y) label" on every cell, so this addresses an
  // exact lattice point without BoardView needing to change.
  targetCell: '.board-cell[title^="(1, 1) "]',
} as const;

// Your board at the start: the two PA_1s at (0,0)/(1,0) are orthogonally adjacent
// so they count (pa 2). The COINS_2 at (0,1) and the MA_1 at (1,1) both touch
// nothing of their own kind — the coins still count regardless (coins always do),
// but the magic attack corner is dead weight, which is exactly the point the
// adjacency step makes, and exactly why it's the one the lesson card overwrites:
// it's the only tile on the board contributing nothing already.
const YOUR_BOARD: BoardPoint[] = [
  { x: 0, y: 0, attribute: 'PA_1' },
  { x: 1, y: 0, attribute: 'PA_1' },
  { x: 0, y: 1, attribute: 'COINS_2' },
  { x: 1, y: 1, attribute: 'MA_1' },
];

// Cosmetic only — visible if the player opens the opponent-boards modal.
const GORN_BOARD: BoardPoint[] = [
  { x: 0, y: 0, attribute: 'PA_1' },
  { x: 1, y: 0, attribute: 'PA_1' },
  { x: 0, y: 1, attribute: 'EMPTY' },
  { x: 1, y: 1, attribute: 'MD_1' },
];

// Slot A is free but deliberately weak, so "free isn't always right" is a real lesson.
// A real EMPTY-shape card (CardFactory: one coin/empty corner + the three stat categories
// other than the omitted one, all at +1) that omits PA, so it never carries a physical
// attack corner — the one stat that matters for finishing Gorn this turn.
const MARKET_A: Card = {
  topLeft: 'EMPTY',
  topRight: 'PD_1',
  bottomLeft: 'MD_1',
  bottomRight: 'MA_1',
  rotation: 'DEG_0',
};

// The card the lesson is built around: a real NORMAL-shape card (CardFactory: one +1
// corner of every stat category). PA_1 sits bottom-right, so exactly one clockwise
// rotation (rotateCornersOnce sets bottomLeft = bottomRight) brings it to bottom-left —
// the corner that lands on your board's dead-weight MA_1 tile at (1,1), so the new
// attack corner ends up beside your existing PA_1s without disturbing either of them.
// The other three corners are real stat corners too, but they land on fresh board
// cells with no matching neighbour, so only the attack corner counts once placed.
const LESSON_CARD: Card = {
  topLeft: 'MD_1',
  topRight: 'MA_1',
  bottomLeft: 'PD_1',
  bottomRight: 'PA_1',
  rotation: 'DEG_0',
};

// Two coins — out of reach this turn on 3 coins minus the 1 spent on slot B. A real
// DOUBLE(MA)-shape card.
const MARKET_C: Card = {
  topLeft: 'MA_2',
  topRight: 'PA_1',
  bottomLeft: 'PD_1',
  bottomRight: 'MD_1',
  rotation: 'DEG_0',
};

/** LESSON_CARD after one clockwise turn, as the store will compute it from CARD_ROTATED. */
const LESSON_CARD_ROTATED: Card = {
  topLeft: 'PD_1',
  topRight: 'MD_1',
  bottomLeft: 'PA_1',
  bottomRight: 'MA_1',
  rotation: 'DEG_90',
};

const PLAYERS_AT_START: PlayerState[] = [
  {
    playerId: YOU,
    name: 'You',
    seat: 0,
    alive: true,
    stats: { hp: 24, pa: 2, pd: 0, ma: 0, md: 0, cn: 3, hpp: 0 },
  },
  {
    playerId: BRAK,
    name: 'Brak',
    seat: 1,
    alive: false,
    stats: { hp: 0, pa: 0, pd: 0, ma: 0, md: 0, cn: 0, hpp: 0 },
  },
  {
    playerId: MIRA,
    name: 'Mira',
    seat: 2,
    alive: false,
    stats: { hp: 0, pa: 0, pd: 0, ma: 0, md: 0, cn: 0, hpp: 0 },
  },
  {
    playerId: GORN,
    name: 'Gorn',
    seat: 3,
    alive: true,
    stats: { hp: 3, pa: 1, pd: 0, ma: 0, md: 0, cn: 1, hpp: 0 },
  },
];

const PLAYER_REFS: PlayerRef[] = PLAYERS_AT_START.map(({ playerId, name, seat }) => ({
  playerId,
  name,
  seat,
}));

/**
 * Kicks the store into a match once the fake socket connects. Its handler resets match state
 * and then publishes a .resume request, which the driver answers with OPENING_RESUME — the
 * same two-step handshake the real server drives.
 */
export const TUTORIAL_MATCH_FOUND: PrivateMessage = {
  type: 'MATCH_FOUND',
  matchId: 'tutorial',
  players: PLAYER_REFS,
  yourSeat: 0,
};

/** The opening snapshot, sent in reply to the store's own .resume request. */
export const OPENING_RESUME: PrivateMessage = {
  type: 'RESUME_STATE',
  matchId: 'tutorial',
  phase: 'TURN',
  round: 5,
  currentSeat: 0,
  finalRound: false,
  players: PLAYERS_AT_START,
  boards: { [YOU]: YOUR_BOARD, [GORN]: GORN_BOARD },
  market: { A: MARKET_A, B: LESSON_CARD, C: MARKET_C },
  deckRemaining: 9,
  heldCard: null,
};

/** As above but mid-turn holding the rotated card — replayed to undo a rejected action. */
const RESUME_HOLDING_ROTATED: PrivateMessage = {
  ...(OPENING_RESUME as Extract<PrivateMessage, { type: 'RESUME_STATE' }>),
  players: PLAYERS_AT_START.map((p) =>
    p.playerId === YOU ? { ...p, stats: { ...p.stats, cn: 2 } } : p,
  ),
  market: { A: MARKET_A, B: null, C: MARKET_C },
  heldCard: LESSON_CARD_ROTATED,
};

export type HighlightTarget = string;

export type Expect =
  | { kind: 'pick'; slot: Slot }
  | { kind: 'rotate' }
  | { kind: 'place'; corner: CornerName; x: number; y: number }
  /** Advanced only by the coach box's Next button, never by a game action. */
  | { kind: 'advance' };

export interface TutorialStep {
  id: string;
  title: string;
  /** Coaching copy — explains WHY this is the right move, not just where to click. */
  text: string;
  /** Selectors lifted above the input blocker, so only these stay clickable. */
  interactive: HighlightTarget[];
  /** Pulsing rings that point at something without making it clickable. */
  pointAt?: HighlightTarget[];
  expect: Expect;
  /** Scripted server replies, optionally staggered to read as separate beats. */
  emit: { msg: TopicMessage; delayMs?: number }[];
  /** Snapshot replayed if the player does something off-script, to clear `busy`. */
  resumeOnReject?: PrivateMessage;
  dock: 'top' | 'bottom' | 'center';
}

export const TUTORIAL_STEPS: TutorialStep[] = [
  {
    id: 'welcome',
    title: 'One opponent left',
    text: "It's round 5 and you're the last two standing. Gorn is down to 3 health — this turn you can finish him. Let's build the attack that does it.",
    interactive: [],
    expect: { kind: 'advance' },
    emit: [],
    dock: 'center',
  },
  {
    id: 'pick',
    title: 'Pick a card',
    text: 'The market charges by position: the card furthest from the deck is free, the next costs 1 coin, the closest costs 2. The free card has no physical attack corner, so it can\'t help you finish Gorn this turn. Spend 1 of your 3 coins on the second card — it carries a physical attack corner.',
    interactive: [SEL.marketSlotB],
    expect: { kind: 'pick', slot: 'B' },
    emit: [
      {
        msg: {
          type: 'CARD_PICKED',
          playerId: YOU,
          slot: 'B',
          card: LESSON_CARD,
          market: { A: MARKET_A, B: null, C: MARKET_C },
          deckRemaining: 9,
        },
      },
      {
        msg: {
          type: 'STATS_UPDATED',
          playerId: YOU,
          stats: { hp: 24, pa: 2, pd: 0, ma: 0, md: 0, cn: 2, hpp: 0 },
        },
      },
    ],
    resumeOnReject: OPENING_RESUME,
    dock: 'bottom',
  },
  {
    id: 'rotate',
    title: 'Rotate it',
    text: 'The physical attack corner is on the bottom-right, but it needs to be bottom-left to land beside the attack corner already on your board. Rotate the card once.',
    interactive: [SEL.rotateButton],
    expect: { kind: 'rotate' },
    emit: [{ msg: { type: 'CARD_ROTATED', playerId: YOU, rotation: 'DEG_90' } }],
    dock: 'top',
  },
  {
    id: 'adjacency',
    title: 'Why adjacency matters',
    text: 'This is the whole game: a corner only counts if it touches a matching corner up, down, left or right. Your two attack corners touch, so you have 2 physical attack. The coins corner and the magic attack corner beside them both touch nothing of their own kind — coins still count regardless, but the magic attack doesn\'t. That magic attack corner is dead weight; it\'s the one worth overwriting.',
    interactive: [],
    expect: { kind: 'advance' },
    dock: 'top',
    emit: [],
  },
  {
    id: 'place',
    title: 'Place the card',
    text: 'Grab the card by its attack corner (bottom-left) and drop it on the highlighted square — your dead-weight magic attack corner. A new card must always overlap a tile already on your board, and overwriting that one costs you nothing: both of your existing attack corners stay exactly as they are, and the new one lands right next to them.',
    interactive: [SEL.heldCard, SEL.board],
    pointAt: [SEL.targetCell],
    expect: { kind: 'place', corner: 'BOTTOM_LEFT', x: 1, y: 1 },
    emit: [
      {
        msg: {
          type: 'CARD_PLACED',
          playerId: YOU,
          corner: 'BOTTOM_LEFT',
          x: 1,
          y: 1,
          card: LESSON_CARD_ROTATED,
        },
      },
      {
        msg: {
          type: 'STATS_UPDATED',
          playerId: YOU,
          // 1 (0,0) + 1 (1,0) + 1 (1,1, new, replacing the dead MA_1) now mutually adjacent
          // -> 3. The card's other three corners (MA_1/PD_1/MD_1) land on fresh cells that
          // touch nothing of their own kind, so they contribute nothing this round — only
          // the attack corner counts.
          stats: { hp: 24, pa: 3, pd: 0, ma: 0, md: 0, cn: 2, hpp: 0 },
        },
      },
    ],
    resumeOnReject: RESUME_HOLDING_ROTATED,
    dock: 'top',
  },
  {
    id: 'stats',
    title: '3 physical attack',
    text: 'Both of your original attack corners are still on the board, untouched, and the new one you placed sits right beside them: 1 + 1 + 1 = 3 physical attack. Gorn has 3 health and no physical defense at all — left in your hand, that card would only have gotten you to 2 attack, and Gorn survives on 1 health. Placing it there, without wasting anything you already had, is what wins this.',
    interactive: [],
    expect: { kind: 'advance' },
    emit: [],
    dock: 'top',
  },
  {
    id: 'gorn',
    title: "Gorn's turn",
    text: 'Every player places one card per round. Watch Gorn take his — he has no defense on the board and one turn is not enough to build any.',
    interactive: [],
    expect: { kind: 'advance' },
    emit: [
      { msg: { type: 'TURN_START', playerId: GORN, seat: 3 } },
      {
        msg: {
          type: 'CARD_PICKED',
          playerId: GORN,
          slot: 'A',
          card: MARKET_A,
          market: { A: null, B: null, C: MARKET_C },
          deckRemaining: 9,
        },
        delayMs: 700,
      },
      {
        msg: {
          type: 'CARD_PLACED',
          playerId: GORN,
          corner: 'TOP_LEFT',
          x: 1,
          y: 1,
          card: MARKET_A,
        },
        delayMs: 1600,
      },
      {
        msg: {
          type: 'STATS_UPDATED',
          playerId: GORN,
          stats: { hp: 3, pa: 1, pd: 0, ma: 0, md: 1, cn: 1, hpp: 0 },
        },
        delayMs: 1800,
      },
    ],
    dock: 'top',
  },
  {
    id: 'battle',
    title: 'Battle',
    text: 'Both players have placed, so the round resolves. Everyone attacks everyone at once, and damage is attack minus the defender’s matching defense. Your 3 physical attack meets Gorn’s 0 physical defense.',
    interactive: [],
    expect: { kind: 'advance' },
    emit: [
      {
        msg: {
          type: 'BATTLE_RESULT',
          round: 5,
          attacks: [
            { attackerId: YOU, defenderId: GORN, physicalDamage: 3, magicDamage: 0, totalDamage: 3 },
            { attackerId: GORN, defenderId: YOU, physicalDamage: 1, magicDamage: 0, totalDamage: 1 },
          ],
          outcomes: [
            { playerId: YOU, hpBefore: 24, damageTaken: 1, healedHp: 0, hpAfter: 23, eliminated: false },
            { playerId: GORN, hpBefore: 3, damageTaken: 3, healedHp: 0, hpAfter: 0, eliminated: true },
          ],
        },
      },
      { msg: { type: 'PLAYER_ELIMINATED', playerId: GORN, finalHp: 0 }, delayMs: 200 },
    ],
    dock: 'top',
  },
  {
    id: 'finish',
    title: 'You win',
    text: "Gorn is out and you're the last player standing. That's the whole loop: pick a card, orient it, place it so matching corners touch, and out-scale everyone else before the deck runs dry.",
    interactive: [],
    expect: { kind: 'advance' },
    // Deliberately its own step: Match returns ResultScreen the moment phase flips to
    // MATCH_OVER, so bundling this with BATTLE_RESULT would cut the kill animation short.
    emit: [{ msg: { type: 'MATCH_RESULT', winners: [YOU], reason: 'LAST_STANDING' } }],
    dock: 'center',
  },
];
