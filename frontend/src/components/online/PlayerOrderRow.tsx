// Small strip under the opponent-board button showing every seat's turn order
// for the current round: a portrait, a silver placement number (1 = moves
// first), a shine on whoever's turn it is right now, and a skull badge
// (placeholder art — no chicken-skull asset exists yet) on this round's first
// mover. Purely presentational, derived from state the store already tracks.

import { avatarFor } from '../../online/assets';
import type { PlayerState, Phase } from '../../online/messages';

interface PlayerOrderRowProps {
  players: PlayerState[];
  currentSeat: number;
  startingSeat: number;
  phase: Phase;
  selfId: string;
}

// Seats rotate through a fixed 4-player order (MatchEngine.PLAYER_COUNT), so
// turnOrder is always 1-4.
const ORDINALS = ['', '1st', '2nd', '3rd', '4th'];

export function PlayerOrderRow({ players, currentSeat, startingSeat, phase, selfId }: PlayerOrderRowProps) {
  const ordered = [...players].sort((a, b) => a.seat - b.seat);
  if (ordered.length === 0 || startingSeat < 0) return null;

  return (
    <div className="player-order-row">
      {ordered.map((p) => {
        const isFirstMover = p.seat === startingSeat;
        const isActive = phase === 'TURN' && p.seat === currentSeat;
        const turnOrder = ((p.seat - startingSeat + 4) % 4) + 1;
        return (
          <div
            key={p.playerId}
            className={`player-order-item${p.alive ? '' : ' player-order-item-dead'}${
              p.playerId === selfId ? ' player-order-item-self' : ''
            }`}
            title={`${p.name}${p.playerId === selfId ? ' (you)' : ''} — moves ${ORDINALS[turnOrder]} this round`}
          >
            <img className="player-order-avatar" src={avatarFor(p.seat)} alt={p.name} />
            <span className={`player-order-number${isActive ? ' player-order-number-active' : ''}`}>
              {turnOrder}
            </span>
            {isFirstMover && (
              <span className="player-order-firstmover-badge" aria-label="Moves first this round">
                💀
              </span>
            )}
          </div>
        );
      })}
    </div>
  );
}
