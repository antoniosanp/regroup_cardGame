package com.regroup.engine;

import java.util.List;

/** How the match ended: the winning seats (more than one only on a mutual-kill final-hp tie) and why. */
public record MatchOutcome(List<Integer> winnerSeats, Reason reason) {

    public enum Reason {
        LAST_STANDING,
        DECK_EXHAUSTED
    }
}
