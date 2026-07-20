import { useEffect, useState, type DragEvent } from 'react';
import { BOARD_ART } from '../../online/assets';
import { cardToPoints, type CornerName } from '../../online/cards';
import type { Stats } from '../../online/messages';
import { useOnlineStore, type BattleVM } from '../../online/onlineStore';
import { playSfx } from '../../sfx/playSfx';
import { BattleStage } from './BattleStage';
import { BoardView } from './BoardView';
import { CardView } from './CardView';
import { Market } from './Market';
import { OpponentsModal } from './OpponentsModal';
import { PlayerHud } from './PlayerHud';
import { PlayerOrderRow } from './PlayerOrderRow';
import { ResultScreen } from './ResultScreen';
import { TurnTimer } from './TurnTimer';

const ZERO_STATS: Stats = { hp: 0, pa: 0, pd: 0, ma: 0, md: 0, cn: 0, hpp: 0 };

function quadrantOf(e: DragEvent<HTMLDivElement>): CornerName {
  const rect = e.currentTarget.getBoundingClientRect();
  const isLeft = e.clientX - rect.left < rect.width / 2;
  const isTop = e.clientY - rect.top < rect.height / 2;
  if (isTop) return isLeft ? 'TOP_LEFT' : 'TOP_RIGHT';
  return isLeft ? 'BOTTOM_LEFT' : 'BOTTOM_RIGHT';
}

export function Match({
  onExit,
  pauseTimer = false,
}: {
  onExit: () => void;
  /** Freezes the turn countdown. Set by the self-paced tutorial; see TurnTimer's `paused`. */
  pauseTimer?: boolean;
}) {
  const self = useOnlineStore((s) => s.identity?.playerId ?? '');
  const players = useOnlineStore((s) => s.players);
  const connected = useOnlineStore((s) => s.connected);
  const phase = useOnlineStore((s) => s.phase);
  const round = useOnlineStore((s) => s.round);
  const currentSeat = useOnlineStore((s) => s.currentSeat);
  const startingSeat = useOnlineStore((s) => s.startingSeat);
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

  // Which corner of the held card is "leading" the drag (grabbed side) and
  // which existing board point it's currently hovering, for the live preview.
  const [dragCorner, setDragCorner] = useState<CornerName | null>(null);
  const [hoverPoint, setHoverPoint] = useState<{ x: number; y: number } | null>(null);
  const [opponentsOpen, setOpponentsOpen] = useState(false);

  // The server's battle-phase pause is only a best-effort estimate of the client
  // animation's real length. Capturing the battle here (instead of rendering
  // straight off the store's lastBattle) lets the overlay outlive a ROUND_START
  // that arrives before BattleStage says it's actually finished, so a fast
  // server / slow client never cuts off the last attacker's last hits.
  const [overlayBattle, setOverlayBattle] = useState<BattleVM | null>(null);
  const [overlayDone, setOverlayDone] = useState(false);

  useEffect(() => {
    if (lastBattle) {
      setOverlayBattle(lastBattle);
      setOverlayDone(false);
    }
  }, [lastBattle]);

  useEffect(() => {
    if (overlayDone && phase !== 'BATTLE' && overlayBattle) {
      setOverlayBattle(null);
    }
  }, [overlayDone, phase, overlayBattle]);

  if (phase === 'MATCH_OVER') {
    const youWon = winners?.includes(self) ?? false;
    return (
      <ResultScreen players={players} winners={winners} reason={reason} youWon={youWon} onExit={onExit} />
    );
  }

  const isMyTurn = phase === 'TURN' && currentSeat === yourSeat;
  const iHoldCard = heldBy === self && heldCard !== null;
  const canPick = isMyTurn && heldBy === null && !busy;
  const me = players.find((p) => p.playerId === self);
  const myCoins = me?.stats.cn ?? 0;
  const myBoard = boards[self] ?? [];
  const currentName = players.find((p) => p.seat === currentSeat)?.name;

  const previewPoints =
    iHoldCard && heldCard && dragCorner && hoverPoint
      ? cardToPoints(heldCard, dragCorner, hoverPoint.x, hoverPoint.y)
      : null;

  const endDrag = () => {
    setDragCorner(null);
    setHoverPoint(null);
  };

  const handleDragStart = (e: DragEvent<HTMLDivElement>) => {
    if (!iHoldCard || busy) {
      e.preventDefault();
      return;
    }
    e.dataTransfer.effectAllowed = 'move';
    setDragCorner(quadrantOf(e));
    playSfx('card-drag-start');
  };

  const handleDragOverPoint = (x: number, y: number) => {
    setHoverPoint((prev) => {
      if (prev && prev.x === x && prev.y === y) return prev;
      playSfx('card-hover-cell');
      return { x, y };
    });
  };

  const handleDropPoint = () => {
    if (!dragCorner || !hoverPoint || busy) return;
    place(dragCorner, hoverPoint.x, hoverPoint.y);
    endDrag();
  };

  const handleDropEmpty = () => {
    if (busy) return;
    place(dragCorner ?? 'TOP_LEFT', 0, 0);
    endDrag();
  };

  return (
    <div className="match">
      <div className="match-top">
        <TurnTimer
          phase={phase}
          round={round}
          currentSeat={currentSeat}
          currentName={currentName}
          isYourTurn={isMyTurn}
          paused={pauseTimer}
        />

        <section className="market-section">
          <Market
            market={market}
            deckRemaining={deckRemaining}
            canPick={canPick}
            yourCoins={myCoins}
            finalRound={finalRound}
            onPick={pick}
          />
        </section>

        <div className="opponent-board-col">
          <button
            type="button"
            className="opponent-board-btn"
            style={{ backgroundImage: `url(${BOARD_ART.opponentBoardButton})` }}
            aria-label="Opponent boards"
            onClick={() => {
              playSfx('ui-modal-open');
              setOpponentsOpen(true);
            }}
          />
          <PlayerOrderRow
            players={players}
            currentSeat={currentSeat}
            startingSeat={startingSeat}
            phase={phase}
            selfId={self}
          />
        </div>
      </div>

      <section className="board-zone">
        <div className="board-frame">
          <img className="border-pole border-pole-left" src={BOARD_ART.borderPole1} alt="" />
          <div className="board-wrap board-wrap-self" style={{ backgroundImage: `url(${BOARD_ART.mainBoard})` }}>
            <BoardView
              points={myBoard}
              dropEnabled={iHoldCard && !busy}
              previewPoints={previewPoints}
              onDragOverPoint={handleDragOverPoint}
              onDrop={handleDropPoint}
              onDropEmpty={handleDropEmpty}
            />
          </div>
          <img className="border-pole border-pole-right" src={BOARD_ART.borderPole2} alt="" />
        </div>
      </section>

      <div className="match-status">
        <span className="round-label">
          Round {round} · {phase === 'BATTLE' ? 'Battle phase' : 'Turn phase'}
          {finalRound && ' · Final round — all cards free'}
        </span>
        <span className="turn-indicator">
          {phase === 'BATTLE'
            ? 'Resolving battle…'
            : isMyTurn
              ? iHoldCard
                ? 'Rotate then drag your card onto your board'
                : 'Your turn — pick a card'
              : `Waiting for ${currentName ?? 'the current player'}…`}
        </span>
        <button
          className="btn-ghost"
          onClick={() => {
            playSfx('ui-click');
            onExit();
          }}
        >
          Leave match
        </button>
      </div>

      <div className="match-bottom">
        <PlayerHud seat={yourSeat} name={me?.name ?? 'You'} stats={me?.stats ?? ZERO_STATS} />

        <div className="hand-slot">
          {iHoldCard && heldCard ? (
            <div className="held-card">
              <div
                className="held-card-drag"
                draggable={!busy}
                onDragStart={handleDragStart}
                onDragEnd={endDrag}
              >
                <CardView card={heldCard} />
              </div>
              <button
                disabled={busy}
                onClick={() => {
                  playSfx('card-rotate');
                  rotate();
                }}
              >
                Rotate 90°
              </button>
              <p className="hint">
                {dragCorner
                  ? 'Drop it on your board — the highlighted cells show where it will land.'
                  : 'Grab a corner of the card and drag it onto your board to place it.'}
              </p>
            </div>
          ) : (
            <div className="hand-slot-empty" style={{ backgroundImage: `url(${BOARD_ART.cardBack})` }}>
              <span className="hint">Empty hand</span>
            </div>
          )}
        </div>
      </div>

      <OpponentsModal
        open={opponentsOpen}
        onClose={() => setOpponentsOpen(false)}
        players={players}
        self={self}
        boards={boards}
        connected={connected}
        currentSeat={currentSeat}
        heldBy={heldBy}
      />

      {overlayBattle && (phase === 'BATTLE' || !overlayDone) && (
        <BattleStage
          battle={overlayBattle}
          players={players}
          selfId={self}
          onFinished={() => setOverlayDone(true)}
        />
      )}
    </div>
  );
}
