package com.regroup.engine;

/** The match's lifecycle. TURN is the resting phase during a round; BATTLE is transient and resolved synchronously at round end. */
public enum GamePhase {
    WAITING,
    TURN,
    BATTLE,
    MATCH_OVER
}
