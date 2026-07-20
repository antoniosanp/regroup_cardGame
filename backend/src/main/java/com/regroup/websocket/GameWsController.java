package com.regroup.websocket;

import com.regroup.matchmaking.MatchmakingService;
import com.regroup.session.MatchService;
import org.springframework.messaging.handler.annotation.DestinationVariable;
import org.springframework.messaging.handler.annotation.MessageMapping;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Controller;

import java.security.Principal;
import java.util.Map;

/** Client -> server app destinations (prefix /app), exactly as in WS_CONTRACT.md. Parses and delegates only. */
@Controller
public class GameWsController {

    private final MatchmakingService matchmaking;
    private final MatchService matchService;

    public GameWsController(MatchmakingService matchmaking, MatchService matchService) {
        this.matchmaking = matchmaking;
        this.matchService = matchService;
    }

    @MessageMapping("queue.join")
    public void queueJoin(Principal principal) {
        matchmaking.join(principal.getName());
    }

    @MessageMapping("queue.joinOffline")
    public void queueJoinOffline(Principal principal) {
        matchmaking.joinOffline(principal.getName());
    }

    @MessageMapping("queue.leave")
    public void queueLeave(Principal principal) {
        matchmaking.leave(principal.getName());
    }

    @MessageMapping("match.{matchId}.pick")
    public void pick(@DestinationVariable String matchId,
                     @Payload Map<String, Object> payload,
                     Principal principal) {
        Object slot = payload.get("slot");
        matchService.pick(principal.getName(), matchId, slot == null ? null : slot.toString());
    }

    @MessageMapping("match.{matchId}.rotate")
    public void rotate(@DestinationVariable String matchId, Principal principal) {
        matchService.rotate(principal.getName(), matchId);
    }

    @MessageMapping("match.{matchId}.place")
    public void place(@DestinationVariable String matchId,
                      @Payload Map<String, Object> payload,
                      Principal principal) {
        Object corner = payload.get("corner");
        int x = payload.get("x") instanceof Number n ? n.intValue() : 0;
        int y = payload.get("y") instanceof Number n ? n.intValue() : 0;
        matchService.place(principal.getName(), matchId, corner == null ? null : corner.toString(), x, y);
    }

    @MessageMapping("match.{matchId}.resume")
    public void resume(@DestinationVariable String matchId, Principal principal) {
        matchService.resume(principal.getName(), matchId);
    }

    @MessageMapping("match.{matchId}.leave")
    public void leave(@DestinationVariable String matchId, Principal principal) {
        matchService.leaveMatch(principal.getName(), matchId);
    }
}
