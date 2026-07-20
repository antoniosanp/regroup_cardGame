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

// Your board at the start: the two PA_1s are orthogonally adjacent so they count
// (pa 2), while the lone COINS_2 touches nothing — which is exactly the point the
// adjacency step makes.
const YOUR_BOARD: BoardPoint[] = [
  { x: 0, y: 0, attribute: 'EMPTY' },
  { x: 1, y: 0, attribute: 'COINS_2' },
  { x: 0, y: 1, attribute: 'PA_1' },
  { x: 1, y: 1, attribute: 'PA_1' },
];

// Cosmetic only — visible if the player opens the opponent-boards modal.
const GORN_BOARD: BoardPoint[] = [
  { x: 0, y: 0, attribute: 'PA_1' },
  { x: 1, y: 0, attribute: 'PA_1' },
  { x: 0, y: 1, attribute: 'EMPTY' },
  { x: 1, y: 1, attribute: 'MD_1' },
];

// Slot A is free but deliberately weak, so "free isn't always right" is a real lesson.
const MARKET_A: Card = {
  topLeft: 'MD_1',
  topRight: 'EMPTY',
  bottomLeft: 'EMPTY',
  bottomRight: 'MD_1',
  rotation: 'DEG_0',
};

// The card the lesson is built around. PA_2 sits bottom-left, so exactly one
// clockwise rotation (rotateCornersOnce sets topLeft = bottomLeft) is needed to
// bring it to top-left where it can touch your existing PA_1.
const LESSON_CARD: Card = {
  topLeft: 'EMPTY',
  topRight: 'EMPTY',
  bottomLeft: 'PA_2',
  bottomRight: 'COINS_2',
  rotation: 'DEG_0',
};

// Two coins — out of reach this turn on 3 coins minus the 1 spent on slot B.
const MARKET_C: Card = {
  topLeft: 'MA_2',
  topRight: 'EMPTY',
  bottomLeft: 'EMPTY',
  bottomRight: 'MA_1',
  rotation: 'DEG_0',
};

/** LESSON_CARD after one clockwise turn, as the store will compute it from CARD_ROTATED. */
const LESSON_CARD_ROTATED: Card = {
  topLeft: 'PA_2',
  topRight: 'EMPTY',
  bottomLeft: 'COINS_2',
  bottomRight: 'EMPTY',
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
    text: 'The market charges by position: the card furthest from the deck is free, the next costs 1 coin, the closest costs 2. The free card is all defense and does nothing for you here. Spend 1 of your 3 coins on the second card — it carries a 2 physical attack corner.',
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
    text: 'The 2 physical attack corner is on the bottom-left, but it needs to be top-left to end up touching the attack corner already on your board. Rotate the card once.',
    interactive: [SEL.rotateButton],
    expect: { kind: 'rotate' },
    emit: [{ msg: { type: 'CARD_ROTATED', playerId: YOU, rotation: 'DEG_90' } }],
    dock: 'top',
  },
  {
    id: 'adjacency',
    title: 'Why adjacency matters',
    text: 'This is the whole game: a corner only counts if it touches a matching corner up, down, left or right. Your two attack corners touch, so you have 2 physical attack. The coins corner beside them touches nothing of its own kind — it still gives coins, but stats need neighbours.',
    interactive: [],
    expect: { kind: 'advance' },
    dock: 'top',
    emit: [],
  },
  {
    id: 'place',
    title: 'Place the card',
    text: 'Grab the card by its top-left corner and drop it on the highlighted square. A new card must always overlap cards already on your board — this one covers your 1 attack corner and replaces it with the 2.',
    interactive: [SEL.heldCard, SEL.board],
    pointAt: [SEL.targetCell],
    expect: { kind: 'place', corner: 'TOP_LEFT', x: 1, y: 1 },
    emit: [
      {
        msg: {
          type: 'CARD_PLACED',
          playerId: YOU,
          corner: 'TOP_LEFT',
          x: 1,
          y: 1,
          card: LESSON_CARD_ROTATED,
        },
      },
      {
        msg: {
          type: 'STATS_UPDATED',
          playerId: YOU,
          // pa 1 + pa 2 now adjacent -> 3. Coins are unchanged: the card's own coins
          // corner lands on top of the coins corner already there, so nothing is gained.
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
    text: 'Your 1 attack corner now sits next to the 2 attack corner, so they add up: 3 physical attack. Gorn has 3 health and no physical defense at all.',
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
