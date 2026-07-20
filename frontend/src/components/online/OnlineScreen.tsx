import { useEffect, useState } from 'react';
import { loadIdentity } from '../../online/api';
import { useOnlineStore } from '../../online/onlineStore';
import { playMusic, playSfx, stopMusic } from '../../sfx/playSfx';
import { useSfxStore } from '../../sfx/sfxStore';
import { Match } from './Match';

export function OnlineScreen() {
  const stage = useOnlineStore((s) => s.stage);
  const conn = useOnlineStore((s) => s.conn);
  const error = useOnlineStore((s) => s.error);
  const dismissError = useOnlineStore((s) => s.dismissError);
  const leave = useOnlineStore((s) => s.leave);
  const muted = useSfxStore((s) => s.muted);
  const toggleMute = useSfxStore((s) => s.toggleMute);

  // Lobby music plays on every pre-match stage and stops the instant a match
  // starts; it should not resume mid-match even if stage briefly toggles.
  useEffect(() => {
    if (stage === 'match') {
      stopMusic();
    } else {
      playMusic('music-lobby');
    }
  }, [stage]);

  return (
    <div className={`screen${stage === 'match' ? ' screen-match' : ''}`}>
      <button
        type="button"
        className="btn-ghost mute-toggle"
        aria-label={muted ? 'Unmute sound' : 'Mute sound'}
        onClick={toggleMute}
      >
        {muted ? '🔇' : '🔊'}
      </button>

      {stage !== 'match' && <h1 className="title">Regroup</h1>}

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
      {stage === 'lobby' && <Lobby />}
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
    <div className="panel screen-center" style={{ gap: '1rem' }}>
      <h2>Play online</h2>
      <p className="subtitle">Pick a name to enter matchmaking. 4 players per match.</p>
      <form
        className="row"
        style={{ width: '100%', maxWidth: 360 }}
        onSubmit={(e) => {
          e.preventDefault();
          playSfx('ui-click');
          void start(name);
        }}
      >
        <input
          type="text"
          value={name}
          maxLength={24}
          placeholder="Your name"
          onChange={(e) => setName(e.target.value)}
          disabled={connecting}
        />
        <button className="btn-primary" type="submit" disabled={connecting || !name.trim()}>
          {connecting ? 'Connecting…' : 'Connect'}
        </button>
      </form>
      {connecting && <span className="spinner" aria-label="Connecting" />}
    </div>
  );
}

function Lobby() {
  const name = useOnlineStore((s) => s.identity?.name);
  const joinQueue = useOnlineStore((s) => s.joinQueue);
  const playOffline = useOnlineStore((s) => s.playOffline);
  const leave = useOnlineStore((s) => s.leave);
  return (
    <div className="panel screen-center" style={{ gap: '1rem' }}>
      <h2>Connected as {name}</h2>
      <button
        className="btn-primary btn-big"
        onClick={() => {
          playSfx('queue-join');
          joinQueue();
        }}
      >
        Find a match
      </button>
      <button
        className="btn-primary btn-big"
        onClick={() => {
          playSfx('queue-join');
          playOffline();
        }}
      >
        Play offline vs bots
      </button>
      <button
        className="btn-ghost"
        onClick={() => {
          playSfx('ui-click');
          leave();
        }}
      >
        Sign out
      </button>
    </div>
  );
}

function QueueScreen() {
  const leaveQueue = useOnlineStore((s) => s.leaveQueue);
  return (
    <div className="panel screen-center" style={{ gap: '1rem' }}>
      <h2>Searching for players…</h2>
      <span className="spinner" aria-label="Searching" />
      <p className="subtitle">Waiting for 4 players to be matched.</p>
      <button
        onClick={() => {
          playSfx('ui-click');
          leaveQueue();
        }}
      >
        Leave queue
      </button>
    </div>
  );
}
