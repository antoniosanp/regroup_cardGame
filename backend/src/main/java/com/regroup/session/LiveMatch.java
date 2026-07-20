package com.regroup.session;

import com.regroup.bot.BotStrategy;
import com.regroup.engine.MatchEngine;
import com.regroup.websocket.Messages;

import java.util.List;
import java.util.Map;
import java.util.concurrent.ScheduledFuture;

/**
 * One live match: engine plus session bookkeeping. All mutation goes through MatchService, which
 * synchronizes on this object to serialize concurrent picks, placements, resumes and presence changes.
 */
public class LiveMatch {

    private final String matchId;
    private final List<Messages.PlayerInfo> players;
    private final MatchEngine engine;
    private final boolean[] connected = new boolean[MatchEngine.PLAYER_COUNT];
    private final BotStrategy[] botStrategies = new BotStrategy[MatchEngine.PLAYER_COUNT];
    private boolean finished;
    private volatile ScheduledFuture<?> turnTimeout;

    public LiveMatch(String matchId, List<Messages.PlayerInfo> players, MatchEngine engine,
                     Map<Integer, BotStrategy> botStrategies) {
        this.matchId = matchId;
        this.players = List.copyOf(players);
        this.engine = engine;
        for (int i = 0; i < connected.length; i++) {
            connected[i] = true;
        }
        botStrategies.forEach((seat, strategy) -> this.botStrategies[seat] = strategy);
    }

    public String matchId() {
        return matchId;
    }

    public List<Messages.PlayerInfo> players() {
        return players;
    }

    public MatchEngine engine() {
        return engine;
    }

    /** Seat index for a playerId, or -1 if the player is not in this match. */
    public int seatOf(String playerId) {
        for (int i = 0; i < players.size(); i++) {
            if (players.get(i).playerId().equals(playerId)) {
                return i;
            }
        }
        return -1;
    }

    public String playerIdAt(int seat) {
        return players.get(seat).playerId();
    }

    /** A bot seat is driven by the server, never by a STOMP session. */
    public boolean isBot(int seat) {
        return botStrategies[seat] != null;
    }

    /** The AI driving this seat, or null for a human seat. */
    public BotStrategy strategyAt(int seat) {
        return botStrategies[seat];
    }

    public boolean isConnected(int seat) {
        return connected[seat];
    }

    public void setConnected(int seat, boolean value) {
        connected[seat] = value;
    }

    public boolean isFinished() {
        return finished;
    }

    public void markFinished() {
        this.finished = true;
    }

    /** Replaces the pending turn-timeout task, if any, with a new one (cancelling the old one first). */
    public void setTurnTimeout(ScheduledFuture<?> future) {
        cancelTurnTimeout();
        this.turnTimeout = future;
    }

    public void cancelTurnTimeout() {
        if (turnTimeout != null) {
            turnTimeout.cancel(false);
            turnTimeout = null;
        }
    }
}
