import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Every one-shot sound the game ships, matching the file names in the web
/// client's `sfx/` folder (see frontend/src/sfx/SOUNDS.md). Music is handled
/// separately (see [Sfx.playMusic]).
enum SfxName {
  attackerStep('attacker-step'),
  attackLunge('attack-lunge'),
  battleEnd('battle-end'),
  battleSkip('battle-skip'),
  battleStart('battle-start'),
  cardDragStart('card-drag-start'),
  cardHoverCell('card-hover-cell'),
  cardPick('card-pick'),
  cardPlace('card-place'),
  cardPlaceInvalid('card-place-invalid'),
  cardRotate('card-rotate'),
  coinSpend('coin-spend'),
  deckDraw('deck-draw'),
  defeat('defeat'),
  eliminated('eliminated'),
  heal('heal'),
  hitBlocked('hit-blocked'),
  hitImpact('hit-impact'),
  hitImpactChicken('hit-impact-chicken'),
  hpTick('hp-tick'),
  matchFound('match-found'),
  pickDenied('pick-denied'),
  queueJoin('queue-join'),
  statDown('stat-down'),
  statUp('stat-up'),
  timerExpired('timer-expired'),
  timerLowTick('timer-low-tick'),
  turnYours('turn-yours'),
  uiClick('ui-click'),
  uiConnect('ui-connect'),
  uiError('ui-error'),
  uiModalClose('ui-modal-close'),
  uiModalOpen('ui-modal-open'),
  uiReconnecting('ui-reconnecting'),
  victory('victory');

  final String file;
  const SfxName(this.file);
}

/// Volume tiers from SOUNDS.md: quiet UI ticks ≈ 0.3, gameplay ≈ 0.6,
/// stingers ≈ 0.9. Levels in the files are already pre-normalised to these
/// tiers, so these multipliers apply on top.
const double _tickVol = 0.35;
const double _gameVol = 0.6;
const double _stingVol = 0.9;
const double _musicVol = 0.4;

double _volumeFor(SfxName name) => switch (name) {
  SfxName.timerLowTick || SfxName.hpTick || SfxName.cardHoverCell => _tickVol,
  SfxName.matchFound ||
  SfxName.victory ||
  SfxName.defeat ||
  SfxName.eliminated ||
  SfxName.turnYours => _stingVol,
  _ => _gameVol,
};

const String _mutedPrefsKey = 'regroup.sfx.muted';

/// Sound service — a direct port of the web client's playSfx.ts + sfxStore.ts.
/// One-shots spin up a fresh [AudioPlayer] per play (mirroring the web's
/// `new Audio()` per call) so overlapping plays of the same sound never cut
/// each other off; the player disposes itself on completion. Music is a single
/// persistent looping player. Mute is persisted like the web's localStorage.
class Sfx {
  Sfx._();
  static final Sfx instance = Sfx._();

  final ValueNotifier<bool> muted = ValueNotifier(false);
  final _random = Random();
  AudioPlayer? _music;
  bool _musicPlaying = false;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      muted.value = prefs.getBool(_mutedPrefsKey) ?? false;
    } catch (_) {
      // Storage may be unavailable; mute still works for the session.
    }
  }

  Future<void> toggleMute() async {
    final next = !muted.value;
    muted.value = next;
    if (next) {
      await _music?.stop();
    } else if (_musicPlaying) {
      await _music?.resume();
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_mutedPrefsKey, next);
    } catch (_) {}
  }

  /// Plays a one-shot. [pitchVariance] randomizes playback rate by ± that
  /// fraction (e.g. 0.1 = ±10%), same as the web, so repeated plays (battle
  /// hits) don't sound cloned.
  void play(SfxName name, {double? pitchVariance}) {
    if (muted.value) return;
    final player = AudioPlayer();
    // Free native resources as soon as the sound finishes.
    player.onPlayerComplete.listen((_) => player.dispose());
    () async {
      try {
        await player.setReleaseMode(ReleaseMode.release);
        await player.play(
          AssetSource('sfx/${name.file}.mp3'),
          volume: _volumeFor(name),
        );
        if (pitchVariance != null) {
          final rate = 1 + (_random.nextDouble() * 2 - 1) * pitchVariance;
          await player.setPlaybackRate(rate);
        }
      } catch (_) {
        // Never let an audio failure surface — dispose and move on.
        await player.dispose();
      }
    }();
  }

  /// Starts the looping lobby music (idempotent). Muted state is respected.
  Future<void> playMusic() async {
    _musicPlaying = true;
    if (muted.value) return;
    if (_music != null) return;
    final player = AudioPlayer();
    _music = player;
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.play(AssetSource('sfx/music-lobby.mp3'), volume: _musicVol);
    } catch (_) {
      await player.dispose();
      _music = null;
    }
  }

  Future<void> stopMusic() async {
    _musicPlaying = false;
    final player = _music;
    _music = null;
    if (player != null) {
      try {
        await player.stop();
        await player.dispose();
      } catch (_) {}
    }
  }
}

/// Convenience top-level, mirroring the web's `playSfx(name)`.
void playSfx(SfxName name, {double? pitchVariance}) =>
    Sfx.instance.play(name, pitchVariance: pitchVariance);
