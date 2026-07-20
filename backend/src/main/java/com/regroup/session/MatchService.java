package com.regroup.session;

import com.regroup.bot.BotStrategies;
import com.regroup.bot.BotStrategy;
import com.regroup.bot.PickChoice;
import com.regroup.bot.Placement;
import com.regroup.engine.BattleResult;
import com.regroup.engine.Board;
import com.regroup.engine.BoardCell;
import com.regroup.engine.Card;
import com.regroup.engine.CornerPosition;
import com.regroup.engine.Deck;
import com.regroup.engine.GamePhase;
import com.regroup.engine.InvalidMoveException;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.MatchOutcome;
import com.regroup.engine.PlacementResult;
import com.regroup.engine.Player;
import com.regroup.engine.Slot;
import com.regroup.websocket.Messages;
import jakarta.annotation.PreDestroy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;

import java.awt.Point;
import java.security.SecureRandom;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

/**
 * Orchestrates live matches: creation, per-turn pick/rotate/place, the round-end battle, elimination,
 * end-of-game and reconnection. The engine is the single source of truth; this class only serializes
 * access to it (one lock per match) and translates its results into wire messages.
 */
@Service
public class MatchService {

    private static final Logger log = LoggerFactory.getLogger(MatchService.class);
    private static final String PRIVATE_QUEUE = "/queue/game";
    private static final long FINISHED_MATCH_RETENTION_MINUTES = 10;
    private static final long TURN_TIMEOUT_SECONDS = 60;
    // Bots act after a short, human-like delay rather than waiting on the turn timeout. Kept
    // slow enough that a chain of bot turns after a battle reads as separate beats rather than
    // as one instant block landing right on top of the battle-end sound (which is what made
    // "your turn" feel like it fires immediately after every battle in bot matches).
    private static final long BOT_MOVE_MIN_MS = 1200;
    private static final long BOT_MOVE_MAX_MS = 2600;
    // Pause between BATTLE_RESULT and the next ROUND_START / MATCH_RESULT so clients can play
    // the per-attack battle animation before the phase (and BattleStage's overlay) flips away.
    // Must cover BattleStage.tsx's actual timeline or the trailing attacks of the last phase get
    // cut off mid-animation: per phase (one per distinct attacker, up to PLAYER_COUNT of them) a
    // 450ms "who's attacking" beat, then per attack a 600ms lunge + 420ms impact flash + 280ms
    // pause (1300ms), plus a 900ms beat if anyone healed (potion use must stay visible) and a
    // 700ms beat if anyone was eliminated — both can apply in the same battle. BASE covers the
    // phase beats + heal + elimination beats + margin; PER_ATTACK matches the per-attack cost.
    private static final long BATTLE_PAUSE_BASE_MS = 3800;
    private static final long BATTLE_PAUSE_PER_ATTACK_MS = 1300;

    private final SimpMessagingTemplate messaging;
    private final Random rng = new SecureRandom();
    private final ScheduledExecutorService scheduler = Executors.newSingleThreadScheduledExecutor();

    private final Map<String, LiveMatch> matchesById = new ConcurrentHashMap<>();
    private final Map<String, String> matchIdByPlayerId = new ConcurrentHashMap<>();

    public MatchService(SimpMessagingTemplate messaging) {
        this.messaging = messaging;
    }

    @PreDestroy
    void shutdown() {
        scheduler.shutdownNow();
    }

    public boolean isInActiveMatch(String playerId) {
        String matchId = matchIdByPlayerId.get(playerId);
        if (matchId == null) {
            return false;
        }
        LiveMatch match = matchesById.get(matchId);
        return match != null && !match.isFinished();
    }

    /** Called by matchmaking with exactly 4 human players (seats already assigned by list order). */
    public void createMatch(List<Messages.PlayerInfo> players) {
        createMatch(players, Set.of());
    }

    /** As above, but {@code botSeats} marks seats driven by a server-side AI personality instead of a client. */
    public void createMatch(List<Messages.PlayerInfo> players, Set<Integer> botSeats) {
        String matchId = UUID.randomUUID().toString();
        MatchEngine engine = new MatchEngine(Deck.standard(rng));
        engine.start();
        Map<Integer, BotStrategy> botStrategies = BotStrategies.assignPersonalities(botSeats, rng);
        LiveMatch match = new LiveMatch(matchId, players, engine, botStrategies);
        matchesById.put(matchId, match);
        for (Messages.PlayerInfo p : players) {
            matchIdByPlayerId.put(p.playerId(), matchId);
        }
        synchronized (match) {
            for (Messages.PlayerInfo p : players) {
                sendPrivate(p.playerId(), new Messages.MatchFound(matchId, players, p.seat()));
            }
            broadcast(match, new Messages.RoundStart(engine.round(), engine.startingSeat(), engine.isFinalRound()));
            armTurn(match);
        }
        log.info("Match {} created for {}", matchId, players.stream().map(Messages.PlayerInfo::name).toList());
        if (!botStrategies.isEmpty()) {
            log.info("Match {} bot personalities: {}", matchId, botStrategies.entrySet().stream()
                    .map(e -> "seat " + e.getKey() + "=" + e.getValue().getClass().getSimpleName()).toList());
        }
    }

    public void pick(String playerId, String matchId, String slot) {
        LiveMatch match = requireMatch(playerId, matchId);
        if (match == null) {
            return;
        }
        if (slot == null) {
            sendError(playerId, "BAD_STATE", "Missing slot");
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            Card card;
            try {
                if ("DECK".equals(slot)) {
                    card = match.engine().pickFromDeck(seat);
                } else {
                    card = match.engine().pickFromMarket(seat, parseSlot(slot));
                }
            } catch (InvalidMoveException e) {
                sendError(playerId, e.getCode().name(), e.getMessage());
                return;
            } catch (IllegalArgumentException e) {
                sendError(playerId, "BAD_STATE", "Unknown slot: " + slot);
                return;
            }
            MatchEngine engine = match.engine();
            broadcast(match, new Messages.CardPicked(playerId, slot, cardDto(card),
                    marketSnapshot(engine), engine.deckRemaining()));
        }
    }

    public void rotate(String playerId, String matchId) {
        LiveMatch match = requireMatch(playerId, matchId);
        if (match == null) {
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            try {
                var rotation = match.engine().rotate(seat);
                broadcast(match, new Messages.CardRotated(playerId, rotation.name()));
            } catch (InvalidMoveException e) {
                sendError(playerId, e.getCode().name(), e.getMessage());
            }
        }
    }

    public void place(String playerId, String matchId, String corner, int x, int y) {
        LiveMatch match = requireMatch(playerId, matchId);
        if (match == null) {
            return;
        }
        if (corner == null) {
            sendError(playerId, "BAD_STATE", "Missing corner");
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            MatchEngine engine = match.engine();
            PlacementResult result;
            try {
                result = engine.place(seat, parseCorner(corner), x, y);
            } catch (InvalidMoveException e) {
                sendError(playerId, e.getCode().name(), e.getMessage());
                return;
            } catch (IllegalArgumentException e) {
                sendError(playerId, "BAD_STATE", "Unknown corner: " + corner);
                return;
            }
            broadcast(match, new Messages.CardPlaced(playerId, corner, x, y, cardDto(result.placedCard())));
            broadcast(match, new Messages.StatsUpdated(playerId, statsOf(engine.player(seat))));
            afterPlacement(match, engine, result);
        }
    }

    /** Shared tail for a completed placement, whether typed by the player or auto-played on timeout: advances the turn, or resolves the round/match if it was the round's last placement, and (re)arms the next turn's timeout. Must hold the match lock. */
    private void afterPlacement(LiveMatch match, MatchEngine engine, PlacementResult result) {
        match.cancelTurnTimeout();
        if (!result.roundEnded()) {
            armTurn(match);
            return;
        }
        broadcastBattle(match, result.battle());
        for (BattleResult.Outcome o : result.battle().outcomes()) {
            if (o.eliminated()) {
                broadcast(match, new Messages.PlayerEliminated(match.playerIdAt(o.seat()), o.hpAfter()));
            }
        }
        long pause = BATTLE_PAUSE_BASE_MS + BATTLE_PAUSE_PER_ATTACK_MS * result.battle().attacks().size();
        MatchOutcome outcome = result.outcome();
        scheduler.schedule(() -> afterBattlePause(match, outcome), pause, TimeUnit.MILLISECONDS);
    }

    /** Runs when the battle-animation pause elapses: announces the match result, or starts the next round. */
    private void afterBattlePause(LiveMatch match, MatchOutcome outcome) {
        synchronized (match) {
            if (match.isFinished()) {
                return;
            }
            if (outcome != null) {
                finishMatch(match, outcome);
                return;
            }
            MatchEngine engine = match.engine();
            broadcast(match, new Messages.RoundStart(engine.round(), engine.startingSeat(), engine.isFinalRound()));
            armTurn(match);
        }
    }

    /**
     * Announces the current seat's turn and arms its safety timeout; if that seat is a bot, also schedules
     * its move after a short delay. Bot turns chain naturally: the bot's placement runs {@link #afterPlacement},
     * which calls back here for the next seat. Must hold the match lock.
     */
    private void armTurn(LiveMatch match) {
        MatchEngine engine = match.engine();
        int seat = engine.currentSeat();
        broadcast(match, new Messages.TurnStart(match.playerIdAt(seat), seat));
        scheduleTurnTimeout(match);
        if (match.isBot(seat)) {
            int round = engine.round();
            long delay = BOT_MOVE_MIN_MS + rng.nextInt((int) (BOT_MOVE_MAX_MS - BOT_MOVE_MIN_MS + 1));
            scheduler.schedule(() -> playBotTurn(match, round, seat), delay, TimeUnit.MILLISECONDS);
        }
    }

    /**
     * Plays one bot turn by delegating both decisions to the seat's {@link BotStrategy}. Re-validates
     * round/seat/phase under the match lock first, so a firing that lost the race (the turn already
     * moved on) is a safe no-op. The turn timeout stays armed as a dormant fallback; a strategy that
     * fails or finds nothing pickable leaves the turn to it.
     */
    private void playBotTurn(LiveMatch match, int round, int seat) {
        synchronized (match) {
            if (match.isFinished()) {
                return;
            }
            MatchEngine engine = match.engine();
            if (engine.phase() != GamePhase.TURN || engine.round() != round || engine.currentSeat() != seat) {
                return;
            }
            String playerId = match.playerIdAt(seat);
            BotStrategy strategy = match.strategyAt(seat);

            PickChoice choice;
            try {
                choice = strategy.choosePick(engine, seat);
            } catch (RuntimeException e) {
                log.warn("Match {} bot seat {} pick strategy failed; leaving it to the turn timeout",
                        match.matchId(), seat, e);
                return;
            }
            if (choice == null) {
                log.warn("Match {} bot seat {} has no affordable pick; leaving it to the turn timeout",
                        match.matchId(), seat);
                return;
            }
            Card card;
            try {
                card = choice.isDeck() ? engine.pickFromDeck(seat) : engine.pickFromMarket(seat, choice.slot());
            } catch (InvalidMoveException e) {
                log.warn("Match {} bot seat {} pick failed: {}", match.matchId(), seat, e.getMessage());
                return;
            }
            broadcast(match, new Messages.CardPicked(playerId, choice.wireName(), cardDto(card),
                    marketSnapshot(engine), engine.deckRemaining()));

            Placement placement;
            try {
                placement = strategy.choosePlacement(engine, seat, card);
            } catch (RuntimeException e) {
                log.warn("Match {} bot seat {} placement strategy failed; leaving it to the turn timeout",
                        match.matchId(), seat, e);
                return;
            }
            PlacementResult result;
            try {
                for (int i = 0; i < placement.rotations(); i++) {
                    var rotation = engine.rotate(seat);
                    broadcast(match, new Messages.CardRotated(playerId, rotation.name()));
                }
                result = engine.place(seat, placement.overlapCorner(), placement.x(), placement.y());
            } catch (InvalidMoveException e) {
                log.warn("Match {} bot seat {} placement failed: {}", match.matchId(), seat, e.getMessage());
                return;
            }
            broadcast(match, new Messages.CardPlaced(playerId, placement.overlapCorner().name(),
                    placement.x(), placement.y(), cardDto(result.placedCard())));
            broadcast(match, new Messages.StatsUpdated(playerId, statsOf(engine.player(seat))));
            afterPlacement(match, engine, result);
        }
    }

    /** Arms the turn timeout ({@link #TURN_TIMEOUT_SECONDS}) for whoever currently holds the turn, capturing round+seat so a stale firing (the turn already moved on) is a safe no-op. Must hold the match lock. */
    private void scheduleTurnTimeout(LiveMatch match) {
        MatchEngine engine = match.engine();
        int round = engine.round();
        int seat = engine.currentSeat();
        match.setTurnTimeout(scheduler.schedule(
                () -> onTurnTimeout(match, round, seat), TURN_TIMEOUT_SECONDS, TimeUnit.SECONDS));
    }

    /** Auto-plays a stalled or disconnected player's turn: a free deck draw placed at the first legal board point. Presence (connected/disconnected) is irrelevant here on purpose — a slow connected player and a disconnected one are covered by the same mechanism. */
    private void onTurnTimeout(LiveMatch match, int round, int seat) {
        synchronized (match) {
            if (match.isFinished()) {
                return;
            }
            MatchEngine engine = match.engine();
            if (engine.phase() != GamePhase.TURN || engine.round() != round || engine.currentSeat() != seat) {
                return;
            }
            String playerId = match.playerIdAt(seat);
            Card card;
            try {
                card = engine.pickFromDeck(seat);
            } catch (InvalidMoveException e) {
                log.warn("Match {} seat {} turn timed out with no card left to auto-play", match.matchId(), seat);
                return;
            }
            broadcast(match, new Messages.CardPicked(playerId, "DECK", cardDto(card),
                    marketSnapshot(engine), engine.deckRemaining()));

            Board board = engine.player(seat).board();
            Point at = board.isEmpty() ? new Point(0, 0) : board.cells().keySet().iterator().next();
            PlacementResult result;
            try {
                result = engine.place(seat, CornerPosition.TOP_LEFT, at.x, at.y);
            } catch (InvalidMoveException e) {
                log.warn("Match {} seat {} auto-play placement failed: {}", match.matchId(), seat, e.getMessage());
                return;
            }
            broadcast(match, new Messages.CardPlaced(
                    playerId, CornerPosition.TOP_LEFT.name(), at.x, at.y, cardDto(result.placedCard())));
            broadcast(match, new Messages.StatsUpdated(playerId, statsOf(engine.player(seat))));
            afterPlacement(match, engine, result);
        }
    }

    public void resume(String playerId, String matchId) {
        LiveMatch match = requireMatch(playerId, matchId);
        if (match == null) {
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            MatchEngine engine = match.engine();

            List<Messages.PlayerState> playerStates = new ArrayList<>();
            Map<String, List<Messages.BoardCellDto>> boards = new LinkedHashMap<>();
            for (Messages.PlayerInfo info : match.players()) {
                int s = info.seat();
                playerStates.add(new Messages.PlayerState(
                        info.playerId(), info.name(), s, engine.isAlive(s), statsOf(engine.player(s))));
                boards.put(info.playerId(), boardCells(engine.player(s).board()));
            }

            Messages.CardDto held = seat == engine.currentSeat() ? cardDto(engine.heldCard()) : null;

            sendPrivate(playerId, new Messages.ResumeState(
                    match.matchId(), engine.phase().name(), engine.round(), engine.currentSeat(), engine.isFinalRound(),
                    playerStates, boards, marketSnapshot(engine), engine.deckRemaining(), held));
        }
    }

    /** Presence: STOMP session connected. Recognizes a reconnecting player by their seat. */
    public void onPlayerConnected(String playerId) {
        LiveMatch match = activeMatchOf(playerId);
        if (match == null) {
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            if (seat >= 0 && !match.isConnected(seat)) {
                match.setConnected(seat, true);
                broadcast(match, new Messages.PlayerNotice("PLAYER_RECONNECTED", playerId));
            }
        }
    }

    /** Presence: STOMP session disconnected. The match keeps running; the player resumes with a fresh snapshot. */
    public void onPlayerDisconnected(String playerId) {
        LiveMatch match = activeMatchOf(playerId);
        if (match == null) {
            return;
        }
        synchronized (match) {
            int seat = match.seatOf(playerId);
            if (seat >= 0 && match.isConnected(seat)) {
                match.setConnected(seat, false);
                broadcast(match, new Messages.PlayerNotice("PLAYER_DISCONNECTED", playerId));
            }
        }
    }

    /** Must hold the match lock. */
    private void finishMatch(LiveMatch match, MatchOutcome outcome) {
        match.markFinished();
        List<String> winners = outcome.winnerSeats().stream().map(match::playerIdAt).toList();
        broadcast(match, new Messages.MatchResult(winners, outcome.reason().name()));
        for (Messages.PlayerInfo p : match.players()) {
            matchIdByPlayerId.remove(p.playerId(), match.matchId());
        }
        scheduler.schedule(() -> matchesById.remove(match.matchId()),
                FINISHED_MATCH_RETENTION_MINUTES, TimeUnit.MINUTES);
        log.info("Match {} finished, winners {} ({})", match.matchId(), winners, outcome.reason());
    }

    private void broadcastBattle(LiveMatch match, BattleResult battle) {
        List<Messages.BattleAttack> attacks = new ArrayList<>();
        for (BattleResult.Attack a : battle.attacks()) {
            attacks.add(new Messages.BattleAttack(match.playerIdAt(a.attackerSeat()), match.playerIdAt(a.defenderSeat()),
                    a.physicalDamage(), a.magicDamage(), a.totalDamage()));
        }
        List<Messages.BattleOutcome> outcomes = new ArrayList<>();
        for (BattleResult.Outcome o : battle.outcomes()) {
            outcomes.add(new Messages.BattleOutcome(match.playerIdAt(o.seat()), o.hpBefore(), o.damageTaken(),
                    o.healedHp(), o.hpAfter(), o.eliminated()));
        }
        broadcast(match, new Messages.BattleResult(battle.round(), attacks, outcomes));
    }

    private LiveMatch requireMatch(String playerId, String matchId) {
        LiveMatch match = matchesById.get(matchId);
        if (match == null || match.seatOf(playerId) < 0) {
            sendError(playerId, "NOT_IN_MATCH", "You are not part of this match");
            return null;
        }
        return match;
    }

    private LiveMatch activeMatchOf(String playerId) {
        String matchId = matchIdByPlayerId.get(playerId);
        if (matchId == null) {
            return null;
        }
        LiveMatch match = matchesById.get(matchId);
        return match == null || match.isFinished() ? null : match;
    }

    private static Slot parseSlot(String slot) {
        return Slot.valueOf(slot);
    }

    private static CornerPosition parseCorner(String corner) {
        return CornerPosition.valueOf(corner);
    }

    private static Messages.Stats statsOf(Player player) {
        return new Messages.Stats(player.hp(), player.pa(), player.pd(), player.ma(), player.md(),
                player.cn(), player.hpp());
    }

    private static Messages.CardDto cardDto(Card card) {
        if (card == null) {
            return null;
        }
        return new Messages.CardDto(
                card.at(CornerPosition.TOP_LEFT).name(),
                card.at(CornerPosition.TOP_RIGHT).name(),
                card.at(CornerPosition.BOTTOM_LEFT).name(),
                card.at(CornerPosition.BOTTOM_RIGHT).name(),
                card.rotation().name());
    }

    private static Map<String, Messages.CardDto> marketSnapshot(MatchEngine engine) {
        Map<String, Messages.CardDto> market = new LinkedHashMap<>();
        for (Slot s : Slot.values()) {
            market.put(s.name(), cardDto(engine.marketCard(s)));
        }
        return market;
    }

    private static List<Messages.BoardCellDto> boardCells(Board board) {
        List<Messages.BoardCellDto> cells = new ArrayList<>();
        for (Map.Entry<Point, BoardCell> entry : board.cells().entrySet()) {
            Point p = entry.getKey();
            BoardCell cell = entry.getValue();
            cells.add(new Messages.BoardCellDto(p.x, p.y, cell.attribute().name(), cell.rotation().name()));
        }
        return cells;
    }

    private void broadcast(LiveMatch match, Object message) {
        messaging.convertAndSend("/topic/match." + match.matchId(), message);
    }

    private void sendPrivate(String playerId, Object message) {
        messaging.convertAndSendToUser(playerId, PRIVATE_QUEUE, message);
    }

    public void sendError(String playerId, String code, String message) {
        sendPrivate(playerId, new Messages.Error(code, message));
    }
}
