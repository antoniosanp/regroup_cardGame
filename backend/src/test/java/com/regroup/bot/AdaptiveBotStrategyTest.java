package com.regroup.bot;

import static org.junit.jupiter.api.Assertions.assertTrue;

import com.regroup.engine.CornerPosition;
import com.regroup.engine.Deck;
import com.regroup.engine.MatchEngine;

import java.util.Random;
import org.junit.jupiter.api.Test;

class AdaptiveBotStrategyTest {

    private static MatchEngine startedEngine() {
        MatchEngine engine = new MatchEngine(Deck.standard(new Random(3)));
        engine.start();
        return engine;
    }

    private static MoveEvaluator.EvaluatedMove move(MoveEvaluator.StatVector before, MoveEvaluator.StatVector after) {
        return new MoveEvaluator.EvaluatedMove(new Placement(0, CornerPosition.TOP_LEFT, 0, 0), before, after);
    }

    @Test
    void threatRuleWeightsTheDefenseMatchingTheIncomingAttack() {
        MatchEngine engine = startedEngine();
        engine.player(1).setPa(5); // one physical threat, no magic anywhere

        var scorer = new AdaptiveBotStrategy(new Random(5)).rollScorer(engine, 0);

        var before = new MoveEvaluator.StatVector(0, 0, 0, 0, 0, 0);
        var pdMove = move(before, new MoveEvaluator.StatVector(0, 1, 0, 0, 0, 0));
        var mdMove = move(before, new MoveEvaluator.StatVector(0, 0, 0, 1, 0, 0));

        assertTrue(scorer.applyAsDouble(pdMove) > scorer.applyAsDouble(mdMove),
                "physical threat should make pd gains outscore md gains");
    }

    @Test
    void wallRuleInvestsInTheAttackThatPenetrates() {
        MatchEngine engine = startedEngine();
        for (int seat = 1; seat < MatchEngine.PLAYER_COUNT; seat++) {
            engine.player(seat).setPd(5); // strong physical walls, no magic defense
        }
        engine.player(0).setPa(2);
        engine.player(0).setMa(2);

        var scorer = new AdaptiveBotStrategy(new Random(5)).rollScorer(engine, 0);

        var before = new MoveEvaluator.StatVector(2, 0, 2, 0, 0, 0);
        var paMove = move(before, new MoveEvaluator.StatVector(3, 0, 2, 0, 0, 0)); // still fully blocked
        var maMove = move(before, new MoveEvaluator.StatVector(2, 0, 3, 0, 0, 0)); // +1 damage vs everyone

        assertTrue(scorer.applyAsDouble(maMove) > scorer.applyAsDouble(paMove),
                "against physical walls the magic attack should win");
    }

    @Test
    void survivalOutranksAttackWhenProjectedDamageCouldKill() {
        MatchEngine engine = startedEngine();
        for (int seat = 1; seat < MatchEngine.PLAYER_COUNT; seat++) {
            engine.player(seat).setPa(5); // 15 incoming vs 3 hp: death is possible
        }
        engine.player(0).setHp(3);

        var scorer = new AdaptiveBotStrategy(new Random(5)).rollScorer(engine, 0);

        var before = new MoveEvaluator.StatVector(0, 0, 0, 0, 0, 0);
        var defenseMove = move(before, new MoveEvaluator.StatVector(0, 2, 0, 0, 0, 0));
        var attackMove = move(before, new MoveEvaluator.StatVector(2, 0, 0, 0, 0, 0)); // +2 dmg vs 3 undefended opponents

        assertTrue(scorer.applyAsDouble(defenseMove) > scorer.applyAsDouble(attackMove),
                "with death on the line, defense should outrank raw damage");
    }
}
