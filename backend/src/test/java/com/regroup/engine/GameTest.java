package com.regroup.engine;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.awt.Point;
import java.util.List;
import org.junit.jupiter.api.Test;

class GameTest {

    private static Card cardOf(CornerAttribute topLeft, CornerAttribute topRight,
                                CornerAttribute bottomLeft, CornerAttribute bottomRight) {
        return new Card(topLeft, topRight, bottomLeft, bottomRight);
    }

    private static Game newGame(Card... cards) {
        return new Game(new Deck(List.of(cards)));
    }

    @Test
    void firstPlacementDoesNotRequireAdjacency() {
        Game game = newGame(cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));
        game.pick(Slot.A);

        game.placeHeldCard(CornerPosition.TOP_LEFT, new Point(0, 0));

        assertFalse(game.hasCardHeld());
        assertTrue(game.player().board().hasPoint(new Point(0, 0)));
    }

    @Test
    void placingRecalculatesStatsFromBoard() {
        Game game = newGame(cardOf(
                CornerAttribute.HP_POTION_COIN, CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1));
        game.pick(Slot.A);

        game.placeHeldCard(CornerPosition.TOP_LEFT, new Point(0, 0));

        assertEquals(1, game.player().cn());
        assertEquals(1, game.player().hpp());
    }

    @Test
    void pickingWithoutEnoughCoinsThrows() {
        Game game = newGame(
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1),
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));

        assertThrows(IllegalStateException.class, () -> game.pick(Slot.B));
    }

    @Test
    void pickingAnotherCardWhileOneIsHeldThrows() {
        Game game = newGame(
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1),
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));
        game.pick(Slot.A);

        assertThrows(IllegalStateException.class, () -> game.pickFaceDown());
    }

    @Test
    void pickFaceDownIsFreeAndDoesNotTouchMarketSlots() {
        Game game = newGame(
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1),
                cardOf(CornerAttribute.PA_2, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1),
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_2, CornerAttribute.MA_1, CornerAttribute.MD_1),
                cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_2, CornerAttribute.MD_1));
        Card a = game.market().cardAt(Slot.A);
        Card b = game.market().cardAt(Slot.B);
        Card c = game.market().cardAt(Slot.C);

        Card drawn = game.pickFaceDown();

        assertNotNull(drawn);
        assertEquals(a, game.market().cardAt(Slot.A));
        assertEquals(b, game.market().cardAt(Slot.B));
        assertEquals(c, game.market().cardAt(Slot.C));
    }

    @Test
    void rotateHeldCardRotatesIt() {
        Game game = newGame(cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));
        game.pick(Slot.A);

        game.rotateHeldCard();

        assertEquals(Rotation.DEG_90, game.heldCard().rotation());
    }

    @Test
    void rotatingOrPlacingWithoutAHeldCardThrows() {
        Game game = newGame(cardOf(CornerAttribute.PA_1, CornerAttribute.PD_1, CornerAttribute.MA_1, CornerAttribute.MD_1));

        assertThrows(IllegalStateException.class, game::rotateHeldCard);
        assertThrows(IllegalStateException.class, () -> game.placeHeldCard(CornerPosition.TOP_LEFT, new Point(0, 0)));
    }
}
