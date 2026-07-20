package com.regroup.bot;

import com.regroup.engine.MatchEngine;
import com.regroup.engine.Player;

import java.util.Random;
import java.util.function.ToDoubleFunction;

/**
 * "The turtle" (botAIplan.md 3.1): most turns it stacks PD/MD, keeping the two in equilibrium by
 * boosting whichever lags and penalizing moves that push |pd - md| beyond the tolerated gap.
 * The rest of the time it plays a neutral best-overall move so it still grows some attack/economy.
 */
public class DefensiveBotStrategy extends WeightedBotStrategy {

    public DefensiveBotStrategy(Random rng) {
        super(rng);
    }

    @Override
    protected ToDoubleFunction<MoveEvaluator.EvaluatedMove> rollScorer(MatchEngine engine, int seat) {
        if (rng.nextDouble() >= BotTuning.PRIMARY_PROFILE_PROBABILITY) {
            return move -> BotTuning.NEUTRAL.dot(move.delta());
        }
        Player me = engine.player(seat);
        BotTuning.Weights base = BotTuning.DEFENSIVE;
        double weightPd = base.pd() + (me.pd() < me.md() ? BotTuning.LAGGING_DEFENSE_BOOST : 0);
        double weightMd = base.md() + (me.md() < me.pd() ? BotTuning.LAGGING_DEFENSE_BOOST : 0);
        BotTuning.Weights weights = new BotTuning.Weights(base.pa(), weightPd, base.ma(), weightMd, base.cn(), base.hpp());
        return move -> {
            double score = weights.dot(move.delta());
            if (Math.abs(move.after().pd() - move.after().md()) > BotTuning.MAX_DEFENSE_GAP) {
                score -= BotTuning.DEFENSE_GAP_PENALTY;
            }
            return score;
        };
    }
}
