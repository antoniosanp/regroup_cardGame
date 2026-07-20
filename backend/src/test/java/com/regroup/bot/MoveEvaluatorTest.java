package com.regroup.bot;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.regroup.engine.Board;
import com.regroup.engine.BoardCell;
import com.regroup.engine.BoardEngine;
import com.regroup.engine.Card;
import com.regroup.engine.CombatEngine;
import com.regroup.engine.CornerAttribute;
import com.regroup.engine.CornerPosition;
import com.regroup.engine.Player;
import com.regroup.engine.Rotation;

import java.awt.Point;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import org.junit.jupiter.api.Test;

class MoveEvaluatorTest {

    private final BoardEngine boardEngine = new BoardEngine();

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

    @Test
    void rotatedCopyMatchesTheEngineRotationForEveryTurnCount() {
        for (int turns = 0; turns < 4; turns++) {
            Card original = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1,
                    CornerAttribute.MA_1, CornerAttribute.MD_1);
            Card copy = MoveEvaluator.rotatedCopy(original, turns);

            Card reference = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1,
                    CornerAttribute.MA_1, CornerAttribute.MD_1);
            for (int i = 0; i < turns; i++) {
                reference.rotate();
            }
            for (CornerPosition position : CornerPosition.values()) {
                assertEquals(reference.at(position), copy.at(position), turns + " turns, " + position);
            }
            // The original card is never touched.
            assertEquals(CornerAttribute.PA_1, original.at(CornerPosition.TOP_LEFT));
            assertEquals(CornerAttribute.PD_1, original.at(CornerPosition.TOP_RIGHT));
            assertEquals(CornerAttribute.MA_1, original.at(CornerPosition.BOTTOM_LEFT));
            assertEquals(CornerAttribute.MD_1, original.at(CornerPosition.BOTTOM_RIGHT));
        }
    }

    @Test
    void evaluateAllLeavesBoardAndCardUntouched() {
        Board board = new Board();
        boardEngine.placeCard(board, cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1,
                CornerAttribute.MA_1, CornerAttribute.MD_1), CornerPosition.BOTTOM_LEFT, p(0, 0));
        Map<Point, BoardCell> cellsBefore = new HashMap<>(board.cells());

        Card card = cardOf(CornerAttribute.PA_2, CornerAttribute.PD_2,
                CornerAttribute.MA_2, CornerAttribute.MD_2);
        MoveEvaluator.evaluateAll(board, card);

        assertEquals(cellsBefore, board.cells());
        assertEquals(CornerAttribute.PA_2, card.at(CornerPosition.TOP_LEFT));
        assertEquals(CornerAttribute.PD_2, card.at(CornerPosition.TOP_RIGHT));
        assertEquals(CornerAttribute.MA_2, card.at(CornerPosition.BOTTOM_LEFT));
        assertEquals(CornerAttribute.MD_2, card.at(CornerPosition.BOTTOM_RIGHT));
    }

    @Test
    void enumeratesFourRotationsTimesFourCornersPerAnchorPoint() {
        Card card = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1,
                CornerAttribute.MA_1, CornerAttribute.MD_1);

        Board empty = new Board();
        assertEquals(16, MoveEvaluator.evaluateAll(empty, card).size());

        Board withOneCard = new Board();
        boardEngine.placeCard(withOneCard, cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1,
                CornerAttribute.MA_1, CornerAttribute.MD_1), CornerPosition.BOTTOM_LEFT, p(0, 0));
        assertEquals(64, MoveEvaluator.evaluateAll(withOneCard, card).size());
    }

    @Test
    void simulationMatchesTheEngineRecalculationForEveryCandidate() {
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_2,
                CornerAttribute.COINS_2, CornerAttribute.MD_1);
        Card candidate = cardOf(CornerAttribute.PA_2, CornerAttribute.HP_POTION_COIN,
                CornerAttribute.MA_1, CornerAttribute.MD_2);

        Board board = new Board();
        boardEngine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0));

        CombatEngine combatEngine = new CombatEngine();
        for (MoveEvaluator.EvaluatedMove move : MoveEvaluator.evaluateAll(board, candidate)) {
            Board real = new Board();
            boardEngine.placeCard(real, first, CornerPosition.BOTTOM_LEFT, p(0, 0));
            Card rotated = MoveEvaluator.rotatedCopy(candidate, move.placement().rotations());
            boardEngine.placeCard(real, rotated, move.placement().overlapCorner(),
                    p(move.placement().x(), move.placement().y()));
            Player player = new Player();
            combatEngine.calculateStats(real, player);

            assertEquals(new MoveEvaluator.StatVector(player.pa(), player.pd(), player.ma(),
                    player.md(), player.cn(), player.hpp()), move.after(), move.placement().toString());
        }
    }

    @Test
    void bestKeepsAnExistingClusterIntactWhenANonDestructiveSquareExists() {
        Board board = new Board();
        board.set(p(0, 0), cell(CornerAttribute.PA_2));
        board.set(p(0, 1), cell(CornerAttribute.PA_2));
        // A far-away spare point: placing there leaves the PA cluster untouched.
        board.set(p(5, 5), cell(CornerAttribute.EMPTY));

        Card card = cardOf(CornerAttribute.PA_1, CornerAttribute.EMPTY,
                CornerAttribute.EMPTY, CornerAttribute.EMPTY);

        MoveEvaluator.EvaluatedMove best = MoveEvaluator.best(
                MoveEvaluator.evaluateAll(board, card),
                move -> BotTuning.NEUTRAL.dot(move.delta()),
                new Random(1));

        // Any placement anchored on the cluster overwrites part of it (pa drops to at most 3);
        // anchoring on the spare point keeps pa at 4.
        assertEquals(5, best.placement().x());
        assertEquals(5, best.placement().y());
        assertEquals(4, best.after().pa());
    }

    @Test
    void copyOfIsIndependentOfTheOriginal() {
        Board board = new Board();
        board.set(p(0, 0), cell(CornerAttribute.PA_1));

        Board copy = MoveEvaluator.copyOf(board);
        copy.set(p(1, 1), cell(CornerAttribute.MD_1));

        assertEquals(1, board.cells().size());
        assertEquals(2, copy.cells().size());
        assertEquals(List.of(cell(CornerAttribute.PA_1)), List.copyOf(board.cells().values()));
        assertTrue(copy.hasPoint(p(0, 0)));
    }
}
