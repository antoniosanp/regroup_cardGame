package com.regroup.websocket;

import java.security.Principal;

/** Principal whose name is the authenticated playerId. */
public record StompPrincipal(String name) implements Principal {

    @Override
    public String getName() {
        return name;
    }
}
