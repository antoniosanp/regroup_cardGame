import { useEffect, useState } from 'react';
import { Modal, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { cardToPoints, type CornerName } from '../online/cards';
import { useOnlineStore } from '../online/onlineStore';
import { colors, spacing } from '../theme';
import { BattleStage } from './BattleStage';
import { BoardView } from './BoardView';
import { CardView } from './CardView';
import { Market } from './Market';
import { ResultScreen } from './ResultScreen';
import { PlayersPanel } from './StatsPanel';
import { Button } from './ui';

const CORNER_OPTIONS: Array<{ corner: CornerName; label: string }> = [
  { corner: 'TOP_LEFT', label: 'TL' },
  { corner: 'TOP_RIGHT', label: 'TR' },
  { corner: 'BOTTOM_LEFT', label: 'BL' },
  { corner: 'BOTTOM_RIGHT', label: 'BR' },
];

export function Match({ onExit }: { onExit: () => void }) {
  const self = useOnlineStore((s) => s.identity?.playerId ?? '');
  const players = useOnlineStore((s) => s.players);
  const connected = useOnlineStore((s) => s.connected);
  const phase = useOnlineStore((s) => s.phase);
  const round = useOnlineStore((s) => s.round);
  const currentSeat = useOnlineStore((s) => s.currentSeat);
  const finalRound = useOnlineStore((s) => s.finalRound);
  const yourSeat = useOnlineStore((s) => s.yourSeat);
  const boards = useOnlineStore((s) => s.boards);
  const market = useOnlineStore((s) => s.market);
  const deckRemaining = useOnlineStore((s) => s.deckRemaining);
  const heldCard = useOnlineStore((s) => s.heldCard);
  const heldBy = useOnlineStore((s) => s.heldBy);
  const busy = useOnlineStore((s) => s.busy);
  const lastBattle = useOnlineStore((s) => s.lastBattle);
  const winners = useOnlineStore((s) => s.winners);
  const reason = useOnlineStore((s) => s.reason);
  const pick = useOnlineStore((s) => s.pick);
  const rotate = useOnlineStore((s) => s.rotate);
  const place = useOnlineStore((s) => s.place);

  // Tap-to-place (the mobile stand-in for the web client's drag-and-drop):
  // choose which corner of the held card anchors, tap a board point, preview,
  // then confirm.
  const [anchorCorner, setAnchorCorner] = useState<CornerName>('TOP_LEFT');
  const [targetPoint, setTargetPoint] = useState<{ x: number; y: number } | null>(null);
  // Opponent boards are shown as small thumbnails; tapping one zooms it into a modal.
  const [zoomedOpponent, setZoomedOpponent] = useState<string | null>(null);

  const iHoldCard = heldBy === self && heldCard !== null;

  // Any change of held card (placed, new turn, rotation keeps it) drops a stale
  // target selection.
  useEffect(() => {
    if (!iHoldCard) {
      setTargetPoint(null);
      setAnchorCorner('TOP_LEFT');
    }
  }, [iHoldCard]);

  if (phase === 'MATCH_OVER') {
    return <ResultScreen players={players} winners={winners} reason={reason} onExit={onExit} />;
  }

  const nameOf = (playerId: string) => players.find((p) => p.playerId === playerId)?.name ?? playerId;
  const isMyTurn = phase === 'TURN' && currentSeat === yourSeat;
  const canPick = isMyTurn && heldBy === null && !busy;
  const myCoins = players.find((p) => p.playerId === self)?.stats.cn ?? 0;
  const myBoard = boards[self] ?? [];
  const currentName = players.find((p) => p.seat === currentSeat)?.name;

  const orderedPlayers = [...players].sort((a, b) => a.seat - b.seat);
  const opponents = orderedPlayers.filter((p) => p.playerId !== self);

  const previewPoints =
    iHoldCard && heldCard && targetPoint
      ? cardToPoints(heldCard, anchorCorner, targetPoint.x, targetPoint.y)
      : null;

  return (
    <View style={styles.root}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={styles.topBar}>
          <View style={{ flex: 1 }}>
            <Text style={styles.roundLabel}>
              Round {round} · {phase === 'BATTLE' ? 'Battle phase' : 'Turn phase'}
              {finalRound ? ' · Final round — all cards free' : ''}
            </Text>
            <Text style={styles.turnIndicator}>
              {phase === 'BATTLE'
                ? 'Resolving battle…'
                : isMyTurn
                  ? iHoldCard
                    ? 'Your turn — rotate, pick an anchor corner, then tap your board'
                    : 'Your turn — pick a card'
                  : `Waiting for ${currentName ?? 'the current player'}…`}
            </Text>
          </View>
          <Button label="Leave" kind="ghost" onPress={onExit} />
        </View>

        <PlayersPanel
          players={players}
          connected={connected}
          currentSeat={currentSeat}
          yourSeat={yourSeat}
          heldBy={heldBy}
        />

        <Text style={styles.sectionTitle}>
          Market{heldBy && !iHoldCard ? ` · ${nameOf(heldBy)} is holding a card` : ''}
        </Text>
        <Market
          market={market}
          deckRemaining={deckRemaining}
          canPick={canPick}
          yourCoins={myCoins}
          finalRound={finalRound}
          onPick={pick}
        />

        {iHoldCard && heldCard && (
          <View style={styles.heldPanel}>
            <Text style={styles.sectionTitle}>Your held card</Text>
            <View style={styles.heldRow}>
              <CardView card={heldCard} size={104} />
              <View style={styles.heldControls}>
                <Button label="Rotate 90°" disabled={busy} onPress={rotate} />
                <Text style={styles.hint}>Anchor corner</Text>
                <View style={styles.cornerRow}>
                  {CORNER_OPTIONS.map(({ corner, label }) => (
                    <Pressable
                      key={corner}
                      onPress={() => setAnchorCorner(corner)}
                      style={[styles.cornerBtn, anchorCorner === corner && styles.cornerBtnActive]}
                    >
                      <Text
                        style={[
                          styles.cornerBtnText,
                          anchorCorner === corner && styles.cornerBtnTextActive,
                        ]}
                      >
                        {label}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </View>
            </View>
            <Text style={styles.hint}>
              {targetPoint
                ? `Anchoring ${anchorCorner.toLowerCase().replace('_', ' ')} at (${targetPoint.x}, ${targetPoint.y}) — the highlighted cells show where it will land.`
                : myBoard.length === 0
                  ? 'Tap your empty board to place this card at the origin.'
                  : 'Tap a point on your board to preview the placement.'}
            </Text>
            {targetPoint && (
              <View style={styles.confirmRow}>
                <Button
                  label="Place here"
                  kind="primary"
                  disabled={busy}
                  onPress={() => {
                    place(anchorCorner, targetPoint.x, targetPoint.y);
                    setTargetPoint(null);
                  }}
                />
                <Button label="Cancel" kind="ghost" onPress={() => setTargetPoint(null)} />
              </View>
            )}
          </View>
        )}

        <Text style={styles.sectionTitle}>Your board</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          <BoardView
            points={myBoard}
            tapEnabled={iHoldCard && !busy}
            previewPoints={previewPoints}
            selectedPoint={targetPoint}
            onTapPoint={(x, y) => setTargetPoint({ x, y })}
            onTapEmpty={() => place(anchorCorner, 0, 0)}
          />
        </ScrollView>

        {opponents.length > 0 && (
          <>
            <Text style={styles.sectionTitle}>Opponents (tap to zoom)</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.oppRail}>
              {opponents.map((p) => (
                <Pressable
                  key={p.playerId}
                  onPress={() => setZoomedOpponent(p.playerId)}
                  style={styles.oppThumb}
                >
                  <Text style={styles.oppName} numberOfLines={1}>
                    {p.name}
                  </Text>
                  <BoardView points={boards[p.playerId] ?? []} cellSize={14} />
                </Pressable>
              ))}
            </ScrollView>
          </>
        )}
      </ScrollView>

      <Modal
        visible={zoomedOpponent !== null}
        transparent
        animationType="fade"
        onRequestClose={() => setZoomedOpponent(null)}
      >
        <Pressable style={styles.modalBackdrop} onPress={() => setZoomedOpponent(null)}>
          <Pressable style={styles.modalPanel} onPress={() => undefined}>
            <View style={styles.modalHeader}>
              <Text style={styles.modalTitle}>{zoomedOpponent ? nameOf(zoomedOpponent) : ''}'s board</Text>
              <Button label="Close" kind="ghost" onPress={() => setZoomedOpponent(null)} />
            </View>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              <ScrollView showsVerticalScrollIndicator={false}>
                <BoardView points={zoomedOpponent ? (boards[zoomedOpponent] ?? []) : []} cellSize={36} />
              </ScrollView>
            </ScrollView>
          </Pressable>
        </Pressable>
      </Modal>

      {phase === 'BATTLE' && lastBattle && (
        <BattleStage battle={lastBattle} players={players} selfId={self} nameOf={nameOf} />
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    flex: 1,
  },
  scroll: {
    padding: spacing.md,
    gap: spacing.sm,
    paddingBottom: spacing.xl,
  },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  roundLabel: {
    color: colors.gold,
    fontWeight: '700',
  },
  turnIndicator: {
    color: colors.textDim,
    fontSize: 13,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
    marginTop: spacing.sm,
  },
  heldPanel: {
    backgroundColor: colors.panel,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: colors.primaryDark,
    padding: spacing.md,
    gap: spacing.sm,
  },
  heldRow: {
    flexDirection: 'row',
    gap: spacing.lg,
    alignItems: 'center',
  },
  heldControls: {
    gap: spacing.sm,
    flex: 1,
  },
  cornerRow: {
    flexDirection: 'row',
    gap: spacing.xs,
  },
  cornerBtn: {
    borderWidth: 1,
    borderColor: colors.border,
    borderRadius: 6,
    paddingVertical: 6,
    paddingHorizontal: 10,
    backgroundColor: colors.panelSoft,
  },
  cornerBtnActive: {
    borderColor: colors.gold,
    backgroundColor: '#3a3420',
  },
  cornerBtnText: {
    color: colors.textDim,
    fontWeight: '700',
    fontSize: 12,
  },
  cornerBtnTextActive: {
    color: colors.gold,
  },
  confirmRow: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  hint: {
    color: colors.textDim,
    fontSize: 12,
  },
  oppRail: {
    gap: spacing.sm,
  },
  oppThumb: {
    backgroundColor: colors.panel,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.sm,
    gap: spacing.xs,
    maxWidth: 180,
  },
  oppName: {
    color: colors.text,
    fontWeight: '600',
    fontSize: 12,
  },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.7)',
    justifyContent: 'center',
    padding: spacing.lg,
  },
  modalPanel: {
    backgroundColor: colors.panel,
    borderRadius: 12,
    borderWidth: 1,
    borderColor: colors.border,
    padding: spacing.md,
    maxHeight: '80%',
    gap: spacing.sm,
  },
  modalHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  modalTitle: {
    color: colors.text,
    fontWeight: '700',
    fontSize: 16,
  },
});
