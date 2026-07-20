package com.regroup.engine;

/** What a placement produced: the placed card, and — if it was the round's last placement — the resulting battle and any match-ending outcome. */
public record PlacementResult(Card placedCard, boolean roundEnded, BattleResult battle, MatchOutcome outcome) {
}
