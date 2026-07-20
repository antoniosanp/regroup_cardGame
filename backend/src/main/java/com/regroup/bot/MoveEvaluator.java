package com.regroup.bot;

import com.regroup.engine.Board;
import com.regroup.engine.BoardEngine;
import com.regroup.engine.Card;
import com.regroup.engine.CombatEngine;
import com.regroup.engine.CornerPosition;
import com.regroup.engine.Player;

import java.awt.Point;
import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.function.ToDoubleFunction;

/**
 * Shared move-simulation core for the weighted bot personalities: enumerates every legal placement
 * of a card (4 rotations x 4 overlap corners x every anchor point), applies each to a copy of the
 * board, and recomputes stats exactly the way the engine's round-end recalculation does. Never
 * mutates the real board or the card — cards are live engine objects and {@link Card#rotate()}
 * changes them in place, so rotations are simulated on throwaway copies.
 */
public final class MoveEvaluator {

    /** The board-derived stats the engine recomputes on every placement. */
    public record StatVector(int pa, int pd, int ma, int md, int cn, int hpp) {
        public StatVector minus(StatVector o) {
            return new StatVector(pa - o.pa, pd - o.pd, ma - o.ma, md - o.md, cn - o.cn, hpp - o.hpp);
        }
    }

    /** One candidate placement with the board stats before and after it. */
    public record EvaluatedMove(Placement placement, StatVector before, StatVector after) {
        public StatVector delta() {
            return after.minus(before);
        }
    }

    private static final BoardEngine BOARD_ENGINE = new BoardEngine();
    private static final CombatEngine COMBAT_ENGINE = new CombatEngine();

    private MoveEvaluator() {
    }

    /** Board stats via the engine's own recalculation, run against a throwaway player (so the coin cap applies too). */
    public static StatVector statsOf(Board board) {
        Player scratch = new Player();
        COMBAT_ENGINE.calculateStats(board, scratch);
        return new StatVector(scratch.pa(), scratch.pd(), scratch.ma(), scratch.md(), scratch.cn(), scratch.hpp());
    }

    /** A new card equal to {@code card} rotated {@code quarterTurns} times clockwise; the original is untouched. */
    public static Card rotatedCopy(Card card, int quarterTurns) {
        var topLeft = card.at(CornerPosition.TOP_LEFT);
        var topRight = card.at(CornerPosition.TOP_RIGHT);
        var bottomLeft = card.at(CornerPosition.BOTTOM_LEFT);
        var bottomRight = card.at(CornerPosition.BOTTOM_RIGHT);
        for (int i = 0; i < quarterTurns; i++) {
            var newTopLeft = bottomLeft;
            var newTopRight = topLeft;
            var newBottomRight = topRight;
            var newBottomLeft = bottomRight;
            topLeft = newTopLeft;
            topRight = newTopRight;
            bottomRight = newBottomRight;
            bottomLeft = newBottomLeft;
        }
        return new Card(topLeft, topRight, bottomLeft, bottomRight);
    }

    public static Board copyOf(Board board) {
        Board copy = new Board();
        // Point is mutable, so keys are copied; BoardCell is an immutable record and can be shared.
        board.cells().forEach((point, cell) -> copy.set(new Point(point), cell));
        return copy;
    }

    /** Every legal move for {@code card} on {@code board}, each simulated on a board copy. */
    public static List<EvaluatedMove> evaluateAll(Board board, Card card) {
        StatVector before = statsOf(board);
        List<Point> anchors = board.isEmpty()
                ? List.of(new Point(0, 0))
                : List.copyOf(board.cells().keySet());
        List<EvaluatedMove> moves = new ArrayList<>(anchors.size() * 16);
        for (int rotations = 0; rotations < 4; rotations++) {
            Card rotated = rotatedCopy(card, rotations);
            for (CornerPosition corner : CornerPosition.values()) {
                for (Point anchor : anchors) {
                    Board sim = copyOf(board);
                    BOARD_ENGINE.placeCard(sim, rotated, corner, new Point(anchor));
                    moves.add(new EvaluatedMove(
                            new Placement(rotations, corner, anchor.x, anchor.y), before, statsOf(sim)));
                }
            }
        }
        return moves;
    }

    /** The highest-scoring move, breaking ties uniformly at random so equal boards don't play identically. */
    public static EvaluatedMove best(List<EvaluatedMove> moves, ToDoubleFunction<EvaluatedMove> scorer, Random tieBreakRng) {
        double bestScore = Double.NEGATIVE_INFINITY;
        List<EvaluatedMove> bestMoves = new ArrayList<>();
        for (EvaluatedMove move : moves) {
            double score = scorer.applyAsDouble(move);
            if (score > bestScore) {
                bestScore = score;
                bestMoves.clear();
                bestMoves.add(move);
            } else if (score == bestScore) {
                bestMoves.add(move);
            }
        }
        return bestMoves.get(tieBreakRng.nextInt(bestMoves.size()));
    }
}
