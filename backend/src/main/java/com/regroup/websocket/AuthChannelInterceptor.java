package com.regroup.websocket;

import com.regroup.identity.GuestPlayer;
import com.regroup.identity.PlayerRegistry;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.stereotype.Component;

/** Authenticates STOMP CONNECT frames from the "token" header issued by POST /api/players. */
@Component
public class AuthChannelInterceptor implements ChannelInterceptor {

    private final PlayerRegistry registry;

    public AuthChannelInterceptor(PlayerRegistry registry) {
        this.registry = registry;
    }

    @Override
    public Message<?> preSend(Message<?> message, MessageChannel channel) {
        StompHeaderAccessor accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
            String token = accessor.getFirstNativeHeader("token");
            GuestPlayer player = registry.byToken(token)
                    .orElseThrow(() -> new IllegalArgumentException("Invalid or missing token"));
            accessor.setUser(new StompPrincipal(player.playerId()));
        }
        return message;
    }
}
