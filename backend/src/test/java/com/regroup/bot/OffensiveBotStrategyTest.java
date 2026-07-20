package com.regroup.bot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.regroup.engine.Card;
import com.regroup.engine.CornerAttribute;
import com.regroup.engine.CornerPosition;
import com.regroup.engine.Deck;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.Slot;

import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

class OffensiveBotStrategyTest {

    private static Card cardOf(CornerAttribute topLeft, CornerAttribute topRight,
                               CornerAttribute bottomLeft, CornerAttribute bottomRight) {
        return new Card(topLeft, topRight, bottomLeft, bottomRight);
    }

    @Test
    void picksTheOffensiveCardAboutSevenTurnsInTen() {
        Card offensiveCard = cardOf(CornerAttribute.PA_1, CornerAttribute.PA_1,
                CornerAttribute.MA_1, CornerAttribute.MA_1);   // pa=2, ma=2: neutral 4, offensive 12
        Card defensiveCard = cardOf(CornerAttribute.PD_2, CornerAttribute.PD_2,
                CornerAttribute.MD_2, CornerAttribute.MD_2);   // pd=4, md=4: neutral 8, offensive 4
        Card filler = cardOf(CornerAttribute.EMPTY, CornerAttribute.EMPTY,
                CornerAttribute.EMPTY, CornerAttribute.EMPTY);

        OffensiveBotStrategy bot = new OffensiveBotStrategy(new Random(42));
        int trials = 200;
        int offensivePicks = 0;
        for (int t = 0; t < trials; t++) {
            MatchEngine engine = new MatchEngine(new Deck(List.of(offensiveCard, defensiveCard, filler)));
            engine.start();
            PickChoice pick = bot.choosePick(engine, 0);
            assertNotNull(pick);
            assertFalse(pick.isDeck());
            if (pick.slot() == Slot.A) {
                offensivePicks++;
            } else {
                assertEquals(Slot.B, pick.slot(), "the neutral fallback should prefer the biggest raw delta");
            }
        }
        assertTrue(offensivePicks >= 110 && offensivePicks <= 170,
                "expected ~70% offensive picks over " + trials + " trials, got " + offensivePicks);
    }

    @Test
    void buildsOnTheStrongerAttackStat() {
        MatchEngine engine = new MatchEngine(Deck.standard(new Random(1)));
        engine.start();
        engine.player(0).setPa(4);
        engine.player(0).setMa(1);

        OffensiveBotStrategy bot = new OffensiveBotStrategy(DefensiveBotStrategyTest.alwaysPrimary(7));
        var scorer = bot.rollScorer(engine, 0);

        var before = new MoveEvaluator.StatVector(4, 0, 1, 0, 0, 0);
        var paMove = new MoveEvaluator.EvaluatedMove(new Placement(0, CornerPosition.TOP_LEFT, 0, 0),
                before, new MoveEvaluator.StatVector(5, 0, 1, 0, 0, 0));
        var maMove = new MoveEvaluator.EvaluatedMove(new Placement(0, CornerPosition.TOP_LEFT, 0, 0),
                before, new MoveEvaluator.StatVector(4, 0, 2, 0, 0, 0));

        assertTrue(scorer.applyAsDouble(paMove) > scorer.applyAsDouble(maMove),
                "with pa ahead of ma, an equal pa gain should outscore an equal ma gain");
    }
}
