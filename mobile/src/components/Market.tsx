import { ScrollView, StyleSheet, Text, View } from 'react-native';
import type { Slot } from '../online/messages';
import type { Market as MarketState } from '../online/onlineStore';
import { CardView, DeckCard, EmptyCard } from './CardView';
import { Button } from './ui';
import { colors, spacing } from '../theme';

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
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.rail}>
      {(['A', 'B', 'C'] as const).map((slot) => {
        const card = market[slot];
        const price = finalRound ? 0 : PRICE[slot];
        const affordable = yourCoins >= price;
        const enabled = canPick && !!card && affordable;
        return (
          <View key={slot} style={styles.slot}>
            <Text style={styles.label}>{price === 0 ? 'Free' : `${price} coin${price > 1 ? 's' : ''}`}</Text>
            {card ? <CardView card={card} size={88} /> : <EmptyCard label="empty" size={88} />}
            <Button
              label={!affordable && card ? 'Not enough coins' : 'Pick'}
              disabled={!enabled}
              onPress={() => onPick(slot)}
            />
          </View>
        );
      })}
      <View style={styles.slot}>
        <Text style={styles.label}>Deck · free</Text>
        <DeckCard remaining={deckRemaining} size={88} />
        <Button label="Draw" disabled={!canPick || deckRemaining <= 0} onPress={() => onPick('DECK')} />
      </View>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  rail: {
    gap: spacing.md,
    paddingVertical: spacing.sm,
  },
  slot: {
    alignItems: 'center',
    gap: spacing.sm,
    backgroundColor: colors.panel,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.sm,
  },
  label: {
    color: colors.gold,
    fontSize: 12,
    fontWeight: '600',
  },
});
