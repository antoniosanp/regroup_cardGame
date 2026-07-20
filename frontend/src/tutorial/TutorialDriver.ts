// Owns the tutorial's step cursor and plays the role of the server. It advances only when
// the player performs the exact action the current step expects, so the lesson can never
// derail or run ahead of the coaching copy.

import { playSfx } from '../sfx/playSfx';
import { TutorialSocket } from './TutorialSocket';
import {
  OPENING_RESUME,
  TUTORIAL_MATCH_FOUND,
  TUTORIAL_STEPS,
  type Expect,
  type TutorialStep,
} from './tutorialScript';

export interface DriverView {
  step: TutorialStep | null;
  index: number;
  total: number;
  done: boolean;
}

function matchesExpectation(expect: Expect, action: string, body: unknown): boolean {
  const b = (body ?? {}) as Record<string, unknown>;
  switch (expect.kind) {
    case 'pick':
      return action === 'pick' && b.slot === expect.slot;
    case 'rotate':
      return action === 'rotate';
    case 'place':
      return action === 'place' && b.corner === expect.corner && b.x === expect.x && b.y === expect.y;
    case 'advance':
      // Only the coach box's Next button moves these along; no game action should.
      return false;
  }
}

export class TutorialDriver {
  readonly socket: TutorialSocket;

  private readonly script: TutorialStep[];
  private readonly listeners = new Set<() => void>();
  private timers: number[] = [];
  private index = 0;
  // useSyncExternalStore compares snapshots by identity, so this is rebuilt only in
  // notify() — returning a fresh object per read would loop forever.
  private cachedView: DriverView;

  constructor(script: TutorialStep[] = TUTORIAL_STEPS) {
    this.script = script;
    this.cachedView = this.buildView();
    this.socket = new TutorialSocket({
      onPublish: (action, body) => this.handlePublish(action, body),
      onConnected: () => this.socket.emitPrivate(TUTORIAL_MATCH_FOUND),
    });
  }

  subscribe = (fn: () => void): (() => void) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };

  getView = (): DriverView => this.cachedView;

  /** Advances an `advance`-kind step. Called by the coach box's Next button. */
  next(): void {
    const step = this.script[this.index];
    if (!step || step.expect.kind !== 'advance') return;
    playSfx('ui-click');
    this.advance(step);
  }

  /** Clears pending emits and stops the socket. Re-armable: a remount replays from step 1. */
  stop(): void {
    this.timers.forEach((id) => clearTimeout(id));
    this.timers = [];
    this.socket.deactivate();
    this.index = 0;
    this.cachedView = this.buildView();
    this.listeners.clear();
  }

  private handlePublish(action: string, body: unknown): void {
    // The store's first act after MATCH_FOUND is a .resume request; answer it with the
    // opening snapshot. That alone seeds phase/round/currentSeat, and the RESUME_STATE
    // handler derives startingSeat as (round - 1) % 4 = 0, so no ROUND_START is needed.
    if (action === 'resume') {
      this.socket.emitPrivate(OPENING_RESUME);
      return;
    }
    const step = this.script[this.index];
    if (!step || !matchesExpectation(step.expect, action, body)) {
      this.reject();
      return;
    }
    this.advance(step);
  }

  private advance(step: TutorialStep): void {
    this.index += 1;
    for (const { msg, delayMs } of step.emit) {
      if (!delayMs) {
        this.socket.emitTopic(msg);
      } else {
        this.timers.push(window.setTimeout(() => this.socket.emitTopic(msg), delayMs));
      }
    }
    this.notify();
  }

  /**
   * Off-script actions should feel refused, not broken. `pick` and `place` set busy:true
   * before publishing, so silently dropping them would deadlock the UI — replaying the
   * step's snapshot clears busy and restores the held card without raising the red error
   * banner an ERROR frame would.
   */
  private reject(): void {
    playSfx('pick-denied');
    const snapshot = this.script[this.index]?.resumeOnReject;
    if (snapshot) this.socket.emitPrivate(snapshot);
  }

  private buildView(): DriverView {
    return {
      step: this.script[this.index] ?? null,
      index: this.index,
      total: this.script.length,
      done: this.index >= this.script.length,
    };
  }

  private notify(): void {
    this.cachedView = this.buildView();
    this.listeners.forEach((fn) => fn());
  }
}
