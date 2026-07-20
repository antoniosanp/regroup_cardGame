// Bottom-left HUD: the local player's portrait + hp/potion/coin badges, plus
// the adjacent 2x2 PA/MA/PD/MD stat grid, per layoutGuide.txt sections 4-5.

import { avatarFor, BOARD_ART } from '../../online/assets';
import type { Stats } from '../../online/messages';
import { AnimatedNumber } from './AnimatedNumber';

interface PlayerHudProps {
  seat: number;
  name: string;
  stats: Stats;
}

const STAT_TILES: Array<{ key: 'pa' | 'ma' | 'pd' | 'md'; icon: string; label: string }> = [
  { key: 'pa', icon: BOARD_ART.pa, label: 'Physical attack' },
  { key: 'ma', icon: BOARD_ART.ma, label: 'Magic attack' },
  { key: 'pd', icon: BOARD_ART.pd, label: 'Physical defense' },
  { key: 'md', icon: BOARD_ART.md, label: 'Magic defense' },
];

export function PlayerHud({ seat, name, stats }: PlayerHudProps) {
  return (
    <div className="player-hud">
      <div className="player-hud-portrait">
        <img className="player-hud-avatar" src={avatarFor(seat)} alt={name} />
        <div className="player-hud-badge player-hud-badge-hp" title="Health">
          <img src={BOARD_ART.hp} alt="" />
          <AnimatedNumber value={stats.hp} />
        </div>
        <div className="player-hud-badge player-hud-badge-potion" title="Healing potions">
          <img src={BOARD_ART.pot} alt="" />
          <AnimatedNumber value={stats.hpp} />
        </div>
        <div className="player-hud-badge player-hud-badge-coin" title="Coins">
          <img src={BOARD_ART.coin} alt="" />
          <AnimatedNumber value={stats.cn} />
        </div>
        <div className="player-hud-name">{name}</div>
      </div>

      <div className="stat-grid">
        {STAT_TILES.map((t) => (
          <div key={t.key} className="stat-tile" title={t.label}>
            <img className="stat-tile-icon" src={t.icon} alt="" />
            <AnimatedNumber className="stat-tile-value" value={stats[t.key]} />
          </div>
        ))}
      </div>
    </div>
  );
}
