package com.regroup.bot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.regroup.engine.Board;
import com.regroup.engine.BoardCell;
import com.regroup.engine.BoardEngine;
import com.regroup.engine.Card;
import com.regroup.engine.CornerAttribute;
import com.regroup.engine.Deck;
import com.regroup.engine.MatchEngine;
import com.regroup.engine.Rotation;
import com.regroup.engine.Slot;

import java.awt.Point;
import java.util.List;
import java.util.Random;
import org.junit.jupiter.api.Test;

class DefensiveBotStrategyTest {

    private static Card cardOf(CornerAttribute topLeft, CornerAttribute topRight,
                               CornerAttribute bottomLeft, CornerAttribute bottomRight) {
        return new Card(topLeft, topRight, bottomLeft, bottomRight);
    }

    private static Point p(int x, int y) {
        return new Point(x, y);
    }

    private static BoardCell cell(CornerAttribute attribute) {
        return new BoardCell(attribute, Rotation.DEG_0);
    }

    /** A Random whose profile dice always land on the primary (archetype) branch. */
    static Random alwaysPrimary(long seed) {
        return new Random(seed) {
            @Override
            public double nextDouble() {
                return 0.0;
            }
        };
    }

    @Test
    void picksTheDefensiveCardAboutSevenTurnsInTen() {
        // Slot A scores high under defensive weights, slot B high under the neutral fallback.
        Card defensiveCard = cardOf(CornerAttribute.PD_1, CornerAttribute.PD_1,
                CornerAttribute.MD_1, CornerAttribute.MD_1);   // pd=2, md=2: neutral 4, defensive 12
        Card offensiveCard = cardOf(CornerAttribute.PA_2, CornerAttribute.PA_2,
                CornerAttribute.MA_2, CornerAttribute.MA_2);   // pa=4, ma=4: neutral 8, defensive 4
        Card filler = cardOf(CornerAttribute.EMPTY, CornerAttribute.EMPTY,
                CornerAttribute.EMPTY, CornerAttribute.EMPTY);

        DefensiveBotStrategy bot = new DefensiveBotStrategy(new Random(42));
        int trials = 200;
        int defensivePicks = 0;
        for (int t = 0; t < trials; t++) {
            // 3 cards < FINAL_ROUND_THRESHOLD: final round, every slot free, no deck option.
            MatchEngine engine = new MatchEngine(new Deck(List.of(defensiveCard, offensiveCard, filler)));
            engine.start();
            PickChoice pick = bot.choosePick(engine, 0);
            assertNotNull(pick);
            assertFalse(pick.isDeck());
            if (pick.slot() == Slot.A) {
                defensivePicks++;
            } else {
                assertEquals(Slot.B, pick.slot(), "the neutral fallback should prefer the biggest raw delta");
            }
        }
        assertTrue(defensivePicks >= 110 && defensivePicks <= 170,
                "expected ~70% defensive picks over " + trials + " trials, got " + defensivePicks);
    }

    @Test
    void closesTheDefenseGapWhenAGapClosingMoveExists() {
        MatchEngine engine = new MatchEngine(Deck.standard(new Random(1)));
        engine.start();
        Board board = engine.player(0).board();
        // pd cluster worth 5, md cluster worth 2: gap 3 exceeds the tolerated MAX_DEFENSE_GAP.
        board.set(p(0, 0), cell(CornerAttribute.PD_2));
        board.set(p(0, 1), cell(CornerAttribute.PD_2));
        board.set(p(1, 0), cell(CornerAttribute.PD_1));
        board.set(p(3, 0), cell(CornerAttribute.MD_1));
        board.set(p(3, 1), cell(CornerAttribute.MD_1));

        DefensiveBotStrategy bot = new DefensiveBotStrategy(alwaysPrimary(7));
        Card mdCard = cardOf(CornerAttribute.MD_1, CornerAttribute.MD_1,
                CornerAttribute.MD_1, CornerAttribute.MD_1);
        Placement placement = bot.choosePlacement(engine, 0, mdCard);

        Board sim = MoveEvaluator.copyOf(board);
        new BoardEngine().placeCard(sim, MoveEvaluator.rotatedCopy(mdCard, placement.rotations()),
                placement.overlapCorner(), p(placement.x(), placement.y()));
        MoveEvaluator.StatVector after = MoveEvaluator.statsOf(sim);
        assertTrue(Math.abs(after.pd() - after.md()) <= BotTuning.MAX_DEFENSE_GAP,
                "gap not closed: " + after);
    }
}
