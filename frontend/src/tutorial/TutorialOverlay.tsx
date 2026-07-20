// Coaching layer drawn over the real Match UI. A full-screen blocker swallows every pointer
// and drag event, and the current step's target elements are lifted above it by a class, so
// exactly one path through the UI stays live. This works because no Match ancestor creates a
// stacking context — verified against styles.css — which is what lets a plain z-index lift
// beat rect-based cutouts (it also supports several holes at once, which the drag step needs:
// the held card for dragstart AND the board for dragover/drop).

import { useLayoutEffect } from 'react';
import { playSfx } from '../sfx/playSfx';
import type { DriverView } from './TutorialDriver';

interface TutorialOverlayProps {
  view: DriverView;
  /** Changes whenever the store remounts the DOM the step selectors point at. */
  domRevision: string;
  onNext: () => void;
  onExit: () => void;
}

export function TutorialOverlay({ view, domRevision, onNext, onExit }: TutorialOverlayProps) {
  const { step, index, total } = view;

  useLayoutEffect(() => {
    if (!step) return;
    const mark = (selectors: string[], className: string) => {
      const els = selectors.flatMap((sel) => [...document.querySelectorAll<HTMLElement>(sel)]);
      els.forEach((el) => el.classList.add(className));
      return () => els.forEach((el) => el.classList.remove(className));
    };
    const unmarkTargets = mark(step.interactive, 'tutorial-target');
    const unmarkRings = mark(step.pointAt ?? [], 'tutorial-ring');
    return () => {
      unmarkTargets();
      unmarkRings();
    };
  }, [step, domRevision]);

  if (!step) return null;

  const waitingOnPlayer = step.expect.kind !== 'advance';

  return (
    <>
      <div
        className="tutorial-blocker"
        // Off-script clicks should feel deliberately refused rather than dead.
        onPointerDownCapture={() => playSfx('pick-denied')}
      />
      <div className={`tutorial-coach tutorial-coach-${step.dock}`}>
        <div className="tutorial-coach-step">
          Step {index + 1} of {total}
        </div>
        <h3 className="tutorial-coach-title">{step.title}</h3>
        <p className="tutorial-coach-text">{step.text}</p>
        <div className="tutorial-coach-actions">
          <button className="btn-ghost" onClick={onExit}>
            Exit tutorial
          </button>
          {waitingOnPlayer ? (
            <span className="tutorial-coach-waiting">Your move — follow the highlight</span>
          ) : (
            <button className="btn-primary" onClick={onNext}>
              Next
            </button>
          )}
        </div>
      </div>
    </>
  );
}
