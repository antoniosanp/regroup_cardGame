// Central import point for the sfx/ folder's audio assets, same spirit as
// online/assets.ts for images. There are 35 one-shots + one music loop, each
// shipped as a .ogg with a .mp3 fallback (see SOUNDS.md) - too many pairs to
// hand-write as individual imports, so import.meta.glob pulls in every file
// directly under this folder (it does not recurse into originals/, since a
// single `*` never crosses a path separator).

const SFX_NAMES = [
  'attacker-step',
  'attack-lunge',
  'battle-end',
  'battle-skip',
  'battle-start',
  'card-drag-start',
  'card-hover-cell',
  'card-pick',
  'card-place',
  'card-place-invalid',
  'card-rotate',
  'coin-spend',
  'deck-draw',
  'defeat',
  'eliminated',
  'heal',
  'hit-blocked',
  'hit-impact',
  'hit-impact-chicken',
  'hp-tick',
  'match-found',
  'pick-denied',
  'queue-join',
  'stat-down',
  'stat-up',
  'timer-expired',
  'timer-low-tick',
  'turn-yours',
  'ui-click',
  'ui-connect',
  'ui-error',
  'ui-modal-close',
  'ui-modal-open',
  'ui-reconnecting',
  'victory',
] as const;

export type SfxName = (typeof SFX_NAMES)[number];

const oggModules = import.meta.glob('./*.ogg', { eager: true }) as Record<string, { default: string }>;
const mp3Modules = import.meta.glob('./*.mp3', { eager: true }) as Record<string, { default: string }>;

function urlFor(name: string, modules: Record<string, { default: string }>): string | null {
  return modules[`./${name}`]?.default ?? null;
}

// Vorbis (.ogg) plays everywhere except Safari; canPlayType is the standard
// feature-detection for it, checked once at module load.
const supportsOgg =
  typeof document !== 'undefined' &&
  document.createElement('audio').canPlayType('audio/ogg; codecs="vorbis"') !== '';

function resolve(name: SfxName): string {
  const primary = urlFor(`${name}.${supportsOgg ? 'ogg' : 'mp3'}`, supportsOgg ? oggModules : mp3Modules);
  const fallback = urlFor(`${name}.${supportsOgg ? 'mp3' : 'ogg'}`, supportsOgg ? mp3Modules : oggModules);
  const url = primary ?? fallback;
  if (!url && import.meta.env.DEV) {
    console.error(`sfx: missing audio asset for "${name}"`);
  }
  return url ?? '';
}

export const SFX_URLS: Record<SfxName, string> = Object.fromEntries(
  SFX_NAMES.map((name) => [name, resolve(name)]),
) as Record<SfxName, string>;

export const MUSIC_LOBBY_URL = urlFor(`music-lobby.${supportsOgg ? 'ogg' : 'mp3'}`, supportsOgg ? oggModules : mp3Modules)
  ?? urlFor(`music-lobby.${supportsOgg ? 'mp3' : 'ogg'}`, supportsOgg ? mp3Modules : oggModules)
  ?? '';
