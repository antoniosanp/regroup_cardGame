import { ScrollView, StyleSheet, Text, View } from 'react-native';
import type { PlayerState } from '../online/messages';
import { colors, spacing } from '../theme';

const STAT_KEYS = ['hp', 'pa', 'pd', 'ma', 'md', 'cn', 'hpp'] as const;

export function StatsRow({ stats }: { stats: PlayerState['stats'] }) {
  return (
    <View style={styles.statsRow}>
      {STAT_KEYS.map((k) => (
        <View key={k} style={styles.stat}>
          <Text style={styles.statKey}>{k}</Text>
          <Text style={styles.statVal}>{stats[k]}</Text>
        </View>
      ))}
    </View>
  );
}

interface PlayersPanelProps {
  players: PlayerState[];
  connected: Record<string, boolean>;
  currentSeat: number;
  yourSeat: number;
  heldBy: string | null;
}

export function PlayersPanel({ players, connected, currentSeat, yourSeat, heldBy }: PlayersPanelProps) {
  const ordered = [...players].sort((a, b) => a.seat - b.seat);
  return (
    <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.rail}>
      {ordered.map((p) => {
        const isCurrent = p.seat === currentSeat;
        const isYou = p.seat === yourSeat;
        const isConnected = connected[p.playerId] !== false;
        return (
          <View
            key={p.playerId}
            style={[styles.tag, isCurrent && styles.tagCurrent, !p.alive && styles.tagDead]}
          >
            <View style={styles.head}>
              <Text style={styles.name} numberOfLines={1}>
                {p.name}
                {isYou ? ' (you)' : ''}
              </Text>
              <View style={styles.flags}>
                {isCurrent && p.alive && <Flag text="turn" color={colors.primary} />}
                {heldBy === p.playerId && <Flag text="holding" color={colors.gold} />}
                {!p.alive && <Flag text="out" color={colors.danger} />}
                {!isConnected && <Flag text="offline" color={colors.textDim} />}
              </View>
            </View>
            <StatsRow stats={p.stats} />
          </View>
        );
      })}
    </ScrollView>
  );
}

function Flag({ text, color }: { text: string; color: string }) {
  return (
    <View style={[styles.flag, { borderColor: color }]}>
      <Text style={[styles.flagText, { color }]}>{text}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  rail: {
    gap: spacing.sm,
    paddingVertical: spacing.sm,
  },
  tag: {
    backgroundColor: colors.panel,
    borderColor: colors.border,
    borderWidth: 1,
    borderRadius: 10,
    padding: spacing.sm,
    minWidth: 190,
  },
  tagCurrent: {
    borderColor: colors.primary,
  },
  tagDead: {
    opacity: 0.5,
  },
  head: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    gap: spacing.sm,
    marginBottom: spacing.xs,
  },
  name: {
    color: colors.text,
    fontWeight: '700',
    flexShrink: 1,
  },
  flags: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  flag: {
    borderWidth: 1,
    borderRadius: 4,
    paddingHorizontal: 4,
    paddingVertical: 1,
  },
  flagText: {
    fontSize: 10,
    fontWeight: '700',
  },
  statsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    flexWrap: 'wrap',
  },
  stat: {
    alignItems: 'center',
  },
  statKey: {
    color: colors.textDim,
    fontSize: 10,
    textTransform: 'uppercase',
  },
  statVal: {
    color: colors.text,
    fontWeight: '700',
  },
});
