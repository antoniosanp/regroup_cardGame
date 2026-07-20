// Opens from the top-right "Opponent board" button. Lets you flip between
// every opponent's board plus a reskinned (icon-based) stat row and their
// turn/eliminated/offline flags — this absorbs what the old StatsPanel's
// PlayersPanel/StatsRow showed inline on the match screen at all times.

import { useState } from 'react';
import type { BoardPoint } from '../../online/cards';
import { avatarFor, STAT_ICON, type StatKey } from '../../online/assets';
import type { PlayerState, Stats } from '../../online/messages';
import { playSfx } from '../../sfx/playSfx';
import { BoardView } from './BoardView';

interface OpponentsModalProps {
  open: boolean;
  onClose: () => void;
  players: PlayerState[];
  self: string;
  boards: Record<string, BoardPoint[]>;
  connected: Record<string, boolean>;
  currentSeat: number;
  heldBy: string | null;
}

const STAT_KEYS: StatKey[] = ['hp', 'pa', 'pd', 'ma', 'md', 'cn', 'hpp'];

function OpponentStatRow({ stats }: { stats: Stats }) {
  return (
    <div className="stats-row-icons">
      {STAT_KEYS.map((k) => (
        <span key={k} className="stat-icon" title={k}>
          <img src={STAT_ICON[k]} alt={k} />
          <span>{stats[k]}</span>
        </span>
      ))}
    </div>
  );
}

export function OpponentsModal({
  open,
  onClose,
  players,
  self,
  boards,
  connected,
  currentSeat,
  heldBy,
}: OpponentsModalProps) {
  const [selectedId, setSelectedId] = useState<string | null>(null);

  if (!open) return null;

  const handleClose = () => {
    playSfx('ui-modal-close');
    onClose();
  };

  const opponents = [...players].filter((p) => p.playerId !== self).sort((a, b) => a.seat - b.seat);
  const selected =
    selectedId && opponents.some((p) => p.playerId === selectedId) ? selectedId : (opponents[0]?.playerId ?? null);
  const selectedPlayer = opponents.find((p) => p.playerId === selected) ?? null;

  return (
    <div className="modal-backdrop" onClick={handleClose}>
      <div className="modal-panel modal-panel-opponents" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h3>Opponent boards</h3>
          <button className="btn-ghost" onClick={handleClose}>
            Close
          </button>
        </div>

        {opponents.length === 0 ? (
          <p className="hint">No opponents yet.</p>
        ) : (
          <>
            <div className="opponent-tabs">
              {opponents.map((p) => {
                const isConnected = connected[p.playerId] !== false;
                return (
                  <button
                    key={p.playerId}
                    type="button"
                    className={`opponent-tab${p.playerId === selected ? ' opponent-tab-active' : ''}${
                      p.alive ? '' : ' opponent-tab-dead'
                    }`}
                    onClick={() => {
                      playSfx('ui-click');
                      setSelectedId(p.playerId);
                    }}
                  >
                    <img className="opponent-tab-avatar" src={avatarFor(p.seat)} alt={p.name} />
                    <span className="opponent-tab-name">{p.name}</span>
                    <span className="opponent-tab-flags">
                      {p.seat === currentSeat && p.alive && <span className="flag flag-turn">turn</span>}
                      {heldBy === p.playerId && <span className="flag flag-hold">holding</span>}
                      {!p.alive && <span className="flag flag-out">out</span>}
                      {!isConnected && <span className="flag flag-off">offline</span>}
                    </span>
                  </button>
                );
              })}
            </div>

            {selectedPlayer && (
              <div className="opponent-detail">
                <OpponentStatRow stats={selectedPlayer.stats} />
                <BoardView points={boards[selectedPlayer.playerId] ?? []} />
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
