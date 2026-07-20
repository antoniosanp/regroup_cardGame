// Client-side cosmetic countdown for the 60s turn cap documented in
// WS_CONTRACT.md. The server never sends a deadline/timestamp on the wire, so
// this can only approximate: it resets to 60s whenever a new turn begins
// (round/currentSeat/phase changes) and ticks down locally. The real
// enforcement (auto-play on expiry) stays entirely server-side; this is
// display only, never authoritative.

import { useEffect, useRef, useState } from 'react';
import { BOARD_ART } from '../../online/assets';
import type { Phase } from '../../online/messages';
import { playSfx } from '../../sfx/playSfx';

const TURN_SECONDS = 60;

interface TurnTimerProps {
  phase: Phase;
  round: number;
  currentSeat: number;
  currentName?: string;
  isYourTurn: boolean;
}

export function TurnTimer({ phase, round, currentSeat, currentName, isYourTurn }: TurnTimerProps) {
  const [secondsLeft, setSecondsLeft] = useState(TURN_SECONDS);

  useEffect(() => {
    setSecondsLeft(TURN_SECONDS);
    if (phase !== 'TURN') return;
    const id = setInterval(() => {
      setSecondsLeft((s) => {
        const next = s > 0 ? s - 1 : 0;
        // Ticks only for your own turn's countdown, and only the single
        // second the value actually crosses 0 (the interval keeps firing
        // at 0 afterward until this effect resets for the next turn).
        if (isYourTurn) {
          if (next > 0 && next <= 10) playSfx('timer-low-tick');
          else if (next === 0 && s > 0) playSfx('timer-expired');
        }
        return next;
      });
    }, 1000);
    return () => clearInterval(id);
    // Resets only for a genuinely new turn, not on every render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [round, currentSeat, phase]);

  const wasYourTurn = useRef(isYourTurn);
  useEffect(() => {
    if (isYourTurn && !wasYourTurn.current) playSfx('turn-yours');
    wasYourTurn.current = isYourTurn;
  }, [isYourTurn]);

  const inTurn = phase === 'TURN';
  const low = inTurn && secondsLeft <= 10;
  const mm = Math.floor(secondsLeft / 60);
  const ss = secondsLeft % 60;

  return (
    <div
      className={`turn-timer${low ? ' turn-timer-low' : ''}`}
      style={{ backgroundImage: `url(${BOARD_ART.panelSquare})` }}
    >
      <div className="turn-timer-value">{inTurn ? `${mm}:${ss.toString().padStart(2, '0')}` : '--:--'}</div>
      <div className="turn-timer-label">
        {phase === 'TURN'
          ? isYourTurn
            ? 'Your turn'
            : (currentName ?? 'Waiting…')
          : phase === 'BATTLE'
            ? 'Battle'
            : ''}
      </div>
    </div>
  );
}
