// The rulebook, laid out after RCA_Rulebook_EN_v03.pdf's visual language — parchment field,
// carved banner headings, an icon legend — but with content taken from backend/gameRules.md,
// which is the digital game's source of truth. (The printed rulebook describes the physical
// edition: leader cards, life counters, 43 cards. Style from there, rules from here.)

import { BOARD_ART } from '../online/assets';
import { CORNER_META, type CornerAttribute } from '../online/cards';

function Banner({ children }: { children: string }) {
  return (
    <h3 className="rules-banner" style={{ backgroundImage: `url(${BOARD_ART.panelWide})` }}>
      {children}
    </h3>
  );
}

// Mirrors the printed rulebook's "Icon Description" panel, but drawn with the real corner
// art the board uses, so what you learn here is exactly what you'll see on a card.
const LEGEND: CornerAttribute[] = [
  'PA_1',
  'PA_2',
  'PD_1',
  'PD_2',
  'MA_1',
  'MA_2',
  'MD_1',
  'MD_2',
  'COINS_2',
  'HP_POTION_COIN',
  'EMPTY',
];

const STATS: Array<{ name: string; abbr: string; start: string }> = [
  { name: 'Health Points', abbr: 'hp', start: '30 (max 30)' },
  { name: 'Physical Attack', abbr: 'pa', start: '0' },
  { name: 'Physical Defense', abbr: 'pd', start: '0' },
  { name: 'Magic Attack', abbr: 'ma', start: '0' },
  { name: 'Magic Defense', abbr: 'md', start: '0' },
  { name: 'Coins', abbr: 'cn', start: '0' },
  { name: 'Health Potions', abbr: 'hpp', start: '0' },
];

export function RulesPage({ onExit }: { onExit: () => void }) {
  return (
    <div className="rules-page" style={{ backgroundImage: `url(${BOARD_ART.boardBackground})` }}>
      <div className="rules-scroll">
        <header className="rules-head">
          <h2 className="rules-title">Regroup</h2>
          <p className="rules-sub">Chicken Army — rules of play</p>
        </header>

        <Banner>Goal</Banner>
        <p>
          Be the last player standing, or hold the most health when the deck runs dry. Four
          players build a personal army of cards side by side, turning raw corners into attack
          and defense, then batter each other every round until one is left.
        </p>

        <Banner>Your Stats</Banner>
        <table className="rules-table">
          <thead>
            <tr>
              <th>Stat</th>
              <th>Short</th>
              <th>Starts at</th>
            </tr>
          </thead>
          <tbody>
            {STATS.map((s) => (
              <tr key={s.abbr}>
                <td>{s.name}</td>
                <td>{s.abbr}</td>
                <td>{s.start}</td>
              </tr>
            ))}
          </tbody>
        </table>

        <Banner>Cards</Banner>
        <p>
          Every card is a square with four corners, and each corner carries one property — an
          attack or defense value, coins, a potion, or nothing at all.
        </p>
        <p className="rules-note">
          A stat category may appear on at most two corners of the same card, and when it does,
          those corners are always <strong>diagonally opposite</strong> — never side by side. A
          diagonal pair can never match itself once placed, so you still have to earn it on the
          board.
        </p>

        <Banner>Turn Order</Banner>
        <p>
          Players take turns in a loop, and the player who moves first rotates each round so
          everyone gets the opening move. On your turn you do three things:
        </p>
        <ol className="rules-list">
          <li>
            <strong>Pick a card.</strong> Three cards sit face up. The one furthest from the deck
            is free, the middle costs 1 coin, and the one closest to the deck costs 2. Drawing
            the top card of the deck is also free. After a pick the remaining cards shift down
            and a new one is drawn, so prices always run free / 1 / 2.
          </li>
          <li>
            <strong>Rotate it.</strong> Turn the card 90° as many times as you like to line its
            corners up the way you need them.
          </li>
          <li>
            <strong>Place it.</strong> The new card must overlap at least one corner already on
            your board, covering what was there. Your very first card is the exception — it
            starts an empty board.
          </li>
        </ol>

        <Banner>Making Stats Count</Banner>
        <p className="rules-note">
          This is the heart of the game. A corner only counts if it touches a matching corner{' '}
          <strong>up, down, left or right</strong> — diagonals never count.
        </p>
        <p>
          Put a 1 physical attack corner next to a 2 physical attack corner and you have 3
          physical attack. Leave a 2 magic defense corner surrounded by attack and coin corners
          and it is worth nothing at all. Coins and potions are the exception: they always count,
          wherever they sit.
        </p>

        <Banner>Battle</Banner>
        <p>
          Once every player has placed a card, stats are recalculated and everyone attacks
          everyone at once:
        </p>
        <ul className="rules-list">
          <li>Physical damage = attacker's pa − defender's pd</li>
          <li>Magic damage = attacker's ma − defender's md</li>
          <li>Negative results count as zero — defense never heals the attacker.</li>
        </ul>
        <p>
          Survivors then recover health equal to their potions. A player knocked below 1 health
          is out, but still lands their own attack that round — so two players can finish each
          other in the same battle. When that happens the one ending on the higher health wins
          the exchange.
        </p>

        <Banner>Final Round &amp; End of Game</Banner>
        <p>
          When the market and deck together hold fewer than 7 cards at the start of a round, that
          round is the <strong>final round</strong>: every market slot is free. Once it resolves,
          the game ends and the highest health wins, with ties sharing the victory. The game also
          ends the moment only one player is left standing.
        </p>

        <Banner>Icon Description</Banner>
        <div className="rules-legend">
          {LEGEND.map((attr) => (
            <div key={attr} className="rules-legend-item">
              <img src={CORNER_META[attr].icon} alt="" />
              <span>{CORNER_META[attr].label}</span>
            </div>
          ))}
        </div>

        <div className="rules-footer">
          <button className="btn-primary btn-big" onClick={onExit}>
            Back
          </button>
        </div>
      </div>
    </div>
  );
}
