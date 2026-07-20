package com.regroup.identity;

import org.springframework.stereotype.Component;

import java.security.SecureRandom;
import java.util.Base64;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;

/** In-memory guest registry. Tokens are opaque and only meaningful to this process. */
@Component
public class PlayerRegistry {

    private final SecureRandom random = new SecureRandom();
    private final Map<String, GuestPlayer> byToken = new ConcurrentHashMap<>();
    private final Map<String, GuestPlayer> byId = new ConcurrentHashMap<>();

    public GuestPlayer register(String name) {
        byte[] raw = new byte[32];
        random.nextBytes(raw);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(raw);
        GuestPlayer player = new GuestPlayer(UUID.randomUUID().toString(), token, name);
        byToken.put(token, player);
        byId.put(player.playerId(), player);
        return player;
    }

    public Optional<GuestPlayer> byToken(String token) {
        return token == null ? Optional.empty() : Optional.ofNullable(byToken.get(token));
    }

    public Optional<GuestPlayer> byId(String playerId) {
        return playerId == null ? Optional.empty() : Optional.ofNullable(byId.get(playerId));
    }
}
