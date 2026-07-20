package com.regroup.websocket;

import com.regroup.matchmaking.MatchmakingService;
import com.regroup.session.MatchService;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

import java.security.Principal;

/** Bridges STOMP session lifecycle to matchmaking and live-match presence. */
@Component
public class PresenceListener {

    private final MatchmakingService matchmaking;
    private final MatchService matchService;

    public PresenceListener(MatchmakingService matchmaking, MatchService matchService) {
        this.matchmaking = matchmaking;
        this.matchService = matchService;
    }

    @EventListener
    public void onConnected(SessionConnectedEvent event) {
        Principal user = event.getUser();
        if (user != null) {
            matchService.onPlayerConnected(user.getName());
        }
    }

    @EventListener
    public void onDisconnected(SessionDisconnectEvent event) {
        Principal user = event.getUser();
        if (user != null) {
            matchmaking.onDisconnect(user.getName());
            matchService.onPlayerDisconnected(user.getName());
        }
    }
}
