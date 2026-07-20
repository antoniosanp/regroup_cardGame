// Full-screen battle-phase overlay. Plays BATTLE_RESULT.attacks[] grouped
// into per-attacker phases (consecutive same-attackerId rows, per
// WS_CONTRACT.md's resolution-order description): the attacker takes the
// left "attacker square" (portrait, PA, MA) while every player sits in a
// fixed-position column on the right (portrait, animated HP, PD, MD) — the
// current attacker's own row is dimmed with an "attacking" tag rather than
// removed, so row positions never reflow mid-battle. Each hit is a single
// lunge-and-return of the attacker square toward the target row (no flying
// projectile), an impact flash on the row, and the row's HP counting down via
// AnimatedNumber. Purely presentational: every number comes from the
// server's BATTLE_RESULT; this never computes game rules.

import { useEffect, useRef, useState } from 'react';
import { avatarFor, BOARD_ART } from '../../online/assets';
import type { Attack, PlayerState } from '../../online/messages';
import type { BattleVM } from '../../online/onlineStore';
import { playSfx } from '../../sfx/playSfx';
import { AnimatedNumber } from './AnimatedNumber';
import { BattlePanel } from './BattlePanel';

interface BattleStageProps {
  battle: BattleVM;
  players: PlayerState[];
  selfId: string;
  nameOf: (playerId: string) => string;
}

interface Floater {
  id: number;
  x: number;
  y: number;
  text: string;
  kind: 'damage' | 'heal' | 'blocked';
}

interface AttackerPhase {
  attackerId: string;
  attacks: Attack[];
}

function groupByAttacker(attacks: Attack[]): AttackerPhase[] {
  const phases: AttackerPhase[] = [];
  for (const a of attacks) {
    const last = phases[phases.length - 1];
    if (last && last.attackerId === a.attackerId) {
      last.attacks.push(a);
    } else {
      phases.push({ attackerId: a.attackerId, attacks: [a] });
    }
  }
  return phases;
}

function animate(el: Element, keyframes: Keyframe[], options: KeyframeAnimationOptions): Promise<void> {
  return el.animate(keyframes, options).finished.then(
    () => undefined,
    () => undefined, // a cancelled animation is not an error here
  );
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}

export function BattleStage({ battle, players, selfId, nameOf }: BattleStageProps) {
  const ordered = [...players].sort((a, b) => a.seat - b.seat);

  const arenaRef = useRef<HTMLDivElement | null>(null);
  const attackerRef = useRef<HTMLDivElement | null>(null);
  const rowRefs = useRef(new Map<string, HTMLDivElement>());
  const flashRefs = useRef(new Map<string, HTMLDivElement>());
  const skippedRef = useRef(false);
  const floaterId = useRef(0);
  // Lets the Skip button (defined in the render body, below) reach into the
  // per-battle finishInstantly() that lives inside the effect's closure.
  const finishInstantlyRef = useRef<() => void>(() => {});

  const [shownHp, setShownHp] = useState<Record<string, number>>({});
  const [deadIds, setDeadIds] = useState<Set<string>>(new Set());
  const [floaters, setFloaters] = useState<Floater[]>([]);
  const [activeAttackerId, setActiveAttackerId] = useState<string | null>(null);
  const [highlightDefenderId, setHighlightDefenderId] = useState<string | null>(null);
  const [finished, setFinished] = useState(false);

  useEffect(() => {
    skippedRef.current = false;
    setFinished(false);
    setDeadIds(new Set());
    setFloaters([]);
    setActiveAttackerId(null);
    setHighlightDefenderId(null);
    setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpBefore])));

    playSfx('battle-start');

    let cancelled = false;
    const active = () => !cancelled && !skippedRef.current;

    // Skip can call this once immediately (so the UI snaps right away) and
    // the async sequence below calls it again shortly after when it notices
    // skippedRef - both calls must re-set the same final state (idempotent,
    // harmless), but the finish sounds must only play once.
    let playedFinishSound = false;
    const finishInstantly = () => {
      setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpAfter])));
      const eliminatedNow = battle.outcomes.filter((o) => o.eliminated);
      setDeadIds(new Set(eliminatedNow.map((o) => o.playerId)));
      setActiveAttackerId(null);
      setHighlightDefenderId(null);
      setFinished(true);
      if (!playedFinishSound) {
        playedFinishSound = true;
        eliminatedNow.forEach(() => playSfx('eliminated'));
        playSfx('battle-end');
      }
    };
    finishInstantlyRef.current = finishInstantly;

    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches) {
      finishInstantly();
      return;
    }

    const addFloater = (playerId: string, text: string, kind: Floater['kind']) => {
      const rowEl = rowRefs.current.get(playerId);
      const arenaEl = arenaRef.current;
      if (!rowEl || !arenaEl) return;
      const rowRect = rowEl.getBoundingClientRect();
      const arenaRect = arenaEl.getBoundingClientRect();
      const id = ++floaterId.current;
      const x = rowRect.left - arenaRect.left + rowRect.width / 2;
      const y = rowRect.top - arenaRect.top;
      setFloaters((fs) => [...fs, { id, x, y, text, kind }]);
      setTimeout(() => setFloaters((fs) => fs.filter((f) => f.id !== id)), 950);
    };

    (async () => {
      const phases = groupByAttacker(battle.attacks);

      for (const phase of phases) {
        if (!active()) break;
        setActiveAttackerId(phase.attackerId);
        playSfx('attacker-step');
        // Pause so the viewer registers who's attacking before hits start.
        await sleep(450);
        if (!active()) break;

        for (const attack of phase.attacks) {
          if (!active()) break;
          setHighlightDefenderId(attack.defenderId);

          const attackerEl = attackerRef.current;
          const rowEl = rowRefs.current.get(attack.defenderId);
          if (attackerEl && rowEl) {
            const aRect = attackerEl.getBoundingClientRect();
            const dRect = rowEl.getBoundingClientRect();
            const dx = (dRect.left - aRect.left) * 0.55;
            const dy = (dRect.top + dRect.height / 2 - (aRect.top + aRect.height / 2)) * 0.55;
            playSfx('attack-lunge');
            await animate(
              attackerEl,
              [
                { transform: 'translate(0, 0) scale(1)' },
                { transform: `translate(${dx}px, ${dy}px) scale(1.08)` },
                { transform: 'translate(0, 0) scale(1)' },
              ],
              { duration: 600, easing: 'ease-in-out' },
            );
          }
          if (!active()) break;

          const isBlocked = attack.totalDamage <= 0;
          if (isBlocked) {
            playSfx('hit-blocked');
          } else {
            const useChicken = Math.random() < 1 / 8;
            playSfx(useChicken ? 'hit-impact-chicken' : 'hit-impact', { pitchVariance: 0.1 });
            playSfx('hp-tick');
          }
          addFloater(
            attack.defenderId,
            isBlocked ? '0' : `-${attack.totalDamage}`,
            isBlocked ? 'blocked' : 'damage',
          );
          if (!isBlocked) {
            setShownHp((hp) => ({
              ...hp,
              [attack.defenderId]: (hp[attack.defenderId] ?? 0) - attack.totalDamage,
            }));
          }

          const flashEl = flashRefs.current.get(attack.defenderId);
          if (flashEl) {
            await animate(flashEl, [{ opacity: 0 }, { opacity: isBlocked ? 0.35 : 0.75 }, { opacity: 0 }], {
              duration: 420,
            });
          }
          setHighlightDefenderId(null);
          if (!active()) break;
          await sleep(280);
        }
      }

      if (cancelled) return;
      setActiveAttackerId(null);

      if (!skippedRef.current) {
        for (const o of battle.outcomes) {
          if (o.healedHp > 0 && !o.eliminated) {
            addFloater(o.playerId, `+${o.healedHp}`, 'heal');
            playSfx('heal');
          }
        }
        setShownHp(Object.fromEntries(battle.outcomes.map((o) => [o.playerId, o.hpAfter])));
        const eliminatedNow = battle.outcomes.filter((o) => o.eliminated);
        setDeadIds(new Set(eliminatedNow.map((o) => o.playerId)));
        eliminatedNow.forEach(() => playSfx('eliminated'));
        if (eliminatedNow.length > 0) await sleep(700);
        if (!cancelled) {
          setFinished(true);
          playSfx('battle-end');
        }
      } else {
        finishInstantly();
      }
    })();

    return () => {
      cancelled = true;
    };
    // The sequence replays only for a genuinely new battle result.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [battle]);

  const attacker = ordered.find((p) => p.playerId === activeAttackerId) ?? null;

  return (
    <div className="battle-overlay" role="dialog" aria-label={`Battle, round ${battle.round}`}>
      <h3 className="battle-stage-title">Battle — round {battle.round}</h3>

      <div className="battle-arena" ref={arenaRef}>
        <div className="battle-attacker-pane">
          <div className="battle-attacker" ref={attackerRef}>
            {attacker ? (
              <>
                <img className="battle-attacker-avatar" src={avatarFor(attacker.seat)} alt={attacker.name} />
                <div className="battle-attacker-name">
                  {attacker.name}
                  {attacker.playerId === selfId ? ' (you)' : ''}
                </div>
                <div className="battle-attacker-stats">
                  <span className="battle-stat">
                    <img src={BOARD_ART.pa} alt="PA" />
                    {attacker.stats.pa}
                  </span>
                  <span className="battle-stat">
                    <img src={BOARD_ART.ma} alt="MA" />
                    {attacker.stats.ma}
                  </span>
                </div>
              </>
            ) : (
              <div className="battle-attacker-placeholder">···</div>
            )}
          </div>
        </div>

        <div className="battle-defenders">
          {ordered.map((p) => {
            const isAttackerNow = p.playerId === activeAttackerId;
            const isHighlighted = p.playerId === highlightDefenderId;
            const isDead = deadIds.has(p.playerId);
            const hp = shownHp[p.playerId] ?? p.stats.hp;
            return (
              <div
                key={p.playerId}
                ref={(el) => {
                  if (el) rowRefs.current.set(p.playerId, el);
                  else rowRefs.current.delete(p.playerId);
                }}
                className={`battle-defender-row${isAttackerNow ? ' battle-row-attacking' : ''}${
                  isHighlighted ? ' battle-row-hit' : ''
                }${isDead ? ' battle-row-dead' : ''}${p.playerId === selfId ? ' battle-row-self' : ''}`}
              >
                <img className="battle-defender-avatar" src={avatarFor(p.seat)} alt={p.name} />
                <div className="battle-defender-info">
                  <div className="battle-defender-name">
                    {p.name}
                    {p.playerId === selfId ? ' (you)' : ''}
                    {isDead && <span className="battle-dead-badge">💀</span>}
                    {isAttackerNow && <span className="flag flag-turn">attacking</span>}
                  </div>
                  <div className="battle-defender-stats">
                    <span className={`battle-stat battle-stat-hp${hp <= 0 ? ' battle-stat-hp-dead' : ''}`}>
                      <img src={BOARD_ART.hp} alt="HP" />
                      <AnimatedNumber value={hp} />
                    </span>
                    <span className="battle-stat">
                      <img src={BOARD_ART.pd} alt="PD" />
                      {p.stats.pd}
                    </span>
                    <span className="battle-stat">
                      <img src={BOARD_ART.md} alt="MD" />
                      {p.stats.md}
                    </span>
                  </div>
                </div>
                <div
                  className="battle-flash"
                  ref={(el) => {
                    if (el) flashRefs.current.set(p.playerId, el);
                    else flashRefs.current.delete(p.playerId);
                  }}
                />
              </div>
            );
          })}
        </div>

        {floaters.map((f) => (
          <div
            key={f.id}
            className={`battle-floater battle-floater-${f.kind}`}
            style={{ left: f.x, top: f.y }}
          >
            {f.text}
          </div>
        ))}
      </div>

      {!finished && battle.attacks.length > 0 && (
        <button
          className="btn-ghost battle-skip"
          onClick={() => {
            playSfx('battle-skip');
            skippedRef.current = true;
            finishInstantlyRef.current?.();
          }}
        >
          Skip animation
        </button>
      )}

      {finished && (
        <div className="battle-stage-log">
          <BattlePanel battle={battle} nameOf={nameOf} />
          <p className="hint">Next round starts automatically…</p>
        </div>
      )}
    </div>
  );
}
