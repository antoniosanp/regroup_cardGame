package com.regroup.engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.Point;
import java.util.Set;
import org.junit.jupiter.api.Test;

class BoardEngineTest {

    private final BoardEngine engine = new BoardEngine();

    private static Card cardOf(CornerAttribute topLeft, CornerAttribute topRight,
                                CornerAttribute bottomLeft, CornerAttribute bottomRight) {
        return new Card(topLeft, topRight, bottomLeft, bottomRight);
    }

    private static Point p(int x, int y) {
        return new Point(x, y);
    }

    @Test
    void firstCardOnEmptyBoardIsValidAtAnyPointAndCorner() {
        Board board = new Board();
        Card card = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);

        assertTrue(engine.isValidPlacement(board, card, CornerPosition.BOTTOM_LEFT, p(5, -3)));
    }

    @Test
    void firstCardBottomLeftAnchorAtOriginProducesTheStandardTwoByTwoBlock() {
        Board board = new Board();
        Card card = cardOf(CornerAttribute.MD_1, CornerAttribute.MA_1, CornerAttribute.PA_1, CornerAttribute.PD_1);

        engine.placeCard(board, card, CornerPosition.BOTTOM_LEFT, p(0, 0));

        assertEquals(Set.of(p(0, 0), p(1, 0), p(0, 1), p(1, 1)), board.cells().keySet());
        assertEquals(CornerAttribute.PA_1, board.at(p(0, 0)).attribute());
        assertEquals(CornerAttribute.PD_1, board.at(p(1, 0)).attribute());
        assertEquals(CornerAttribute.MD_1, board.at(p(0, 1)).attribute());
        assertEquals(CornerAttribute.MA_1, board.at(p(1, 1)).attribute());
    }

    @Test
    void nonEmptyBoardRejectsAnchoringOnAPointThatDoesNotExistYet() {
        Board board = new Board();
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);
        engine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0));

        Card second = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);

        assertFalse(engine.isValidPlacement(board, second, CornerPosition.TOP_LEFT, p(9, 9)));
        assertThrows(IllegalArgumentException.class,
                () -> engine.placeCard(board, second, CornerPosition.TOP_LEFT, p(9, 9)));
    }

    /**
     * The staircase example straight out of gameRules.md's "Placing cards" section: a card with corners
     * Q(TL)/W(TR)/E(BL)/R(BR) already on the board, then a card with T(TL)/Y(TR)/U(BL)/I(BR) placed so its
     * BOTTOM_LEFT (U) covers the first card's TOP_RIGHT (W). Expected result:
     * <pre>
     *     T | Y
     *    -------
     * Q | U | I
     * -----
     * E | R
     * </pre>
     */
    @Test
    void sharingExactlyOneCornerMatchesTheDocumentedStaircaseExample() {
        Board board = new Board();
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1); // Q,W,E,R
        engine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0)); // Q=(0,1) W=(1,1) E=(0,0) R=(1,0)

        Card second = cardOf(CornerAttribute.MA_2, CornerAttribute.MD_2, CornerAttribute.PA_2, CornerAttribute.PD_2); // T,Y,U,I
        engine.placeCard(board, second, CornerPosition.BOTTOM_LEFT, p(1, 1)); // U anchors on W's point

        assertEquals(
                Set.of(p(0, 0), p(1, 0), p(0, 1), p(1, 1), p(1, 2), p(2, 2), p(2, 1)),
                board.cells().keySet());
        assertEquals(CornerAttribute.MA_1, board.at(p(0, 0)).attribute()); // E untouched
        assertEquals(CornerAttribute.MD_1, board.at(p(1, 0)).attribute()); // R untouched
        assertEquals(CornerAttribute.PA_1, board.at(p(0, 1)).attribute()); // Q untouched
        assertEquals(CornerAttribute.PA_2, board.at(p(1, 1)).attribute()); // W overwritten by U
        assertEquals(CornerAttribute.MA_2, board.at(p(1, 2)).attribute()); // T, new
        assertEquals(CornerAttribute.MD_2, board.at(p(2, 2)).attribute()); // Y, new
        assertEquals(CornerAttribute.PD_2, board.at(p(2, 1)).attribute()); // I, new
    }

    @Test
    void extendingFlushToTheRightSharesTwoPointsAlongTheEdge() {
        Board board = new Board();
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);
        engine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0)); // occupies (0,0)(1,0)(0,1)(1,1)

        Card second = cardOf(CornerAttribute.PA_2, CornerAttribute.PD_2, CornerAttribute.MA_2, CornerAttribute.MD_2);
        // Anchor the new card's own left edge (TOP_LEFT) on the first card's right edge point (1,1).
        engine.placeCard(board, second, CornerPosition.TOP_LEFT, p(1, 1));

        assertEquals(
                Set.of(p(0, 0), p(0, 1), p(1, 0), p(1, 1), p(2, 0), p(2, 1)),
                board.cells().keySet());
        // Both of the first card's right-edge points get overwritten by the second card's left edge.
        assertEquals(CornerAttribute.PA_2, board.at(p(1, 1)).attribute());
        assertEquals(CornerAttribute.MA_2, board.at(p(1, 0)).attribute());
        // The new card's own right edge is brand new.
        assertEquals(CornerAttribute.PD_2, board.at(p(2, 1)).attribute());
        assertEquals(CornerAttribute.MD_2, board.at(p(2, 0)).attribute());
        // The first card's left edge is untouched.
        assertEquals(CornerAttribute.PA_1, board.at(p(0, 1)).attribute());
        assertEquals(CornerAttribute.MA_1, board.at(p(0, 0)).attribute());
    }

    @Test
    void extendingInTheOppositeDirectionSharesOnlyTheAnchorPoint() {
        Board board = new Board();
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);
        engine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0)); // occupies (0,0)(1,0)(0,1)(1,1)

        Card second = cardOf(CornerAttribute.PA_2, CornerAttribute.PD_2, CornerAttribute.MA_2, CornerAttribute.MD_2);
        // Anchor the new card's TOP_RIGHT on the first card's own BOTTOM_LEFT point (0,0),
        // extending away from the first card entirely (down-left, all fresh territory).
        engine.placeCard(board, second, CornerPosition.TOP_RIGHT, p(0, 0));

        assertEquals(
                Set.of(p(0, 0), p(1, 0), p(0, 1), p(1, 1), p(-1, 0), p(-1, -1), p(0, -1)),
                board.cells().keySet());
        assertEquals(CornerAttribute.PD_2, board.at(p(0, 0)).attribute()); // anchor overwritten
        assertEquals(CornerAttribute.PA_2, board.at(p(-1, 0)).attribute());
        assertEquals(CornerAttribute.MA_2, board.at(p(-1, -1)).attribute());
        assertEquals(CornerAttribute.MD_2, board.at(p(0, -1)).attribute());
        // The other three points of the first card are all untouched.
        assertEquals(CornerAttribute.MD_1, board.at(p(1, 0)).attribute());
        assertEquals(CornerAttribute.PA_1, board.at(p(0, 1)).attribute());
        assertEquals(CornerAttribute.PD_1, board.at(p(1, 1)).attribute());
    }

    @Test
    void rotatingBeforePlacingChangesWhichAttributeLandsWhere() {
        Board board = new Board();
        Card card = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);

        engine.rotateCard(card); // one clockwise quarter-turn: TL<-BL, TR<-TL, BR<-TR, BL<-BR
        engine.placeCard(board, card, CornerPosition.BOTTOM_LEFT, p(0, 0));

        assertEquals(Rotation.DEG_90, card.rotation());
        // After one clockwise rotation: TL=MA_1, TR=PA_1, BL=MD_1, BR=PD_1.
        assertEquals(CornerAttribute.MD_1, board.at(p(0, 0)).attribute()); // BOTTOM_LEFT
        assertEquals(CornerAttribute.PD_1, board.at(p(1, 0)).attribute()); // BOTTOM_RIGHT
        assertEquals(CornerAttribute.MA_1, board.at(p(0, 1)).attribute()); // TOP_LEFT
        assertEquals(CornerAttribute.PA_1, board.at(p(1, 1)).attribute()); // TOP_RIGHT
        for (BoardCell cell : board.cells().values()) {
            assertEquals(Rotation.DEG_90, cell.rotation());
        }
    }

    @Test
    void placingOnTopOfAnAlreadyFullyOccupiedTwoByTwoOverwritesAllFourPointsAndAddsNone() {
        Board board = new Board();
        Card first = cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1);
        engine.placeCard(board, first, CornerPosition.BOTTOM_LEFT, p(0, 0));

        Card second = cardOf(CornerAttribute.PA_2, CornerAttribute.PD_2, CornerAttribute.MA_2, CornerAttribute.MD_2);
        // BOTTOM_LEFT of the new card anchored exactly where the first card's own
        // BOTTOM_LEFT already is: every one of the new card's 4 points lands on an
        // existing point, so the board gains zero new cells.
        engine.placeCard(board, second, CornerPosition.BOTTOM_LEFT, p(0, 0));

        assertEquals(Set.of(p(0, 0), p(1, 0), p(0, 1), p(1, 1)), board.cells().keySet());
        assertEquals(CornerAttribute.MA_2, board.at(p(0, 0)).attribute());
        assertEquals(CornerAttribute.MD_2, board.at(p(1, 0)).attribute());
        assertEquals(CornerAttribute.PA_2, board.at(p(0, 1)).attribute());
        assertEquals(CornerAttribute.PD_2, board.at(p(1, 1)).attribute());
    }
}
