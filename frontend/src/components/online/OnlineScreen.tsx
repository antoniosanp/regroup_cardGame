import { useEffect, useState } from 'react';
import { loadIdentity } from '../../online/api';
import { MENU_ART } from '../../online/assets';
import { useOnlineStore } from '../../online/onlineStore';
import { playMusic, playSfx, stopMusic } from '../../sfx/playSfx';
import { useSfxStore } from '../../sfx/sfxStore';
import { HowToPlayMenu } from '../../tutorial/HowToPlayMenu';
import { RulesPage } from '../../tutorial/RulesPage';
import { TutorialScreen } from '../../tutorial/TutorialScreen';
import { Match } from './Match';
import { MenuButton, MenuPanel } from './MenuShell';

/** Which How-to-Play view is open over the lobby, if any. */
type HowTo = 'none' | 'menu' | 'rules' | 'tutorial';

export function OnlineScreen() {
  const stage = useOnlineStore((s) => s.stage);
  const conn = useOnlineStore((s) => s.conn);
  const error = useOnlineStore((s) => s.error);
  const dismissError = useOnlineStore((s) => s.dismissError);
  const leave = useOnlineStore((s) => s.leave);
  const muted = useSfxStore((s) => s.muted);
  const toggleMute = useSfxStore((s) => s.toggleMute);

  // Local rather than a new Stage: every Stage value is tied to the connection/match
  // lifecycle and would be reset by an incoming server message.
  const [howTo, setHowTo] = useState<HowTo>('none');

  // The tutorial renders the full match UI, so it wants the same chrome a real match
  // gets: no lobby music, no page title, and the match layout class.
  const matchLike = stage === 'match' || howTo === 'tutorial';

  // Lobby music plays on every pre-match stage and stops the instant a match
  // starts; it should not resume mid-match even if stage briefly toggles.
  useEffect(() => {
    if (matchLike) {
      stopMusic();
    } else {
      playMusic('music-lobby');
    }
  }, [matchLike]);

  return (
    <div className={`screen${matchLike ? ' screen-match' : ''}`}>
      <button
        type="button"
        className="btn-ghost mute-toggle"
        aria-label={muted ? 'Unmute sound' : 'Mute sound'}
        onClick={toggleMute}
      >
        {muted ? '🔇' : '🔊'}
      </button>

      {/* No <h1> title: the menu panel's background art has the logo painted into it,
          and every non-match screen now renders inside that panel. */}

      {conn === 'reconnecting' && (
        <div className="banner banner-warn" role="status">
          <span className="spinner" /> Connection lost — reconnecting…
        </div>
      )}
      {error && (
        <div className="banner banner-error" role="alert">
          <span>{error.message || error.code}</span>
          <button
            onClick={() => {
              playSfx('ui-click');
              dismissError();
            }}
          >
            Dismiss
          </button>
        </div>
      )}

      {stage === 'name' && <NameEntry />}
      {stage === 'lobby' && howTo === 'none' && <Lobby onOpenHowTo={() => setHowTo('menu')} />}
      {stage === 'lobby' && howTo === 'menu' && (
        <HowToPlayMenu
          onRules={() => setHowTo('rules')}
          onTutorial={() => setHowTo('tutorial')}
          onBack={() => setHowTo('none')}
        />
      )}
      {stage === 'lobby' && howTo === 'rules' && <RulesPage onExit={() => setHowTo('menu')} />}
      {stage === 'lobby' && howTo === 'tutorial' && (
        <TutorialScreen onExit={() => setHowTo('menu')} />
      )}
      {stage === 'queue' && <QueueScreen />}
      {stage === 'match' && <Match onExit={() => leave()} />}
    </div>
  );
}

function NameEntry() {
  const [name, setName] = useState(() => loadIdentity()?.name ?? '');
  const conn = useOnlineStore((s) => s.conn);
  const start = useOnlineStore((s) => s.start);
  const connecting = conn === 'connecting';

  return (
    <MenuPanel>
      <form
        style={{ display: 'contents' }}
        onSubmit={(e) => {
          e.preventDefault();
          playSfx('ui-click');
          void start(name);
        }}
      >
        <div className="menu-field" style={{ backgroundImage: `url(${MENU_ART.fieldBlank})` }}>
          <input
            type="text"
            value={name}
            maxLength={24}
            placeholder="Your name"
            aria-label="Your name"
            onChange={(e) => setName(e.target.value)}
            disabled={connecting}
          />
        </div>
        <MenuButton
          type="submit"
          icon={MENU_ART.plankHelm}
          label={connecting ? 'Connecting…' : 'Enter'}
          disabled={connecting || !name.trim()}
        />
      </form>
      <p className="menu-note">4 players per match</p>
    </MenuPanel>
  );
}

function Lobby({ onOpenHowTo }: { onOpenHowTo: () => void }) {
  const name = useOnlineStore((s) => s.identity?.name);
  const joinQueue = useOnlineStore((s) => s.joinQueue);
  const playOffline = useOnlineStore((s) => s.playOffline);
  const leave = useOnlineStore((s) => s.leave);
  return (
    <MenuPanel>
      <MenuButton
        icon={MENU_ART.plankHelm}
        label="Find a match"
        onClick={() => {
          playSfx('queue-join');
          joinQueue();
        }}
      />
      <MenuButton
        icon={MENU_ART.plankSwords}
        label="Play vs bots"
        onClick={() => {
          playSfx('queue-join');
          playOffline();
        }}
      />
      <MenuButton
        icon={MENU_ART.plankBanner}
        label="How to play"
        onClick={() => {
          playSfx('ui-modal-open');
          onOpenHowTo();
        }}
      />
      <MenuButton
        icon={MENU_ART.plankDoor}
        label="Sign out"
        onClick={() => {
          playSfx('ui-click');
          leave();
        }}
      />
      <p className="menu-note">Signed in as {name}</p>
    </MenuPanel>
  );
}

function QueueScreen() {
  const leaveQueue = useOnlineStore((s) => s.leaveQueue);
  return (
    <MenuPanel>
      <p className="menu-note menu-spinner-row">
        <span className="spinner" aria-label="Searching" /> Searching for players…
      </p>
      <MenuButton
        icon={MENU_ART.plankDoor}
        label="Leave queue"
        onClick={() => {
          playSfx('ui-click');
          leaveQueue();
        }}
      />
      <p className="menu-note">Waiting for 4 players</p>
    </MenuPanel>
  );
}
