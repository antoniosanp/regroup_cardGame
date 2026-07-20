package com.regroup.identity;

import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

@RestController
@RequestMapping("/api/players")
public class PlayerController {

    private final PlayerRegistry registry;

    public PlayerController(PlayerRegistry registry) {
        this.registry = registry;
    }

    public record CreatePlayerRequest(String name) {
    }

    public record CreatePlayerResponse(String playerId, String token, String name) {
    }

    @PostMapping
    public CreatePlayerResponse create(@RequestBody CreatePlayerRequest request) {
        if (request.name() == null || request.name().isBlank()) {
            throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "name is required");
        }
        GuestPlayer player = registry.register(request.name().trim());
        return new CreatePlayerResponse(player.playerId(), player.token(), player.name());
    }
}
