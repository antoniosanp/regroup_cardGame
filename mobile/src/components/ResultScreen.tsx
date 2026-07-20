import { StyleSheet, Text, View } from 'react-native';
import type { PlayerState } from '../online/messages';
import { colors, spacing } from '../theme';
import { Button, Panel } from './ui';

interface ResultScreenProps {
  players: PlayerState[];
  winners: string[] | null;
  reason: string | null;
  onExit: () => void;
}

const REASON_TEXT: Record<string, string> = {
  LAST_STANDING: 'Last player standing',
  DECK_EXHAUSTED: 'Deck exhausted — highest HP wins',
};

export function ResultScreen({ players, winners, reason, onExit }: ResultScreenProps) {
  const standings = [...players].sort((a, b) => b.stats.hp - a.stats.hp);
  const winnerSet = new Set(winners ?? []);
  const winnerNames = players.filter((p) => winnerSet.has(p.playerId)).map((p) => p.name);

  return (
    <View style={styles.center}>
      <Panel style={styles.panel}>
        <Text style={styles.title}>Match over</Text>
        {winners && winners.length > 0 ? (
          <Text style={styles.winner}>
            {winnerNames.length > 1 ? 'Winners' : 'Winner'}: {winnerNames.join(', ')}
          </Text>
        ) : (
          <Text style={styles.hint}>Awaiting final result…</Text>
        )}
        {reason && <Text style={styles.subtitle}>{REASON_TEXT[reason] ?? reason}</Text>}

        <View style={styles.table}>
          {standings.map((p) => (
            <View key={p.playerId} style={[styles.row, winnerSet.has(p.playerId) && styles.rowWinner]}>
              <Text style={[styles.cell, styles.cellName]} numberOfLines={1}>
                {p.name}
              </Text>
              <Text style={styles.cell}>{p.stats.hp} hp</Text>
              <Text style={[styles.cell, !p.alive && { color: colors.danger }]}>
                {p.alive ? 'alive' : 'eliminated'}
              </Text>
            </View>
          ))}
        </View>

        <Button label="Back to lobby" kind="primary" onPress={onExit} />
      </Panel>
    </View>
  );
}

const styles = StyleSheet.create({
  center: {
    flex: 1,
    justifyContent: 'center',
    padding: spacing.lg,
  },
  panel: {
    gap: spacing.md,
  },
  title: {
    color: colors.text,
    fontSize: 22,
    fontWeight: '800',
    textAlign: 'center',
  },
  winner: {
    color: colors.gold,
    fontSize: 17,
    fontWeight: '700',
    textAlign: 'center',
  },
  subtitle: {
    color: colors.textDim,
    textAlign: 'center',
  },
  hint: {
    color: colors.textDim,
    textAlign: 'center',
  },
  table: {
    gap: spacing.xs,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: colors.panelSoft,
    borderRadius: 8,
    padding: spacing.sm,
    gap: spacing.md,
  },
  rowWinner: {
    borderWidth: 1,
    borderColor: colors.gold,
  },
  cell: {
    color: colors.text,
  },
  cellName: {
    flex: 1,
    fontWeight: '700',
  },
});
