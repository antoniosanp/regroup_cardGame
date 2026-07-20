package com.regroup.bot;

import com.regroup.engine.MatchEngine;
import com.regroup.engine.Player;

import java.util.Random;
import java.util.function.ToDoubleFunction;

/**
 * "The berserker" (botAIplan.md 3.2): most turns it stacks PA/MA, mildly preferring whichever
 * attack is already stronger on its board — adjacency rewards concentration. No equilibrium rule:
 * unlike defense, focused attack is fine. The rest of the time it plays a neutral best-overall move.
 */
public class OffensiveBotStrategy extends WeightedBotStrategy {

    public OffensiveBotStrategy(Random rng) {
        super(rng);
    }

    @Override
    protected ToDoubleFunction<MoveEvaluator.EvaluatedMove> rollScorer(MatchEngine engine, int seat) {
        if (rng.nextDouble() >= BotTuning.PRIMARY_PROFILE_PROBABILITY) {
            return move -> BotTuning.NEUTRAL.dot(move.delta());
        }
        Player me = engine.player(seat);
        BotTuning.Weights base = BotTuning.OFFENSIVE;
        double weightPa = base.pa() + (me.pa() > me.ma() ? BotTuning.STRONGER_ATTACK_BOOST : 0);
        double weightMa = base.ma() + (me.ma() > me.pa() ? BotTuning.STRONGER_ATTACK_BOOST : 0);
        BotTuning.Weights weights = new BotTuning.Weights(weightPa, base.pd(), weightMa, base.md(), base.cn(), base.hpp());
        return move -> weights.dot(move.delta());
    }
}
