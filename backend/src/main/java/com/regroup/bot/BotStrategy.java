package com.regroup.bot;

import com.regroup.engine.Card;
import com.regroup.engine.MatchEngine;

/**
 * The two decisions a bot makes on its turn. Implementations only read engine state; MatchService
 * executes the returned choices through the engine's normal move API. Instances are stateful
 * (a per-turn profile carries from pick to placement), belong to exactly one seat of one match,
 * and are always called under that match's lock.
 */
public interface BotStrategy {

    /** What to pick this turn, or null if nothing is pickable/affordable — the caller then leaves the turn to the timeout. */
    PickChoice choosePick(MatchEngine engine, int seat);

    /** Where to put the card just picked; never null (any existing board point is a legal anchor, (0,0) when empty). */
    Placement choosePlacement(MatchEngine engine, int seat, Card held);
}
