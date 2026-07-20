import type { Slot } from '../../online/messages';
import type { Market as MarketState } from '../../online/onlineStore';
import { BOARD_ART } from '../../online/assets';
import { playSfx } from '../../sfx/playSfx';
import { CardView, EmptyCard } from './CardView';

const PRICE: Record<'A' | 'B' | 'C', number> = { A: 0, B: 1, C: 2 };

interface MarketProps {
  market: MarketState;
  deckRemaining: number;
  canPick: boolean;
  yourCoins: number;
  finalRound: boolean;
  onPick: (slot: Slot) => void;
}

export function Market({ market, deckRemaining, canPick, yourCoins, finalRound, onPick }: MarketProps) {
  return (
    <div className="market" style={{ backgroundImage: `url(${BOARD_ART.marketFrame})` }}>
      <div className="market-slots">
        {(['A', 'B', 'C'] as const).map((slot) => {
          const card = market[slot];
          const price = finalRound ? 0 : PRICE[slot];
          const affordable = yourCoins >= price;
          const enabled = canPick && !!card && affordable;
          // Price lives in the button text (not a separate label row) so the
          // card + button stack always fits inside the frame's painted window.
          const priceText = price === 0 ? 'Free' : `${price} coin${price > 1 ? 's' : ''}`;
          return (
            <div key={slot} className="market-slot">
              {card ? <CardView card={card} /> : <EmptyCard label="empty" />}
              <button
                aria-disabled={!enabled}
                onClick={() => {
                  if (enabled) onPick(slot);
                  else playSfx('pick-denied');
                }}
              >
                {!affordable && card ? 'Not enough coins' : `Pick · ${priceText}`}
              </button>
            </div>
          );
        })}
        <div className="market-slot">
          <div className="card card-back" style={{ backgroundImage: `url(${BOARD_ART.cardBack})` }}>
            {deckRemaining}
          </div>
          <button
            aria-disabled={!canPick || deckRemaining <= 0}
            onClick={() => {
              if (canPick && deckRemaining > 0) onPick('DECK');
              else playSfx('pick-denied');
            }}
          >
            Draw · Free
          </button>
        </div>
      </div>
    </div>
  );
}
