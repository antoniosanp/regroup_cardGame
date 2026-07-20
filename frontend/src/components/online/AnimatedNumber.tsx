// Small reusable tween: animates its displayed integer from whatever it was
// previously showing to a new `value` over `duration`ms, flashing red while
// decreasing / green while increasing. Used for HP everywhere it can change
// (battle stage, player hud) so a hit or heal is visible as a counting
// animation, not just a number that jumps.

import { useEffect, useRef, useState } from 'react';

interface AnimatedNumberProps {
  value: number;
  duration?: number;
  className?: string;
}

export function AnimatedNumber({ value, duration = 500, className }: AnimatedNumberProps) {
  const [display, setDisplay] = useState(value);
  const [flash, setFlash] = useState<'up' | 'down' | null>(null);
  const displayRef = useRef(value);
  const rafRef = useRef<number | null>(null);
  const flashTimeoutRef = useRef<ReturnType<typeof setTimeout> | null>(null);

  useEffect(() => {
    const from = displayRef.current;
    if (from === value) return;
    setFlash(value < from ? 'down' : 'up');

    if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    const start = performance.now();

    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      const current = Math.round(from + (value - from) * t);
      displayRef.current = current;
      setDisplay(current);
      if (t < 1) {
        rafRef.current = requestAnimationFrame(tick);
      } else {
        rafRef.current = null;
      }
    };
    rafRef.current = requestAnimationFrame(tick);

    if (flashTimeoutRef.current) clearTimeout(flashTimeoutRef.current);
    flashTimeoutRef.current = setTimeout(() => setFlash(null), duration + 300);

    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    };
    // Only the target value/duration should restart the tween.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [value, duration]);

  useEffect(
    () => () => {
      if (flashTimeoutRef.current) clearTimeout(flashTimeoutRef.current);
    },
    [],
  );

  return (
    <span
      className={`animated-number${flash ? ` animated-number-${flash}` : ''}${className ? ` ${className}` : ''}`}
    >
      {display}
    </span>
  );
}
