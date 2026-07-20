package com.regroup.matchmaking;

import com.regroup.engine.MatchEngine;
import com.regroup.identity.GuestPlayer;
import com.regroup.identity.PlayerRegistry;
import com.regroup.session.MatchService;
import com.regroup.websocket.Messages;
import org.springframework.stereotype.Service;

import java.util.ArrayList;
import java.util.Iterator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;

/** In-memory FIFO queue; pops a match as soon as 4 players are waiting. */
@Service
public class MatchmakingService {

    private final PlayerRegistry registry;
    private final MatchService matchService;
    private final Set<String> queue = new LinkedHashSet<>();

    public MatchmakingService(PlayerRegistry registry, MatchService matchService) {
        this.registry = registry;
        this.matchService = matchService;
    }

    public void join(String playerId) {
        if (matchService.isInActiveMatch(playerId)) {
            matchService.sendError(playerId, "BAD_STATE", "Already in an active match");
            return;
        }
        List<Messages.PlayerInfo> matched = null;
        synchronized (queue) {
            queue.add(playerId);
            if (queue.size() >= MatchEngine.PLAYER_COUNT) {
                matched = new ArrayList<>(MatchEngine.PLAYER_COUNT);
                Iterator<String> it = queue.iterator();
                while (it.hasNext() && matched.size() < MatchEngine.PLAYER_COUNT) {
                    String id = it.next();
                    it.remove();
                    GuestPlayer player = registry.byId(id).orElseThrow();
                    matched.add(new Messages.PlayerInfo(player.playerId(), player.name(), matched.size()));
                }
            }
        }
        if (matched != null) {
            matchService.createMatch(matched);
        }
    }

    /**
     * Starts a single-human match immediately, filling the other 3 seats with server-driven "easy" bots
     * instead of waiting in the real queue. The human takes seat 0; bots take seats 1-3.
     */
    public void joinOffline(String playerId) {
        if (matchService.isInActiveMatch(playerId)) {
            matchService.sendError(playerId, "BAD_STATE", "Already in an active match");
            return;
        }
        GuestPlayer human = registry.byId(playerId).orElseThrow();
        List<Messages.PlayerInfo> players = new ArrayList<>(MatchEngine.PLAYER_COUNT);
        players.add(new Messages.PlayerInfo(human.playerId(), human.name(), 0));
        Set<Integer> botSeats = new LinkedHashSet<>();
        for (int seat = 1; seat < MatchEngine.PLAYER_COUNT; seat++) {
            GuestPlayer bot = registry.register("Bot " + seat);
            players.add(new Messages.PlayerInfo(bot.playerId(), bot.name(), seat));
            botSeats.add(seat);
        }
        matchService.createMatch(players, botSeats);
    }

    public void leave(String playerId) {
        synchronized (queue) {
            queue.remove(playerId);
        }
    }

    /** Queued players who disconnect are dropped from the queue. */
    public void onDisconnect(String playerId) {
        leave(playerId);
    }
}
