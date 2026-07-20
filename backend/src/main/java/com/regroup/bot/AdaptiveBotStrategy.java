package com.regroup.bot;

import com.regroup.engine.MatchEngine;
import com.regroup.engine.Player;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.function.ToDoubleFunction;

/**
 * "The counter-player" (botAIplan.md 3.3): reads the alive opponents' post-recalculation stats —
 * exactly what the next battle will use — and counters them. Threat rule: defend against whichever
 * incoming damage type is larger. Wall rule: invest in the attack type that actually penetrates the
 * opponents' defenses, scored as expected damage dealt. When projected incoming damage could kill
 * it, survival wins; otherwise attack does. No dice — adaptivity is the personality — but a small
 * per-turn weight jitter keeps multiple adaptive bots from playing identically.
 */
public class AdaptiveBotStrategy extends WeightedBotStrategy {

    public AdaptiveBotStrategy(Random rng) {
        super(rng);
    }

    @Override
    protected ToDoubleFunction<MoveEvaluator.EvaluatedMove> rollScorer(MatchEngine engine, int seat) {
        Player me = engine.player(seat);
        List<Player> opponents = new ArrayList<>();
        for (int s = 0; s < MatchEngine.PLAYER_COUNT; s++) {
            if (s != seat && engine.isAlive(s)) {
                opponents.add(engine.player(s));
            }
        }
        // Snapshot opponent stats so the scorer doesn't re-read live state per candidate.
        int count = opponents.size();
        int[] oppPd = new int[count];
        int[] oppMd = new int[count];
        int incomingPhysical = 0;
        int incomingMagic = 0;
        boolean threat = false;
        for (int i = 0; i < count; i++) {
            Player opp = opponents.get(i);
            oppPd[i] = opp.pd();
            oppMd[i] = opp.md();
            incomingPhysical += Math.max(0, opp.pa() - me.pd());
            incomingMagic += Math.max(0, opp.ma() - me.md());
            threat |= Math.max(opp.pa(), opp.ma()) >= BotTuning.THREAT_THRESHOLD;
        }

        // Everyone attacks everyone each round, so incoming damage is the sum over attackers.
        boolean deathRisk = incomingPhysical + incomingMagic >= me.hp();
        double totalIncoming = Math.max(incomingPhysical + incomingMagic, 1);
        double weightPd = threat ? 1 + 2 * incomingPhysical / totalIncoming : 1;
        double weightMd = threat ? 1 + 2 * incomingMagic / totalIncoming : 1;
        double defenseScale = deathRisk ? 3.0 : 1.0;
        double attackScale = deathRisk ? 1.0 : 2.0;
        double defenseJitter = jitter();
        double attackJitter = jitter();

        return move -> {
            MoveEvaluator.StatVector delta = move.delta();
            double damageGain = expectedDamage(move.after(), oppPd, oppMd)
                    - expectedDamage(move.before(), oppPd, oppMd);
            return defenseScale * (weightPd * delta.pd() + weightMd * delta.md()) * defenseJitter
                    + attackScale * damageGain * attackJitter
                    + 0.5 * delta.cn() + 0.75 * delta.hpp();
        };
    }

    /** Damage this board state would deal next battle — attacks that don't pierce a wall count for nothing. */
    private static double expectedDamage(MoveEvaluator.StatVector stats, int[] oppPd, int[] oppMd) {
        double damage = 0;
        for (int i = 0; i < oppPd.length; i++) {
            damage += Math.max(0, stats.pa() - oppPd[i]) + Math.max(0, stats.ma() - oppMd[i]);
        }
        return damage;
    }

    private double jitter() {
        return 1 + (rng.nextDouble() * 2 - 1) * BotTuning.ADAPTIVE_JITTER;
    }
}
