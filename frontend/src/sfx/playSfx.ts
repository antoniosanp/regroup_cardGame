// The playSfx(key) helper SOUNDS.md's implementation notes ask for. One-shots
// use a fresh Audio() per play - these are all <=3.5s, and a new element per
// call means overlapping plays of the same sound (two hit-impacts in one
// battle, several timer ticks) never cut each other off. The music loop is
// the opposite: exactly one persistent <audio loop> element, started/stopped
// rather than recreated.

import { MUSIC_LOBBY_URL, SFX_URLS, type SfxName } from './sfxAssets';
import { sfxStore } from './sfxStore';

interface PlaySfxOptions {
  /** Randomizes playbackRate by +/- this fraction (e.g. 0.1 = +/-10%) so repeated plays don't sound cloned. */
  pitchVariance?: number;
}

export function playSfx(name: SfxName, opts?: PlaySfxOptions): void {
  if (sfxStore.getState().muted) return;
  const url = SFX_URLS[name];
  if (!url) return;
  const audio = new Audio(url);
  if (opts?.pitchVariance) {
    audio.playbackRate = 1 + (Math.random() * 2 - 1) * opts.pitchVariance;
  }
  // Autoplay-policy rejections are expected in rare edge cases (a sound firing
  // before any user gesture has landed) - never let that surface as an
  // unhandled promise rejection.
  void audio.play().catch(() => {});
}

type MusicName = 'music-lobby';

const MUSIC_URLS: Record<MusicName, string> = {
  'music-lobby': MUSIC_LOBBY_URL,
};

let musicEl: HTMLAudioElement | null = null;
let musicName: MusicName | null = null;
let unsubscribeMute: (() => void) | null = null;

export function playMusic(name: MusicName): void {
  if (musicName === name && musicEl) return; // already playing this track
  stopMusic();
  const url = MUSIC_URLS[name];
  if (!url) return;
  const audio = new Audio(url);
  audio.loop = true;
  audio.muted = sfxStore.getState().muted;
  musicEl = audio;
  musicName = name;
  unsubscribeMute = sfxStore.subscribe((s) => {
    if (musicEl) musicEl.muted = s.muted;
  });
  void audio.play().catch(() => {});
}

export function stopMusic(): void {
  unsubscribeMute?.();
  unsubscribeMute = null;
  if (musicEl) {
    musicEl.pause();
    musicEl.currentTime = 0;
  }
  musicEl = null;
  musicName = null;
}
