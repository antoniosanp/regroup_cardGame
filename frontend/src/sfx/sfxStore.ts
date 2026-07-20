// Audio preferences (currently just mute). Deliberately separate from
// online/onlineStore.ts, whose own header comment scopes it to mirroring
// WS_CONTRACT.md server state - this is local UI preference, not game state.

import { createStore, useStore } from 'zustand';

const STORAGE_KEY = 'regroup.sfx.muted';

function loadMuted(): boolean {
  try {
    return localStorage.getItem(STORAGE_KEY) === '1';
  } catch {
    return false;
  }
}

function saveMuted(muted: boolean): void {
  try {
    localStorage.setItem(STORAGE_KEY, muted ? '1' : '0');
  } catch {
    // Storage can be unavailable (private browsing, disabled cookies); muting
    // still works for the session, it just won't persist. Not worth surfacing.
  }
}

interface SfxState {
  muted: boolean;
  toggleMute: () => void;
}

export const sfxStore = createStore<SfxState>((set, get) => ({
  muted: loadMuted(),
  toggleMute: () => {
    const muted = !get().muted;
    saveMuted(muted);
    set({ muted });
  },
}));

export function useSfxStore<T>(selector: (s: SfxState) => T): T {
  return useStore(sfxStore, selector);
}
