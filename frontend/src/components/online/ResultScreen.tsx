import { useEffect } from 'react';
import type { PlayerState } from '../../online/messages';
import { avatarFor } from '../../online/assets';
import { playSfx } from '../../sfx/playSfx';

interface ResultScreenProps {
  players: PlayerState[];
  winners: string[] | null;
  reason: string | null;
  youWon: boolean;
  onExit: () => void;
}

const REASON_TEXT: Record<string, string> = {
  LAST_STANDING: 'Last player standing',
  DECK_EXHAUSTED: 'Deck exhausted — highest HP wins',
};

export function ResultScreen({ players, winners, reason, youWon, onExit }: ResultScreenProps) {
  // Mounts exactly once per match (Match.tsx only renders this once phase
  // flips to MATCH_OVER), so an empty-deps effect fires the sound exactly once.
  useEffect(() => {
    playSfx(youWon ? 'victory' : 'defeat');
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const standings = [...players].sort((a, b) => b.stats.hp - a.stats.hp);
  const winnerSet = new Set(winners ?? []);
  const winningPlayers = players.filter((p) => winnerSet.has(p.playerId));

  return (
    <div className="panel screen-center" style={{ gap: '1rem' }}>
      <h2>Match over</h2>
      {winningPlayers.length > 0 ? (
        <>
          <div className="result-winners-row">
            {winningPlayers.map((p) => (
              <img key={p.playerId} className="result-winner-avatar" src={avatarFor(p.seat)} alt={p.name} />
            ))}
          </div>
          <p className="result-winner">
            {winningPlayers.length > 1 ? 'Winners' : 'Winner'}: {winningPlayers.map((p) => p.name).join(', ')}
          </p>
        </>
      ) : (
        <p className="hint">Awaiting final result…</p>
      )}
      {reason && <p className="subtitle">{REASON_TEXT[reason] ?? reason}</p>}

      <table className="battle-table">
        <thead>
          <tr>
            <th></th>
            <th>Player</th>
            <th>HP</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          {standings.map((p) => (
            <tr key={p.playerId} className={winnerSet.has(p.playerId) ? 'result-row-winner' : ''}>
              <td>
                <img className="result-row-avatar" src={avatarFor(p.seat)} alt="" />
              </td>
              <td>{p.name}</td>
              <td>{p.stats.hp}</td>
              <td>{p.alive ? 'alive' : 'eliminated'}</td>
            </tr>
          ))}
        </tbody>
      </table>

      <button
        className="btn-primary"
        onClick={() => {
          playSfx('ui-click');
          onExit();
        }}
      >
        Back to lobby
      </button>
    </div>
  );
}
