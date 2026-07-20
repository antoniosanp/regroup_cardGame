import type { BattleVM } from '../../online/onlineStore';

export function BattlePanel({
  battle,
  nameOf,
}: {
  battle: BattleVM;
  nameOf: (playerId: string) => string;
}) {
  return (
    <div className="battle-panel">
      <h3>Battle — round {battle.round}</h3>
      {battle.attacks.length === 0 ? (
        <p className="hint">No damage this round.</p>
      ) : (
        <table className="battle-table">
          <thead>
            <tr>
              <th>Attacker</th>
              <th>Defender</th>
              <th>Phys</th>
              <th>Magic</th>
              <th>Total</th>
            </tr>
          </thead>
          <tbody>
            {battle.attacks.map((a, i) => (
              <tr key={i}>
                <td>{nameOf(a.attackerId)}</td>
                <td>{nameOf(a.defenderId)}</td>
                <td>{a.physicalDamage}</td>
                <td>{a.magicDamage}</td>
                <td>{a.totalDamage}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
      <table className="battle-table">
        <thead>
          <tr>
            <th>Player</th>
            <th>HP before</th>
            <th>Damage taken</th>
            <th>Healed</th>
            <th>HP after</th>
            <th></th>
          </tr>
        </thead>
        <tbody>
          {battle.outcomes.map((o) => (
            <tr key={o.playerId} className={o.eliminated ? 'battle-kill' : ''}>
              <td>{nameOf(o.playerId)}</td>
              <td>{o.hpBefore}</td>
              <td>{o.damageTaken}</td>
              <td>{o.healedHp}</td>
              <td>{o.hpAfter}</td>
              <td>{o.eliminated ? 'eliminated' : ''}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
