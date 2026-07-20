import { Image, StyleSheet, Text, View } from 'react-native';
import { cornerMeta, type Card, type CornerAttribute, type Rotation } from '../online/cards';
import { colors } from '../theme';

// A card's corner fields are always the current arrangement (the store keeps
// them in sync with the server), so rotation here only spins the artwork
// painted on each corner — it never moves attributes between corners.
const ROTATION_DEG: Record<Rotation, string> = {
  DEG_0: '0deg',
  DEG_90: '90deg',
  DEG_180: '180deg',
  DEG_270: '270deg',
};

function CornerCell({
  attr,
  rotationDeg,
  size,
}: {
  attr: CornerAttribute;
  rotationDeg: string;
  size: number;
}) {
  const meta = cornerMeta(attr);
  return (
    <Image
      source={meta.icon}
      accessibilityLabel={meta.label}
      style={{ width: size, height: size, transform: [{ rotate: rotationDeg }] }}
      resizeMode="contain"
    />
  );
}

/** A card rendered as four corner attribute icons in a 2x2 grid. */
export function CardView({ card, size = 96 }: { card: Card; size?: number }) {
  const rotationDeg = ROTATION_DEG[card.rotation] ?? '0deg';
  const cell = size / 2;
  return (
    <View style={[styles.card, { width: size, height: size }]}>
      <View style={styles.row}>
        <CornerCell attr={card.topLeft} rotationDeg={rotationDeg} size={cell} />
        <CornerCell attr={card.topRight} rotationDeg={rotationDeg} size={cell} />
      </View>
      <View style={styles.row}>
        <CornerCell attr={card.bottomLeft} rotationDeg={rotationDeg} size={cell} />
        <CornerCell attr={card.bottomRight} rotationDeg={rotationDeg} size={cell} />
      </View>
    </View>
  );
}

export function EmptyCard({ label, size = 96 }: { label: string; size?: number }) {
  return (
    <View style={[styles.card, styles.cardEmpty, { width: size, height: size }]}>
      <Text style={styles.emptyText}>{label}</Text>
    </View>
  );
}

/** The face-down deck top, showing how many cards remain. */
export function DeckCard({ remaining, size = 96 }: { remaining: number; size?: number }) {
  return (
    <View style={[styles.card, styles.cardBack, { width: size, height: size }]}>
      <Text style={styles.backText}>{remaining}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
    backgroundColor: colors.panelSoft,
    overflow: 'hidden',
  },
  row: {
    flexDirection: 'row',
  },
  cardEmpty: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.panel,
  },
  emptyText: {
    color: colors.textDim,
    fontSize: 12,
  },
  cardBack: {
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: '#243252',
    borderColor: colors.primaryDark,
  },
  backText: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '700',
  },
});
