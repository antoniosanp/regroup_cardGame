// Online-mode state for Regroup. The backend is the source of truth: this store
// only reflects WS_CONTRACT.md messages and never computes game rules (no stat
// calculation, no placement legality, no battle math — the server owns all of
// it). Regroup has no hidden information, so every board / the market / all
// stats are mirrored in full for every player.

import { createContext, useContext } from 'react';
import { createStore, useStore } from 'zustand';
import {
  clearIdentity,
  loadIdentity,
  registerPlayer,
  saveIdentity,
  type Identity,
} from './api';
import { cardToPoints, pointKey, rotateCornersOnce, type BoardPoint, type Card, type CornerName } from './cards';
import {
  parsePrivateMessage,
  parseTopicMessage,
  type Attack,
  type Outcome,
  type Phase,
  type PlayerState,
  type Slot,
  type Stats,
} from './messages';
import { StompGameSocket, type GameSocket, type GameSocketFactory } from './socket';
import { playSfx } from '../sfx/playSfx';

// Coin price per market slot (mirrors Market.tsx's own PRICE map); needed here
// too, since coin-spend layers on top of card-pick only when a slot was paid.
const SLOT_PRICE: Record<'A' | 'B' | 'C', number> = { A: 0, B: 1, C: 2 };

export type ConnStatus = 'idle' | 'connecting' | 'connected' | 'reconnecting' | 'failed';
export type Stage = 'name' | 'lobby' | 'queue' | 'match';

const STARTING_STATS: Stats = { hp: 30, pa: 0, pd: 0, ma: 0, md: 0, cn: 0, hpp: 0 };

export interface Market {
  A: Card | null;
  B: Card | null;
  C: Card | null;
}

export interface BattleVM {
  round: number;
  attacks: Attack[];
  outcomes: Outcome[];
}

export interface OnlineState {
  conn: ConnStatus;
  stage: Stage;
  identity: Identity | null;
  error: { code: string; message: string } | null;

  matchId: string | null;
  yourSeat: number;
  players: PlayerState[];
  connected: Record<string, boolean>;

  phase: Phase;
  round: number;
  currentSeat: number;
  // Seat that opened this round (first to move). Only ROUND_START carries it on
  // the wire; RESUME_STATE (reconnect) doesn't, so it's derived there via the same
  // (round - 1) % PLAYER_COUNT rotation MatchEngine uses server-side.
  startingSeat: number;
  finalRound: boolean;

  boards: Record<string, BoardPoint[]>;
  market: Market;
  deckRemaining: number;

  // The in-progress card of whoever is acting. Public (no hidden info): learned
  // from CARD_PICKED broadcasts for everyone, and from RESUME_STATE for self.
  heldCard: Card | null;
  heldBy: string | null;
  // In-flight pick/place lock to prevent double submits until the server echoes.
  busy: boolean;

  lastBattle: BattleVM | null;
  winners: string[] | null;
  reason: string | null;

  start: (name: string) => Promise<void>;
  /**
   * Connects with an identity we already hold, skipping HTTP registration. Only the tutorial
   * uses this: its identity is fabricated rather than registered, but it still needs to go
   * through the real connect() handshake so the store runs its genuine code paths.
   */
  startWithIdentity: (identity: Identity) => void;
  joinQueue: () => void;
  leaveQueue: () => void;
  playOffline: () => void;
  pick: (slot: Slot) => void;
  rotate: () => void;
  place: (corner: CornerName, x: number, y: number) => void;
  dismissError: () => void;
  leave: () => void;
}

const MATCH_RESET = {
  matchId: null as string | null,
  yourSeat: -1,
  players: [] as PlayerState[],
  connected: {} as Record<string, boolean>,
  phase: 'TURN' as Phase,
  round: 0,
  currentSeat: -1,
  startingSeat: -1,
  finalRound: false,
  boards: {} as Record<string, BoardPoint[]>,
  market: { A: null, B: null, C: null } as Market,
  deckRemaining: 0,
  heldCard: null as Card | null,
  heldBy: null as string | null,
  busy: false,
  lastBattle: null as BattleVM | null,
  winners: null as string[] | null,
  reason: null as string | null,
};

function mergePoints(existing: BoardPoint[] | undefined, added: BoardPoint[]): BoardPoint[] {
  const map = new Map<string, BoardPoint>();
  for (const p of existing ?? []) map.set(pointKey(p.x, p.y), p);
  for (const p of added) map.set(pointKey(p.x, p.y), p);
  return [...map.values()];
}

export function createOnlineStore(socketFactory: GameSocketFactory) {
  let socket: GameSocket | null = null;
  // Tags the in-flight action so a subsequent ERROR can tell a rejected
  // placement (-> card-place-invalid) apart from any other rejection
  // (-> ui-error). Purely an internal sfx concern, not part of OnlineState.
  let lastAction: 'pick' | 'place' | 'rotate' | null = null;

  const store = createStore<OnlineState>((set, get) => {
    function handlePrivate(raw: unknown): void {
      const msg = parsePrivateMessage(raw);
      if (!msg) return;
      const self = get().identity?.playerId;
      switch (msg.type) {
        case 'MATCH_FOUND': {
          playSfx('match-found');
          socket?.subscribeMatch(msg.matchId);
          set({
            stage: 'match',
            ...MATCH_RESET,
            matchId: msg.matchId,
            yourSeat: msg.yourSeat,
            players: msg.players.map((p) => ({
              ...p,
              alive: true,
              stats: { ...STARTING_STATS },
            })),
            connected: Object.fromEntries(msg.players.map((p) => [p.playerId, true])),
          });
          // MATCH_FOUND carries no market/board; pull the initial snapshot.
          socket?.publish(`/app/match.${msg.matchId}.resume`, {});
          break;
        }
        case 'RESUME_STATE': {
          socket?.subscribeMatch(msg.matchId);
          const prev = get();
          const isSelfTurn = msg.currentSeat === prev.yourSeat;
          set({
            stage: 'match',
            matchId: msg.matchId,
            phase: msg.phase,
            round: msg.round,
            currentSeat: msg.currentSeat,
            // Matches MatchEngine's fixed 4-seat rotation (startingSeat = (round - 1) % PLAYER_COUNT).
            startingSeat: (msg.round - 1) % 4,
            finalRound: msg.finalRound,
            players: msg.players,
            connected: Object.fromEntries(msg.players.map((p) => [p.playerId, true])),
            boards: msg.boards,
            market: msg.market,
            deckRemaining: msg.deckRemaining,
            // RESUME_STATE only carries OUR held card. If someone else is
            // acting, keep whatever we learned from their CARD_PICKED broadcast.
            heldCard: isSelfTurn ? msg.heldCard : prev.heldCard,
            heldBy: isSelfTurn ? (msg.heldCard ? (self ?? null) : null) : prev.heldBy,
            busy: false,
          });
          break;
        }
        case 'ERROR': {
          const s = get();
          playSfx(lastAction === 'place' ? 'card-place-invalid' : 'ui-error');
          lastAction = null;
          if (msg.code === 'NOT_IN_MATCH' && s.stage === 'match') {
            set({ ...MATCH_RESET, stage: 'lobby', error: { code: msg.code, message: msg.message } });
          } else {
            // Any rejected action unlocks the UI so the player can retry.
            set({ busy: false, error: { code: msg.code, message: msg.message } });
          }
          break;
        }
      }
    }

    function handleTopic(raw: unknown): void {
      const msg = parseTopicMessage(raw);
      if (!msg) return;
      switch (msg.type) {
        case 'ROUND_START':
          set({
            round: msg.round,
            phase: 'TURN',
            currentSeat: msg.startingSeat,
            startingSeat: msg.startingSeat,
            finalRound: msg.finalRound,
            heldCard: null,
            heldBy: null,
            busy: false,
            lastBattle: null,
          });
          break;
        case 'TURN_START':
          set({ currentSeat: msg.seat, heldCard: null, heldBy: null, busy: false });
          break;
        case 'CARD_PICKED': {
          const self = get().identity?.playerId;
          if (msg.playerId === self) {
            lastAction = null;
            if (msg.slot === 'DECK') {
              playSfx('deck-draw');
            } else {
              playSfx('card-pick');
              const price = get().finalRound ? 0 : SLOT_PRICE[msg.slot];
              if (price > 0) playSfx('coin-spend');
            }
          }
          // market/deckRemaining reflect the post-shift-and-refill state directly
          // from the server, so no extra round trip is needed here.
          set({
            heldCard: msg.card,
            heldBy: msg.playerId,
            market: msg.market,
            deckRemaining: msg.deckRemaining,
            busy: false,
          });
          break;
        }
        case 'CARD_ROTATED': {
          // The broadcast carries only the new rotation, not re-oriented corners. The server mutated
          // its card's corners one clockwise step (Card.rotate()), so mirror that here — corners must
          // stay the literal current arrangement, never "base corners plus a rotation to re-apply".
          const s = get();
          if (s.heldCard) {
            set({ heldCard: { ...rotateCornersOnce(s.heldCard), rotation: msg.rotation } });
          }
          if (msg.playerId === s.identity?.playerId) lastAction = null;
          break;
        }
        case 'CARD_PLACED': {
          const s = get();
          const self = s.identity?.playerId;
          if (msg.playerId === self) {
            lastAction = null;
            playSfx('card-place');
          }
          const points = cardToPoints(msg.card, msg.corner, msg.x, msg.y);
          set({
            boards: { ...s.boards, [msg.playerId]: mergePoints(s.boards[msg.playerId], points) },
            heldCard: null,
            heldBy: null,
            busy: false,
          });
          break;
        }
        case 'STATS_UPDATED': {
          const s = get();
          const self = s.identity?.playerId;
          if (msg.playerId === self) {
            const prevStats = s.players.find((p) => p.playerId === msg.playerId)?.stats;
            if (prevStats) {
              // Nets a placement's full stat delta into one sound; a placement
              // that raises one stat while lowering another (e.g. overwriting
              // a PA cluster to build PD) resolves by which way the sum tips.
              const delta =
                msg.stats.hp -
                prevStats.hp +
                (msg.stats.pa - prevStats.pa) +
                (msg.stats.pd - prevStats.pd) +
                (msg.stats.ma - prevStats.ma) +
                (msg.stats.md - prevStats.md) +
                (msg.stats.cn - prevStats.cn) +
                (msg.stats.hpp - prevStats.hpp);
              if (delta > 0) playSfx('stat-up');
              else if (delta < 0) playSfx('stat-down');
            }
          }
          set((s2) => ({
            players: s2.players.map((p) =>
              p.playerId === msg.playerId ? { ...p, stats: msg.stats } : p,
            ),
          }));
          break;
        }
        case 'BATTLE_RESULT': {
          const byPlayer = new Map(msg.outcomes.map((o) => [o.playerId, o]));
          set((s) => ({
            phase: 'BATTLE',
            lastBattle: { round: msg.round, attacks: msg.attacks, outcomes: msg.outcomes },
            // outcomes[].hpAfter is the authoritative post-battle hp for every
            // player who was alive at battle start - apply it directly rather
            // than waiting on a per-player STATS_UPDATED that never comes for
            // battle damage/healing (only placements trigger STATS_UPDATED).
            players: s.players.map((p) => {
              const o = byPlayer.get(p.playerId);
              if (!o) return p;
              return { ...p, alive: !o.eliminated, stats: { ...p.stats, hp: o.hpAfter } };
            }),
          }));
          break;
        }
        case 'PLAYER_ELIMINATED':
          set((s) => ({
            players: s.players.map((p) =>
              p.playerId === msg.playerId
                ? { ...p, alive: false, stats: { ...p.stats, hp: msg.finalHp } }
                : p,
            ),
          }));
          break;
        case 'MATCH_RESULT':
          set({ phase: 'MATCH_OVER', winners: msg.winners, reason: msg.reason });
          break;
        case 'PLAYER_DISCONNECTED':
          set((s) => ({ connected: { ...s.connected, [msg.playerId]: false } }));
          break;
        case 'PLAYER_RECONNECTED':
          set((s) => ({ connected: { ...s.connected, [msg.playerId]: true } }));
          break;
      }
    }

    function connect(identity: Identity): void {
      socket = socketFactory();
      set({ conn: 'connecting' });
      socket.activate(identity.token, {
        onConnect: () => {
          const s = get();
          const wasNameStage = s.stage === 'name';
          set({ conn: 'connected', stage: wasNameStage ? 'lobby' : s.stage });
          if (wasNameStage) playSfx('ui-connect');
          if (s.matchId) {
            socket?.publish(`/app/match.${s.matchId}.resume`, {});
          } else if (s.stage === 'queue') {
            socket?.publish('/app/queue.join', {});
          }
        },
        onDisconnect: () => {
          if (get().conn === 'connected') {
            playSfx('ui-reconnecting');
            set({ conn: 'reconnecting' });
          }
        },
        onPrivateMessage: handlePrivate,
        onMatchMessage: handleTopic,
      });
    }

    return {
      conn: 'idle',
      stage: 'name',
      identity: null,
      error: null,
      ...MATCH_RESET,

      start: async (name: string) => {
        const trimmed = name.trim();
        if (!trimmed) return;
        set({ error: null, conn: 'connecting' });
        try {
          const stored = loadIdentity();
          const identity =
            stored && stored.name === trimmed ? stored : await registerPlayer(trimmed);
          saveIdentity(identity);
          set({ identity });
          connect(identity);
        } catch (e) {
          clearIdentity();
          playSfx('ui-error');
          set({ conn: 'failed', error: { code: 'REGISTER_FAILED', message: (e as Error).message } });
        }
      },

      startWithIdentity: (identity: Identity) => {
        set({ error: null, identity });
        connect(identity);
      },

      joinQueue: () => {
        set({ stage: 'queue', error: null });
        socket?.publish('/app/queue.join', {});
      },

      leaveQueue: () => {
        socket?.publish('/app/queue.leave', {});
        set({ stage: 'lobby' });
      },

      // Offline single-player vs 3 server-side bots. Unlike joinQueue, we don't
      // flip to 'queue' first: the server forms the 4-seat match instantly and
      // replies with the same MATCH_FOUND private message, whose handler flips
      // stage to 'match'. So we just clear any error and fire the publish.
      playOffline: () => {
        set({ error: null });
        socket?.publish('/app/queue.joinOffline', {});
      },

      pick: (slot: Slot) => {
        const s = get();
        if (s.stage !== 'match' || s.phase !== 'TURN') return;
        if (s.currentSeat !== s.yourSeat || s.heldBy !== null || s.busy) return;
        lastAction = 'pick';
        set({ busy: true });
        socket?.publish(`/app/match.${s.matchId}.pick`, { slot });
      },

      rotate: () => {
        const s = get();
        if (s.heldBy !== s.identity?.playerId) return;
        lastAction = 'rotate';
        socket?.publish(`/app/match.${s.matchId}.rotate`, {});
      },

      place: (corner: CornerName, x: number, y: number) => {
        const s = get();
        if (s.heldBy !== s.identity?.playerId || s.busy) return;
        lastAction = 'place';
        set({ busy: true });
        socket?.publish(`/app/match.${s.matchId}.place`, { corner, x, y });
      },

      dismissError: () => set({ error: null }),

      leave: () => {
        socket?.deactivate();
        socket = null;
        set({ conn: 'idle', stage: 'name', error: null, ...MATCH_RESET });
      },
    };
  });

  return store;
}

export const onlineStore = createOnlineStore(() => new StompGameSocket());

export type OnlineStoreApi = ReturnType<typeof createOnlineStore>;

// Defaults to the app-wide singleton, so every existing caller is unaffected and
// no provider is needed around the normal app. The tutorial overrides it with its
// own store driven by a scripted in-memory socket — that is what lets the tutorial
// render the real Match UI verbatim instead of a fork that would silently drift.
export const OnlineStoreContext = createContext<OnlineStoreApi>(onlineStore);

export function useOnlineStore<T>(selector: (s: OnlineState) => T): T {
  return useStore(useContext(OnlineStoreContext), selector);
}
